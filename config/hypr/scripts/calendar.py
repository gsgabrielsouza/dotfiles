#!/usr/bin/env python3
import atexit
import datetime
import json
import locale
import os
import signal
import subprocess
import sys
import time

PID_PATH = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "waybar-calendar.pid")


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
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell

locale.setlocale(locale.LC_ALL, "")

CSS = """
#calendar-popup {
  background-color: alpha(#24273a, 1);
  border: 1px solid #8aadf4;
  border-radius: 6px;
}
#calendar-popup box {
  padding: 8px;
}
calendar {
  /* background-color: transparent; */
  color: #cad3f5;
  font-family: "JetBrains Mono Nerd", monospace;
  font-size: 16px;
}
calendar:selected {
  background-color: #eed49f;
  color: #24273a;
}
calendar.header {
  background-color: transparent;
  color: #8aadf4;
}
calendar.button, calendar.button:hover {
  color: #8aadf4;
  background-color: transparent;
}
calendar.highlight {
  color: #8aadf4;
}
calendar:indeterminate {
  color: #6e738d;
}
#calendar-dismiss {
  background-color: transparent;
}
"""


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
    x, y = hypr_mon["x"], hypr_mon["y"]
    return display.get_monitor_at_point(x, y)


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


def shift_month(calendar, delta):
    year, month, _day = calendar.get_date()
    month += delta
    while month > 11:
        month -= 12
        year += 1
    while month < 0:
        month += 12
        year -= 1
    calendar.select_month(month, year)


def mark_today(calendar):
    calendar.clear_marks()
    today = datetime.date.today()
    year, month, _day = calendar.get_date()
    if year == today.year and month + 1 == today.month:
        calendar.mark_day(today.day)


def on_scroll(calendar, event):
    delta = 0
    if event.direction == Gdk.ScrollDirection.SMOOTH:
        if event.delta_y < -0.1:
            delta = -1
        elif event.delta_y > 0.1:
            delta = 1
    elif event.direction == Gdk.ScrollDirection.UP:
        delta = -1
    elif event.direction == Gdk.ScrollDirection.DOWN:
        delta = 1
    if delta == 0:
        return False
    shift_month(calendar, delta)
    return True


def main():
    write_pid()
    atexit.register(clear_pid)
    ignore_until = time.monotonic() + 0.25

    def quit_app(*_args):
        Gtk.main_quit()
        return True

    def quit_from_dismiss(*_args):
        if time.monotonic() < ignore_until:
            return True
        return quit_app()

    signal.signal(signal.SIGTERM, lambda *_: GLib.idle_add(Gtk.main_quit))
    signal.signal(signal.SIGINT, lambda *_: GLib.idle_add(Gtk.main_quit))

    css = Gtk.CssProvider()
    css.load_from_data(CSS.encode("utf-8"))
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        css,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    monitor = monitor_at_pointer()

    dismiss = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
    dismiss.set_name("calendar-dismiss")
    dismiss.set_decorated(False)
    dismiss.set_resizable(False)
    apply_rgba(dismiss)
    init_layer(dismiss, "waybar-calendar-dismiss", monitor)
    for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
        GtkLayerShell.set_anchor(dismiss, edge, True)
    dismiss.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
    dismiss.connect("button-press-event", quit_from_dismiss)

    popup = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
    popup.set_name("calendar-popup")
    popup.set_decorated(False)
    popup.set_resizable(False)
    apply_rgba(popup)
    init_layer(popup, "waybar-calendar", monitor)
    GtkLayerShell.set_anchor(popup, GtkLayerShell.Edge.TOP, True)
    GtkLayerShell.set_anchor(popup, GtkLayerShell.Edge.RIGHT, True)
    GtkLayerShell.set_margin(popup, GtkLayerShell.Edge.TOP, 1)
    GtkLayerShell.set_margin(popup, GtkLayerShell.Edge.RIGHT, 8)
    GtkLayerShell.set_keyboard_mode(popup, GtkLayerShell.KeyboardMode.ON_DEMAND)
    popup.connect("key-press-event", lambda _w, event: quit_app() if event.keyval == Gdk.KEY_Escape else False)

    calendar = Gtk.Calendar()
    calendar.set_display_options(
        Gtk.CalendarDisplayOptions.SHOW_HEADING | Gtk.CalendarDisplayOptions.SHOW_DAY_NAMES
    )
    calendar.add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.SMOOTH_SCROLL_MASK)
    calendar.connect("month-changed", lambda _cal: mark_today(calendar))
    calendar.connect("scroll-event", on_scroll)
    mark_today(calendar)

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    box.add(calendar)
    popup.add(box)

    dismiss.show_all()
    popup.show_all()
    if monitor is not None:
        GtkLayerShell.set_monitor(dismiss, monitor)
        GtkLayerShell.set_monitor(popup, monitor)
    Gtk.main()
    clear_pid()


if __name__ == "__main__":
    main()
