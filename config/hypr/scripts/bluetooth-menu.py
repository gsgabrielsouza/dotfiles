#!/usr/bin/env python3
import atexit
import json
import os
import re
import signal
import subprocess
import sys
import threading
import time

PID_PATH = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "waybar-bluetooth.pid")
MAC_RE = re.compile(r"^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$")
SCAN_SECONDS = 12


def pid_alive(pid):
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def read_pid():
    try:
        with open(PID_PATH, encoding="utf-8") as handle:
            return int(handle.read().strip())
    except (OSError, ValueError):
        return None


def write_pid():
    with open(PID_PATH, "w", encoding="utf-8") as handle:
        handle.write(str(os.getpid()))


def clear_pid():
    try:
        if read_pid() == os.getpid():
            os.remove(PID_PATH)
    except OSError:
        pass


existing = read_pid()
if existing and existing != os.getpid() and pid_alive(existing):
    os.kill(existing, signal.SIGTERM)
    sys.exit(0)

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell, Pango

CSS = """
#bt-popup {
  background-color: #1e2030;
  border: 1px solid #8aadf4;
  border-radius: 6px;
  opacity: 1;
}
#bt-popup box,
#bt-popup scrolledwindow,
#bt-popup viewport,
#bt-popup list,
#bt-popup separator {
  background-color: #1e2030;
}
#bt-dismiss {
  background-color: transparent;
}
#bt-title {
  color: #8aadf4;
  font-family: "JetBrains Mono Nerd", monospace;
  font-weight: bold;
  font-size: 14px;
}
#bt-info, #bt-status, #bt-meta {
  color: #a5adcb;
  font-family: "JetBrains Mono Nerd", monospace;
  font-size: 12px;
}
#bt-name {
  color: #cad3f5;
  font-family: "JetBrains Mono Nerd", monospace;
  font-size: 13px;
}
#bt-name-connected {
  color: #eed49f;
  font-family: "JetBrains Mono Nerd", monospace;
  font-size: 13px;
  font-weight: bold;
}
#bt-popup button {
  background-color: #363a4f;
  color: #cad3f5;
  border: none;
  border-radius: 4px;
  padding: 4px 10px;
  font-family: "JetBrains Mono Nerd", monospace;
  font-size: 12px;
}
#bt-popup button:hover {
  background-color: #494d64;
  color: #eed49f;
}
#bt-popup row {
  background-color: #1e2030;
  padding: 4px 6px;
  border-radius: 4px;
  min-height: 0;
}
#bt-popup row:hover {
  background-color: #363a4f;
}
#bt-popup row.connected {
  background-color: #363a4f;
}
#bt-popup scrollbar {
  background-color: #1e2030;
}
#bt-popup scrollbar slider {
  background-color: #494d64;
  border-radius: 4px;
  min-width: 6px;
}
"""


class BtError(Exception):
    def __init__(self, message):
        super().__init__(message)
        self.message = message


def notify(message):
    try:
        subprocess.Popen(
            ["dunstify", "-a", "bluetooth", "-u", "low", "-t", "2500", "Bluetooth", message],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        pass


def run_async(fn, callback):
    def worker():
        try:
            value = fn()
            error = None
        except (BtError, OSError, subprocess.TimeoutExpired) as exc:
            value = None
            error = exc
        GLib.idle_add(callback, value, error, priority=GLib.PRIORITY_DEFAULT)

    threading.Thread(target=worker, daemon=True).start()


def btctl(args, timeout=30, check=True):
    result = subprocess.run(
        ["bluetoothctl", *args],
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    if check and result.returncode != 0:
        detail = (result.stderr or result.stdout or "falha no bluetoothctl").strip()
        raise BtError(detail.splitlines()[0] if detail else "falha no bluetoothctl")
    return result.stdout


def controller_info():
    try:
        output = btctl(["show"], check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if "No default controller" in output or not output.strip():
        return None
    powered = False
    discovering = False
    alias = "Bluetooth"
    for line in output.splitlines():
        text = line.strip()
        if text.startswith("Alias:"):
            alias = text.split(":", 1)[1].strip()
        elif text.startswith("Powered:"):
            powered = text.split(":", 1)[1].strip().lower() == "yes"
        elif text.startswith("Discovering:"):
            discovering = text.split(":", 1)[1].strip().lower() == "yes"
    return {"alias": alias, "powered": powered, "discovering": discovering}


def parse_devices(output):
    devices = []
    for line in output.splitlines():
        parts = line.split(None, 2)
        if len(parts) < 2 or parts[0] != "Device":
            continue
        mac = parts[1]
        if not MAC_RE.match(mac):
            continue
        name = parts[2] if len(parts) > 2 else mac
        devices.append({"mac": mac, "name": name})
    return devices


def device_info(mac):
    try:
        output = btctl(["info", mac], check=False)
    except (OSError, subprocess.TimeoutExpired):
        return {}
    info = {
        "connected": False,
        "paired": False,
        "trusted": False,
        "icon": "",
        "battery": None,
        "name": mac,
    }
    for line in output.splitlines():
        text = line.strip()
        if text.startswith("Name:") or text.startswith("Alias:"):
            info["name"] = text.split(":", 1)[1].strip()
        elif text.startswith("Connected:"):
            info["connected"] = text.split(":", 1)[1].strip().lower() == "yes"
        elif text.startswith("Paired:"):
            info["paired"] = text.split(":", 1)[1].strip().lower() == "yes"
        elif text.startswith("Trusted:"):
            info["trusted"] = text.split(":", 1)[1].strip().lower() == "yes"
        elif text.startswith("Icon:"):
            info["icon"] = text.split(":", 1)[1].strip()
        elif text.startswith("Battery Percentage:"):
            match = re.search(r"\((\d+)\)", text)
            if match:
                info["battery"] = int(match.group(1))
    return info


def icon_for(kind):
    mapping = {
        "audio-headset": "󰋋",
        "audio-headphones": "󰋋",
        "audio-card": "󰓃",
        "input-mouse": "󰍽",
        "input-keyboard": "󰌌",
        "input-gaming": "󰊴",
        "phone": "󰏲",
        "computer": "󰌢",
    }
    return mapping.get(kind, "󰂯")


def list_devices():
    known = parse_devices(btctl(["devices"], check=False))
    connected_macs = {
        item["mac"] for item in parse_devices(btctl(["devices", "Connected"], check=False))
    }
    paired_macs = {
        item["mac"] for item in parse_devices(btctl(["devices", "Paired"], check=False))
    }
    devices = []
    for item in known:
        info = device_info(item["mac"])
        name = info.get("name") or item["name"]
        connected = item["mac"] in connected_macs or info.get("connected", False)
        paired = item["mac"] in paired_macs or info.get("paired", False)
        devices.append(
            {
                "mac": item["mac"],
                "name": name,
                "connected": connected,
                "paired": paired,
                "trusted": info.get("trusted", False),
                "icon": icon_for(info.get("icon", "")),
                "battery": info.get("battery"),
            }
        )
    devices.sort(
        key=lambda item: (
            not item["connected"],
            not item["paired"],
            item["name"].lower(),
        )
    )
    return devices


def set_power(enabled):
    btctl(["power", "on" if enabled else "off"])


def connect_device(mac):
    info = device_info(mac)
    if not info.get("paired"):
        btctl(["pair", mac], timeout=40)
    if not info.get("trusted"):
        btctl(["trust", mac], check=False)
    btctl(["connect", mac], timeout=40)
    route = os.path.expanduser("~/.config/hypr/scripts/bt-audio-route.sh")
    if os.path.isfile(route) and os.access(route, os.X_OK):
        subprocess.run([route], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def disconnect_device(mac):
    btctl(["disconnect", mac], timeout=20)


def start_scan():
    btctl(["scan", "on"], check=False)


def stop_scan():
    btctl(["scan", "off"], check=False)


def hypr_cursor():
    raw = subprocess.check_output(["hyprctl", "cursorpos"], text=True).strip()
    x, y = raw.split(",", 1)
    return int(x.strip()), int(y.strip())


def hypr_monitor_at(x, y):
    monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
    for mon in monitors:
        left = mon["x"]
        top = mon["y"]
        right = left + mon["width"]
        bottom = top + mon["height"]
        if left <= x < right and top <= y < bottom:
            return mon
    return None


def gdk_monitor_for_hypr(hypr_mon):
    display = Gdk.Display.get_default()
    if display is None or hypr_mon is None:
        return None
    target_model = hypr_mon.get("model") or ""
    target_make = hypr_mon.get("make") or ""
    for i in range(display.get_n_monitors()):
        gdk_mon = display.get_monitor(i)
        if gdk_mon.get_model() == target_model and gdk_mon.get_manufacturer() == target_make:
            return gdk_mon
    return display.get_monitor_at_point(hypr_mon["x"], hypr_mon["y"])


def monitor_at_pointer():
    display = Gdk.Display.get_default()
    if display is None:
        return None
    try:
        x, y = hypr_cursor()
        hypr_mon = hypr_monitor_at(x, y)
        gdk_mon = gdk_monitor_for_hypr(hypr_mon)
        if gdk_mon is not None:
            return gdk_mon
        return display.get_monitor_at_point(x, y)
    except (OSError, ValueError, subprocess.CalledProcessError, json.JSONDecodeError):
        seat = display.get_default_seat()
        _screen, x, y = seat.get_pointer().get_position()
        return display.get_monitor_at_point(x, y)


def apply_rgba(window):
    window.set_app_paintable(True)
    screen = window.get_screen()
    visual = screen.get_rgba_visual()
    if visual is not None:
        window.set_visual(visual)


def init_layer(window, namespace, monitor):
    GtkLayerShell.init_for_window(window)
    GtkLayerShell.set_namespace(window, namespace)
    GtkLayerShell.set_layer(window, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_exclusive_zone(window, 0)
    if monitor is not None:
        GtkLayerShell.set_monitor(window, monitor)


class BluetoothMenu:
    def __init__(self, monitor):
        self.monitor = monitor
        self.busy = False
        self.syncing_switch = False
        self.scanning = False
        self.scan_source = None
        self.scan_tick = None
        self.placed_left = None
        self.cursor_x = 0
        try:
            self.cursor_x, _cursor_y = hypr_cursor()
        except (OSError, ValueError, subprocess.CalledProcessError):
            self.cursor_x = 0

        self.popup = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.popup.set_name("bt-popup")
        self.popup.set_decorated(False)
        self.popup.set_resizable(False)
        apply_rgba(self.popup)
        init_layer(self.popup, "waybar-bluetooth", monitor)
        GtkLayerShell.set_anchor(self.popup, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self.popup, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_keyboard_mode(self.popup, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        GtkLayerShell.set_margin(self.popup, GtkLayerShell.Edge.TOP, 1)
        self.place(340)
        self.popup.connect("size-allocate", self.on_allocate)
        self.popup.connect("key-press-event", self.on_key)

        self.dismiss = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.dismiss.set_name("bt-dismiss")
        self.dismiss.set_decorated(False)
        self.dismiss.set_resizable(False)
        apply_rgba(self.dismiss)
        init_layer(self.dismiss, "waybar-bluetooth-dismiss", monitor)
        for edge in (
            GtkLayerShell.Edge.TOP,
            GtkLayerShell.Edge.BOTTOM,
            GtkLayerShell.Edge.LEFT,
            GtkLayerShell.Edge.RIGHT,
        ):
            GtkLayerShell.set_anchor(self.dismiss, edge, True)
        self.ignore_until = time.monotonic() + 0.25
        self.dismiss.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.dismiss.connect("button-press-event", self.on_dismiss)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        root.set_margin_top(10)
        root.set_margin_bottom(10)
        root.set_margin_start(10)
        root.set_margin_end(10)
        root.set_size_request(340, -1)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.title = Gtk.Label(label="󰂯  Bluetooth", xalign=0)
        self.title.set_name("bt-title")
        self.title.set_hexpand(True)
        self.switch = Gtk.Switch()
        self.switch.set_valign(Gtk.Align.CENTER)
        self.switch.connect("notify::active", self.on_switch)
        header.pack_start(self.title, True, True, 0)
        header.pack_end(self.switch, False, False, 0)

        self.info = Gtk.Label(xalign=0)
        self.info.set_name("bt-info")
        self.info.set_line_wrap(True)

        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.scan_btn = Gtk.Button(label="Pesquisar")
        self.scan_btn.connect("clicked", lambda *_: self.toggle_scan())
        self.refresh_btn = Gtk.Button(label="Atualizar")
        self.refresh_btn.connect("clicked", lambda *_: self.reload())
        actions.pack_start(self.scan_btn, False, False, 0)
        actions.pack_start(self.refresh_btn, False, False, 0)

        self.listbox = Gtk.ListBox()
        self.listbox.set_selection_mode(Gtk.SelectionMode.NONE)
        self.listbox.set_activate_on_single_click(True)
        self.listbox.connect("row-activated", self.on_row)
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_min_content_height(120)
        scroll.set_max_content_height(360)
        scroll.set_propagate_natural_height(True)
        scroll.add(self.listbox)

        self.status = Gtk.Label(xalign=0)
        self.status.set_name("bt-status")

        root.pack_start(header, False, False, 0)
        root.pack_start(self.info, False, False, 0)
        root.pack_start(actions, False, False, 0)
        root.pack_start(Gtk.Separator(), False, False, 0)
        root.pack_start(scroll, True, True, 0)
        root.pack_start(self.status, False, False, 0)
        self.popup.add(root)

    def place(self, width):
        if self.monitor is not None:
            geo = self.monitor.get_geometry()
            mon_x, mon_w = geo.x, geo.width
        else:
            mon_x, mon_w = 0, 1920
        left = self.cursor_x - mon_x - width // 2
        left = max(8, min(left, mon_w - width - 8))
        if self.placed_left == left:
            return
        self.placed_left = left
        GtkLayerShell.set_margin(self.popup, GtkLayerShell.Edge.LEFT, int(left))

    def on_allocate(self, _widget, allocation):
        if allocation.width > 1:
            self.place(allocation.width)

    def on_key(self, _widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.quit()
            return True
        return False

    def on_dismiss(self, *_args):
        if time.monotonic() < self.ignore_until:
            return True
        self.quit()
        return True

    def quit(self, *_args):
        self.stop_scan_ui(silent=True)
        Gtk.main_quit()
        return True

    def set_status(self, text):
        self.status.set_text(text or "")

    def set_busy(self, busy, message=""):
        self.busy = busy
        can_act = not busy and self.switch.get_active()
        self.refresh_btn.set_sensitive(not busy)
        self.scan_btn.set_sensitive(can_act or self.scanning)
        self.switch.set_sensitive(not busy)
        self.listbox.set_sensitive(not busy)
        self.set_status(message)

    def fill_header(self, controller, devices):
        if controller is None:
            self.syncing_switch = True
            self.switch.set_active(False)
            self.syncing_switch = False
            self.switch.set_sensitive(False)
            self.title.set_text("󰂲  Bluetooth")
            self.info.set_text("Nenhum adaptador encontrado")
            return
        powered = controller["powered"]
        self.syncing_switch = True
        self.switch.set_active(powered)
        self.syncing_switch = False
        connected = [item for item in devices if item["connected"]]
        if not powered:
            self.title.set_text("󰂲  Bluetooth")
            self.info.set_text("Desligado")
            return
        if connected:
            self.title.set_text("󰂱  Bluetooth")
            names = ", ".join(item["name"] for item in connected)
            self.info.set_text(names)
        else:
            self.title.set_text("󰂯  Bluetooth")
            self.info.set_text("Nenhum dispositivo conectado")

    def clear_rows(self):
        for child in self.listbox.get_children():
            self.listbox.remove(child)

    def add_placeholder(self, text):
        row = Gtk.ListBoxRow()
        row.set_sensitive(False)
        label = Gtk.Label(label=text, xalign=0)
        label.set_name("bt-info")
        row.add(label)
        self.listbox.add(row)

    def add_device_row(self, device):
        row = Gtk.ListBoxRow()
        row.device = device
        if device["connected"]:
            row.get_style_context().add_class("connected")
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        icon = Gtk.Label(label=device["icon"])
        icon.set_name("bt-name-connected" if device["connected"] else "bt-name")
        name = Gtk.Label(label=device["name"], xalign=0)
        name.set_name("bt-name-connected" if device["connected"] else "bt-name")
        name.set_hexpand(True)
        name.set_ellipsize(Pango.EllipsizeMode.END)
        meta_parts = []
        if device["connected"]:
            meta_parts.append("conectado")
        elif device["paired"]:
            meta_parts.append("pareado")
        else:
            meta_parts.append("novo")
        if device["battery"] is not None:
            meta_parts.append(f"{device['battery']}%")
        meta = Gtk.Label(label=" · ".join(meta_parts))
        meta.set_name("bt-meta")
        box.pack_start(icon, False, False, 0)
        box.pack_start(name, True, True, 0)
        box.pack_end(meta, False, False, 0)
        row.add(box)
        self.listbox.add(row)

    def render_devices(self, devices, powered):
        self.clear_rows()
        if not powered:
            self.add_placeholder("Ligue o Bluetooth para ver os dispositivos")
        elif not devices:
            self.add_placeholder("Nenhum dispositivo. Use Pesquisar.")
        else:
            for device in devices:
                self.add_device_row(device)
        self.listbox.show_all()

    def snapshot(self):
        controller = controller_info()
        powered = bool(controller and controller["powered"])
        devices = list_devices() if powered else []
        return {"controller": controller, "powered": powered, "devices": devices}

    def apply_snapshot(self, data, message=""):
        self.fill_header(data["controller"], data["devices"])
        self.render_devices(data["devices"], data["powered"])
        if self.scanning:
            self.scan_btn.set_label("Parar")
            self.set_busy(False, message or "Pesquisando...")
        else:
            self.scan_btn.set_label("Pesquisar")
            self.set_busy(False, message)

    def reload(self, message=""):
        if self.busy:
            return
        self.set_busy(True, message or "Atualizando...")

        def work():
            return self.snapshot()

        def done(data, error):
            if error is not None:
                self.set_busy(False, str(error))
                return False
            self.apply_snapshot(data)
            return False

        run_async(work, done)

    def on_switch(self, switch, _pspec):
        if self.syncing_switch or self.busy:
            return
        wanted = switch.get_active()
        if not wanted:
            self.stop_scan_ui(silent=True)
        self.set_busy(True, "Ligando Bluetooth..." if wanted else "Desligando Bluetooth...")

        def work():
            set_power(wanted)
            return self.snapshot()

        def done(data, error):
            if error is not None:
                self.syncing_switch = True
                switch.set_active(not wanted)
                self.syncing_switch = False
                self.set_busy(False, str(error))
                return False
            self.apply_snapshot(data)
            notify("Bluetooth ligado" if wanted else "Bluetooth desligado")
            return False

        run_async(work, done)

    def on_row(self, _listbox, row):
        device = getattr(row, "device", None)
        if device is None or self.busy:
            return
        if device["connected"]:
            self.disconnect(device)
        else:
            self.connect(device)

    def connect(self, device):
        if self.busy:
            return
        self.set_busy(True, f"Conectando a {device['name']}...")

        def work():
            connect_device(device["mac"])
            return self.snapshot()

        def done(data, error):
            if error is not None:
                self.set_busy(False, str(error).splitlines()[0][:120])
                notify(f"Falha ao conectar a {device['name']}")
                return False
            self.apply_snapshot(data)
            notify(f"Conectado a {device['name']}")
            return False

        run_async(work, done)

    def disconnect(self, device):
        if self.busy:
            return
        self.set_busy(True, f"Desconectando {device['name']}...")

        def work():
            disconnect_device(device["mac"])
            return self.snapshot()

        def done(data, error):
            if error is not None:
                self.set_busy(False, str(error).splitlines()[0][:120])
                return False
            self.apply_snapshot(data)
            notify(f"Desconectado de {device['name']}")
            return False

        run_async(work, done)

    def toggle_scan(self):
        if self.scanning:
            self.stop_scan_ui()
            return
        if self.busy or not self.switch.get_active():
            return
        self.scanning = True
        self.scan_btn.set_label("Parar")
        self.set_status("Pesquisando...")

        def work():
            start_scan()
            return True

        def done(_value, error):
            if error is not None:
                self.scanning = False
                self.scan_btn.set_label("Pesquisar")
                self.set_busy(False, str(error))
                return False
            self.scan_tick = GLib.timeout_add_seconds(2, self.on_scan_tick)
            self.scan_source = GLib.timeout_add_seconds(SCAN_SECONDS, self.on_scan_timeout)
            return False

        run_async(work, done)

    def on_scan_tick(self):
        if not self.scanning:
            self.scan_tick = None
            return False
        if not self.busy:
            self.reload("Pesquisando...")
        return True

    def on_scan_timeout(self):
        self.scan_source = None
        self.stop_scan_ui(message="Pesquisa concluída")
        return False

    def stop_scan_ui(self, message="", silent=False):
        was_scanning = self.scanning
        self.scanning = False
        if self.scan_source is not None:
            GLib.source_remove(self.scan_source)
            self.scan_source = None
        if self.scan_tick is not None:
            GLib.source_remove(self.scan_tick)
            self.scan_tick = None
        self.scan_btn.set_label("Pesquisar")

        def work():
            stop_scan()
            return self.snapshot()

        def done(data, error):
            if error is not None:
                if not silent:
                    self.set_busy(False, str(error))
                return False
            if silent:
                self.apply_snapshot(data)
            else:
                self.apply_snapshot(data, message if was_scanning else "")
            return False

        if was_scanning or not silent:
            run_async(work, done)
        else:
            try:
                stop_scan()
            except (BtError, OSError, subprocess.TimeoutExpired):
                pass

    def show(self):
        self.dismiss.show_all()
        self.popup.show_all()
        if self.monitor is not None:
            GtkLayerShell.set_monitor(self.dismiss, self.monitor)
            GtkLayerShell.set_monitor(self.popup, self.monitor)
        self.reload()


def main():
    write_pid()
    atexit.register(clear_pid)
    signal.signal(signal.SIGTERM, lambda *_: GLib.idle_add(Gtk.main_quit))
    signal.signal(signal.SIGINT, lambda *_: GLib.idle_add(Gtk.main_quit))

    css = Gtk.CssProvider()
    css.load_from_data(CSS.encode("utf-8"))
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        css,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    menu = BluetoothMenu(monitor_at_pointer())
    menu.show()
    Gtk.main()
    try:
        stop_scan()
    except (BtError, OSError, subprocess.TimeoutExpired):
        pass
    clear_pid()


if __name__ == "__main__":
    main()
