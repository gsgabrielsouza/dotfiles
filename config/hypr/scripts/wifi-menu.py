#!/usr/bin/env python3
import atexit
import json
import os
import signal
import subprocess
import sys
import threading
import time

PID_PATH = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "waybar-wifi.pid")


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
#wifi-popup {
  background-color: #24273a;
  border: 1px solid #8aadf4;
  border-radius: 6px;
}
#wifi-popup box {
  background-color: transparent;
}
#wifi-dismiss {
  background-color: transparent;
}
#wifi-title {
  color: #8aadf4;
  font-family: "JetBrains Mono Nerd", monospace;
  font-weight: bold;
  font-size: 14px;
}
#wifi-info, #wifi-status, #wifi-meta, #wifi-password-label {
  color: #a5adcb;
  font-family: "JetBrains Mono Nerd", monospace;
  font-size: 12px;
}
#wifi-ssid {
  color: #cad3f5;
  font-family: "JetBrains Mono Nerd", monospace;
  font-size: 13px;
}
#wifi-ssid-connected {
  color: #eed49f;
  font-family: "JetBrains Mono Nerd", monospace;
  font-size: 13px;
  font-weight: bold;
}
#wifi-popup button {
  background-color: #363a4f;
  color: #cad3f5;
  border: none;
  border-radius: 4px;
  padding: 4px 10px;
  font-family: "JetBrains Mono Nerd", monospace;
  font-size: 12px;
}
#wifi-popup button:hover {
  background-color: #494d64;
  color: #eed49f;
}
#wifi-popup entry {
  background-color: #363a4f;
  color: #cad3f5;
  border: none;
  border-radius: 4px;
  padding: 6px 8px;
  font-family: "JetBrains Mono Nerd", monospace;
}
#wifi-popup list {
  background-color: transparent;
}
#wifi-popup row {
  padding: 4px 6px;
  border-radius: 4px;
  min-height: 0;
}
#wifi-popup row:hover {
  background-color: #363a4f;
}
#wifi-popup row.connected {
  background-color: alpha(#eed49f, 0.12);
}
#wifi-popup scrollbar {
  background-color: transparent;
}
#wifi-popup scrollbar slider {
  background-color: #494d64;
  border-radius: 4px;
  min-width: 6px;
}
"""


class NmError(Exception):
    def __init__(self, message):
        super().__init__(message)
        self.message = message


def split_nmcli(line):
    fields = []
    current = []
    escaped = False
    for char in line:
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            fields.append("".join(current))
            current = []
        else:
            current.append(char)
    fields.append("".join(current))
    return fields


def nmcli(args, timeout=30):
    result = subprocess.run(
        ["nmcli", *args],
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "falha no nmcli").strip()
        raise NmError(detail)
    return result.stdout


def notify(message):
    try:
        subprocess.Popen(
            ["dunstify", "-a", "wifi", "-u", "low", "-t", "2500", "Wi-Fi", message],
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
        except (NmError, OSError, subprocess.TimeoutExpired) as exc:
            value = None
            error = exc
        GLib.idle_add(callback, value, error, priority=GLib.PRIORITY_DEFAULT)

    threading.Thread(target=worker, daemon=True).start()


def radio_enabled():
    return nmcli(["radio", "wifi"]).strip().lower() == "enabled"


def wifi_device():
    output = nmcli(["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"])
    for line in output.splitlines():
        parts = split_nmcli(line)
        if len(parts) < 3:
            continue
        device, kind, state = parts[0], parts[1], parts[2]
        if kind == "wifi" and not device.startswith("p2p-"):
            connection = parts[3] if len(parts) > 3 else ""
            return device, state, connection
    return None, "", ""


def active_ipv4(device):
    if not device:
        return ""
    try:
        output = nmcli(["-t", "-f", "IP4.ADDRESS", "device", "show", device])
    except (NmError, subprocess.TimeoutExpired):
        return ""
    for line in output.splitlines():
        if not line:
            continue
        value = split_nmcli(line)[-1]
        return value.split("/", 1)[0]
    return ""


def saved_ssids():
    found = set()
    try:
        output = nmcli(["-t", "-f", "NAME,TYPE", "connection", "show"])
    except (NmError, subprocess.TimeoutExpired):
        return found
    for line in output.splitlines():
        parts = split_nmcli(line)
        if len(parts) < 2 or parts[1] not in ("802-11-wireless", "wifi"):
            continue
        name = parts[0]
        found.add(name)
        try:
            ssid = nmcli(["-g", "802-11-wireless.ssid", "connection", "show", name]).strip()
        except (NmError, subprocess.TimeoutExpired):
            continue
        if ssid:
            found.add(ssid)
    return found


def signal_icon(strength):
    if strength < 25:
        return "󰤯"
    if strength < 50:
        return "󰤟"
    if strength < 75:
        return "󰤢"
    if strength < 90:
        return "󰤥"
    return "󰤨"


def band_of(freq):
    digits = "".join(char for char in freq if char.isdigit())
    if not digits:
        return ""
    value = int(digits)
    if value >= 5000:
        return "5 GHz"
    if value >= 2000:
        return "2.4 GHz"
    return ""


def is_open(security):
    value = security.strip()
    return value in ("", "--", "none", "None")


def needs_secrets(error):
    text = str(error).lower()
    keys = ("secret", "segredo", "password", "senha", "802-11-wireless-security")
    return any(key in text for key in keys)


def is_enterprise(security):
    value = security.upper()
    return "802.1" in value or "ENTERPRISE" in value


def list_networks():
    output = nmcli(
        [
            "-t",
            "-f",
            "IN-USE,SSID,SIGNAL,SECURITY,BSSID,FREQ",
            "device",
            "wifi",
            "list",
            "--rescan",
            "no",
        ]
    )
    grouped = {}
    for line in output.splitlines():
        parts = split_nmcli(line)
        if len(parts) < 4:
            continue
        in_use, ssid, signal, security = parts[0], parts[1], parts[2], parts[3]
        if not ssid:
            continue
        try:
            strength = int(signal)
        except ValueError:
            strength = 0
        freq = parts[5] if len(parts) > 5 else ""
        connected = in_use.strip() in ("*", "yes", "sim")
        current = grouped.get(ssid)
        candidate = {
            "ssid": ssid,
            "signal": strength,
            "security": security,
            "connected": connected,
            "band": band_of(freq),
        }
        if current is None:
            grouped[ssid] = candidate
            continue
        if connected or (not current["connected"] and strength > current["signal"]):
            candidate["connected"] = connected or current["connected"]
            grouped[ssid] = candidate
    networks = list(grouped.values())
    networks.sort(key=lambda item: (not item["connected"], -item["signal"], item["ssid"].lower()))
    return networks


def rescan_and_list():
    try:
        nmcli(["device", "wifi", "rescan"], timeout=8)
    except (NmError, subprocess.TimeoutExpired):
        pass
    return list_networks()


def connect_network(ssid, password=None):
    if password:
        nmcli(["device", "wifi", "connect", ssid, "password", password], timeout=40)
        return
    try:
        nmcli(["connection", "up", ssid], timeout=40)
        return
    except NmError:
        pass
    nmcli(["device", "wifi", "connect", ssid], timeout=40)


def disconnect_device(device):
    if not device:
        raise NmError("Nenhuma interface Wi-Fi")
    nmcli(["device", "disconnect", device])


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
        if left <= x < right and top <= y < top + (bottom - top):
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


class WifiMenu:
    def __init__(self, monitor):
        self.monitor = monitor
        self.busy = False
        self.syncing_switch = False
        self.saved = set()
        self.device = None
        self.pending_ssid = None
        self.want_rescan = False
        self.placed_left = None
        self.cursor_x = 0
        try:
            self.cursor_x, _cursor_y = hypr_cursor()
        except (OSError, ValueError, subprocess.CalledProcessError):
            self.cursor_x = 0

        self.popup = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.popup.set_name("wifi-popup")
        self.popup.set_decorated(False)
        self.popup.set_resizable(False)
        apply_rgba(self.popup)
        init_layer(self.popup, "waybar-wifi", monitor)
        GtkLayerShell.set_anchor(self.popup, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self.popup, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_keyboard_mode(self.popup, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        GtkLayerShell.set_margin(self.popup, GtkLayerShell.Edge.TOP, 1)
        self.place(340)
        self.popup.connect("size-allocate", self.on_allocate)
        self.popup.connect("key-press-event", self.on_key)

        self.dismiss = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.dismiss.set_name("wifi-dismiss")
        self.dismiss.set_decorated(False)
        self.dismiss.set_resizable(False)
        apply_rgba(self.dismiss)
        init_layer(self.dismiss, "waybar-wifi-dismiss", monitor)
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
        self.title = Gtk.Label(label="󰤨  Wi-Fi", xalign=0)
        self.title.set_name("wifi-title")
        self.title.set_hexpand(True)
        self.switch = Gtk.Switch()
        self.switch.set_valign(Gtk.Align.CENTER)
        self.switch.connect("notify::active", self.on_switch)
        header.pack_start(self.title, True, True, 0)
        header.pack_end(self.switch, False, False, 0)

        self.info = Gtk.Label(xalign=0)
        self.info.set_name("wifi-info")
        self.info.set_line_wrap(True)

        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.refresh_btn = Gtk.Button(label="Atualizar")
        self.refresh_btn.connect("clicked", lambda *_: self.reload(True))
        self.disconnect_btn = Gtk.Button(label="Desconectar")
        self.disconnect_btn.connect("clicked", lambda *_: self.disconnect())
        editor_btn = Gtk.Button(label="Ajustes")
        editor_btn.connect("clicked", self.open_editor)
        actions.pack_start(self.refresh_btn, False, False, 0)
        actions.pack_start(self.disconnect_btn, False, False, 0)
        actions.pack_end(editor_btn, False, False, 0)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.NONE)

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
        self.stack.add_named(scroll, "list")

        password_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.password_label = Gtk.Label(xalign=0)
        self.password_label.set_name("wifi-password-label")
        self.password_label.set_line_wrap(True)
        self.password_entry = Gtk.Entry()
        self.password_entry.set_visibility(False)
        self.password_entry.set_input_purpose(Gtk.InputPurpose.PASSWORD)
        self.password_entry.connect("activate", lambda *_: self.submit_password())
        password_actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        cancel_btn = Gtk.Button(label="Cancelar")
        cancel_btn.connect("clicked", lambda *_: self.show_list())
        connect_btn = Gtk.Button(label="Conectar")
        connect_btn.connect("clicked", lambda *_: self.submit_password())
        password_actions.pack_end(connect_btn, False, False, 0)
        password_actions.pack_end(cancel_btn, False, False, 0)
        password_box.pack_start(self.password_label, False, False, 0)
        password_box.pack_start(self.password_entry, False, False, 0)
        password_box.pack_start(password_actions, False, False, 0)
        self.stack.add_named(password_box, "password")

        self.status = Gtk.Label(xalign=0)
        self.status.set_name("wifi-status")

        root.pack_start(header, False, False, 0)
        root.pack_start(self.info, False, False, 0)
        root.pack_start(actions, False, False, 0)
        root.pack_start(Gtk.Separator(), False, False, 0)
        root.pack_start(self.stack, True, True, 0)
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
            if self.stack.get_visible_child_name() == "password":
                self.show_list()
                return True
            self.quit()
            return True
        return False

    def on_dismiss(self, *_args):
        if time.monotonic() < self.ignore_until:
            return True
        self.quit()
        return True

    def quit(self, *_args):
        Gtk.main_quit()
        return True

    def set_status(self, text):
        self.status.set_text(text or "")

    def set_busy(self, busy, message=""):
        self.busy = busy
        self.refresh_btn.set_sensitive(not busy)
        self.disconnect_btn.set_sensitive(not busy and bool(self.device))
        self.switch.set_sensitive(not busy)
        self.listbox.set_sensitive(not busy)
        self.set_status(message)

    def show_list(self):
        self.pending_ssid = None
        self.password_entry.set_text("")
        self.stack.set_visible_child_name("list")
        self.set_status("")

    def show_password(self, ssid, message=None):
        self.pending_ssid = ssid
        self.password_label.set_text(message or f"Senha para {ssid}")
        self.password_entry.set_text("")
        self.stack.set_visible_child_name("password")
        self.password_entry.grab_focus()

    def fill_header(self, enabled, state, connection, ipv4):
        self.syncing_switch = True
        self.switch.set_active(enabled)
        self.syncing_switch = False
        if not enabled:
            self.title.set_text("󰤮  Wi-Fi")
            self.info.set_text("Rádio desligado")
            self.disconnect_btn.set_sensitive(False)
            return
        if connection and state.startswith("connected"):
            self.title.set_text("󰤨  Wi-Fi")
            suffix = f" · {ipv4}" if ipv4 else ""
            self.info.set_text(f"{connection}{suffix}")
            self.disconnect_btn.set_sensitive(not self.busy)
        else:
            self.title.set_text("󰤩  Wi-Fi")
            self.info.set_text("Nenhuma rede conectada")
            self.disconnect_btn.set_sensitive(False)

    def clear_rows(self):
        for child in self.listbox.get_children():
            self.listbox.remove(child)

    def add_placeholder(self, text):
        row = Gtk.ListBoxRow()
        row.set_sensitive(False)
        label = Gtk.Label(label=text, xalign=0)
        label.set_name("wifi-info")
        row.add(label)
        self.listbox.add(row)

    def add_network_row(self, network):
        row = Gtk.ListBoxRow()
        row.network = network
        if network["connected"]:
            row.get_style_context().add_class("connected")
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        icon = Gtk.Label(label=signal_icon(network["signal"]))
        icon.set_name("wifi-ssid-connected" if network["connected"] else "wifi-ssid")
        ssid = Gtk.Label(label=network["ssid"], xalign=0)
        ssid.set_name("wifi-ssid-connected" if network["connected"] else "wifi-ssid")
        ssid.set_hexpand(True)
        ssid.set_ellipsize(Pango.EllipsizeMode.END)
        meta_parts = []
        if network["band"]:
            meta_parts.append(network["band"])
        meta_parts.append(f"{network['signal']}%")
        if not is_open(network["security"]):
            meta_parts.append("")
        meta = Gtk.Label(label="  ".join(meta_parts))
        meta.set_name("wifi-meta")
        box.pack_start(icon, False, False, 0)
        box.pack_start(ssid, True, True, 0)
        box.pack_end(meta, False, False, 0)
        row.add(box)
        self.listbox.add(row)

    def render_networks(self, networks, enabled):
        self.clear_rows()
        if not enabled:
            self.add_placeholder("Ligue o Wi-Fi para ver as redes")
        elif not networks:
            self.add_placeholder("Nenhuma rede encontrada")
        else:
            for network in networks:
                self.add_network_row(network)
        self.listbox.show_all()

    def snapshot(self):
        enabled = radio_enabled()
        device, state, connection = wifi_device()
        ipv4 = active_ipv4(device) if enabled else ""
        networks = list_networks() if enabled else []
        saved = saved_ssids() if enabled else set()
        return {
            "enabled": enabled,
            "device": device,
            "state": state,
            "connection": connection,
            "ipv4": ipv4,
            "networks": networks,
            "saved": saved,
        }

    def apply_snapshot(self, data, message=""):
        self.device = data["device"]
        self.saved = data["saved"]
        self.fill_header(data["enabled"], data["state"], data["connection"], data["ipv4"])
        self.render_networks(data["networks"], data["enabled"])
        self.set_busy(False, message)

    def reload(self, rescan=False):
        if self.busy:
            if rescan:
                self.want_rescan = True
            return
        self.want_rescan = False
        self.set_busy(True, "Atualizando..." if rescan else "")

        def work():
            data = self.snapshot()
            if rescan and data["enabled"]:
                data["networks"] = rescan_and_list()
            return data

        def done(data, error):
            if error is not None:
                self.set_busy(False, str(error))
                if self.want_rescan:
                    self.reload(True)
                return False
            self.apply_snapshot(data)
            if self.want_rescan:
                self.reload(True)
            return False

        run_async(work, done)

    def on_switch(self, switch, _pspec):
        if self.syncing_switch or self.busy:
            return
        wanted = switch.get_active()
        self.set_busy(True, "Ligando Wi-Fi..." if wanted else "Desligando Wi-Fi...")

        def work():
            nmcli(["radio", "wifi", "on" if wanted else "off"])
            if wanted:
                try:
                    nmcli(["device", "wifi", "rescan"], timeout=8)
                except (NmError, subprocess.TimeoutExpired):
                    pass
            return self.snapshot()

        def done(data, error):
            if error is not None:
                self.syncing_switch = True
                switch.set_active(not wanted)
                self.syncing_switch = False
                self.set_busy(False, str(error))
                return False
            self.apply_snapshot(data)
            return False

        run_async(work, done)

    def on_row(self, _listbox, row):
        network = getattr(row, "network", None)
        if network is None or self.busy:
            return
        if network["connected"]:
            return
        if is_enterprise(network["security"]):
            self.set_status("Rede empresarial: use Ajustes")
            return
        ssid = network["ssid"]
        if ssid in self.saved or is_open(network["security"]):
            self.connect(ssid)
            return
        self.show_password(ssid)

    def connect(self, ssid, password=None):
        if self.busy:
            return
        self.set_busy(True, f"Conectando a {ssid}...")

        def work():
            connect_network(ssid, password)
            return self.snapshot()

        def done(data, error):
            if error is not None:
                self.set_busy(False, "Falha ao conectar")
                if needs_secrets(error):
                    self.show_password(ssid, f"Senha inválida ou ausente para {ssid}")
                else:
                    notify(f"Falha ao conectar a {ssid}")
                    self.set_status(str(error).splitlines()[0][:120])
                return False
            self.show_list()
            self.apply_snapshot(data)
            notify(f"Conectado a {ssid}")
            return False

        run_async(work, done)

    def submit_password(self):
        ssid = self.pending_ssid
        password = self.password_entry.get_text()
        if not ssid:
            self.show_list()
            return
        if not password:
            self.set_status("Informe a senha")
            return
        self.connect(ssid, password)

    def disconnect(self):
        if self.busy or not self.device:
            return
        device = self.device
        self.set_busy(True, "Desconectando...")

        def work():
            disconnect_device(device)
            return self.snapshot()

        def done(data, error):
            if error is not None:
                self.set_busy(False, str(error))
                return False
            self.apply_snapshot(data)
            notify("Wi-Fi desconectado")
            return False

        run_async(work, done)

    def open_editor(self, *_args):
        try:
            subprocess.Popen(["nm-connection-editor"])
        except OSError:
            self.set_status("nm-connection-editor não encontrado")
            return
        self.quit()

    def show(self):
        self.dismiss.show_all()
        self.popup.show_all()
        if self.monitor is not None:
            GtkLayerShell.set_monitor(self.dismiss, self.monitor)
            GtkLayerShell.set_monitor(self.popup, self.monitor)
        self.reload(False)
        self.want_rescan = True


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

    menu = WifiMenu(monitor_at_pointer())
    menu.show()
    Gtk.main()
    clear_pid()


if __name__ == "__main__":
    main()
