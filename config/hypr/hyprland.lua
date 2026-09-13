local c = require("macchiato")

local monitorL = "eDP-1"
local monitorR = "HDMI-A-1"

hl.monitor({
    output = monitorL,
    mode = "1920x1080@120",
    position = "0x0",
    scale = 1,
})

hl.monitor({
    output = monitorR,
    mode = "preferred",
    position = "auto-up",
    scale = 1,
})

hl.monitor({
    output = "DP-1",
    mode = "preferred",
    position = "auto-right",
    scale = 1,
})

local terminal = "foot"
local fileManager = "nemo"
local menu = "wofi --show drun"
local browser = "microsoft-edge-stable --ozone-platform-hint=auto"
local waybar = os.getenv("HOME") .. "/.config/hypr/scripts/start-waybar.sh"
local wallpaperScript = os.getenv("HOME") .. "/.config/hypr/scripts/wallpaper.sh"
local osdScript = os.getenv("HOME") .. "/.config/hypr/scripts/osd.sh"

hl.exec_cmd('gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"')
hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"')
hl.exec_cmd("pgrep -x hyprpaper >/dev/null || hyprpaper")
hl.exec_cmd("pgrep -x hypridle >/dev/null || hypridle")
hl.exec_cmd("pgrep -x dunst >/dev/null || dunst")
hl.exec_cmd("pgrep -x gnome-keyring-d >/dev/null || gnome-keyring-daemon --start --components=pkcs11,secrets")
hl.exec_cmd("pgrep -f polkit-kde-authentication-agent-1 >/dev/null || /usr/lib/polkit-kde-authentication-agent-1")
hl.exec_cmd(wallpaperScript .. " daemon")

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("pgrep -x hyprpaper >/dev/null || hyprpaper")
    hl.exec_cmd("pgrep -x hypridle >/dev/null || hypridle")
    hl.exec_cmd("systemctl --user restart dunst.service")
    hl.timer(function()
        hl.exec_cmd("pgrep -x waybar >/dev/null || " .. waybar)
    end, { timeout = 400, type = "oneshot" })
    hl.exec_cmd(wallpaperScript .. " daemon")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/clipboard-watch.sh")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/bt-autoconnect.sh")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/bt-audio-watch.sh")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/mount-windows.sh")
    hl.exec_cmd("pgrep -x gnome-keyring-d >/dev/null || gnome-keyring-daemon --start --components=pkcs11,secrets")
    hl.exec_cmd("pgrep -f polkit-kde-authentication-agent-1 >/dev/null || /usr/lib/polkit-kde-authentication-agent-1")
end)

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_SIZE", "20")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("BROWSER", "microsoft-edge-stable")

hl.config({
    cursor = {
        inactive_timeout = 3,
        no_hardware_cursors = true,
    },
    general = {
        gaps_in = 1,
        gaps_out = 1,
        border_size = 1,
        col = {
            inactive_border = "rgba(" .. c.sapphire .. "4d)",
            active_border = "rgba(" .. c.blue .. "ee)",
        },
        layout = "dwindle",
        allow_tearing = false,
        resize_on_border = true,
        extend_border_grab_area = 15,
    },
    decoration = {
        rounding = 5,
        rounding_power = 5,
        active_opacity = 1,
        inactive_opacity = 0.9,
        shadow = {
            enabled = true,
        },
        blur = {
            enabled = true,
            size = 1,
            passes = 3,
            popups = true,
            new_optimizations = true,
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = false,
        animate_manual_resizes = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
    },
    input = {
        kb_layout = "br",
        kb_variant = "abnt2",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        repeat_rate = 40,
        repeat_delay = 300,
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 8, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 2, bezier = "easeInOutCubic", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2, bezier = "easeInOutCubic", style = "slide" })

hl.workspace_rule({ workspace = "1", monitor = monitorL, default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = monitorL, persistent = true })
hl.workspace_rule({ workspace = "3", monitor = monitorL, persistent = true })
hl.workspace_rule({ workspace = "4", monitor = monitorL, persistent = true })
hl.workspace_rule({ workspace = "5", monitor = monitorL, persistent = true })

local rightWsRules = {}
for i = 6, 10 do
    rightWsRules[i] = {
        hdmi = hl.workspace_rule({
            workspace = tostring(i),
            monitor = monitorR,
            persistent = true,
            default = i == 6,
            enabled = false,
        }),
        laptop = hl.workspace_rule({
            workspace = tostring(i),
            monitor = monitorL,
            persistent = true,
            enabled = false,
        }),
    }
end

local assignTimer = nil

local function assignRightWorkspaces()
    local hdmi = hl.get_monitor(monitorR) ~= nil
    local target = hdmi and monitorR or monitorL
    local focused = hl.get_active_monitor()
    local focusedName = focused and focused.name or nil
    local keepL = nil
    local keepR = nil
    local activeL = hl.get_active_workspace(monitorL)
    if activeL then
        keepL = activeL.id
    end
    if hdmi then
        local activeR = hl.get_active_workspace(monitorR)
        if activeR then
            keepR = activeR.id
        end
    end

    for i = 6, 10 do
        local rules = rightWsRules[i]
        rules.hdmi:set_enabled(hdmi)
        rules.laptop:set_enabled(not hdmi)
        hl.dispatch(hl.dsp.workspace.move({ workspace = i, monitor = target }))
    end

    if keepL then
        hl.dispatch(hl.dsp.focus({ workspace = keepL }))
    end
    if keepR and hdmi then
        hl.dispatch(hl.dsp.focus({ workspace = keepR }))
    end
    if focusedName and hl.get_monitor(focusedName) then
        hl.dispatch(hl.dsp.focus({ monitor = focusedName }))
    end
end

local function scheduleAssignRightWorkspaces()
    if assignTimer then
        assignTimer:set_enabled(false)
    end
    assignTimer = hl.timer(function()
        assignRightWorkspaces()
    end, { timeout = 250, type = "oneshot" })
end

scheduleAssignRightWorkspaces()
hl.on("hyprland.start", scheduleAssignRightWorkspaces)
hl.on("monitor.added", scheduleAssignRightWorkspaces)
hl.on("monitor.removed", scheduleAssignRightWorkspaces)
hl.on("monitor.layout_changed", scheduleAssignRightWorkspaces)
hl.on("config.reloaded", scheduleAssignRightWorkspaces)

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/open-windows.sh"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(wallpaperScript .. " next"))
-- hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd(wallpaperScript .. " prev"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(menu))
-- hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd('cliphist list | wofi --dmenu --prompt clipboard | cliphist decode | wl-copy'))
hl.bind(mainMod .. " + slash", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())
hl.bind(mainMod .. " + minus", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"), { locked = true })

hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CTRL + left", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CTRL + SHIFT + right", hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mainMod .. " + CTRL + SHIFT + left", hl.dsp.window.move({ workspace = "m-1" }))

hl.bind(mainMod .. " + ALT + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + L", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + H", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + J", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + K", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })

hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    hl.bind("right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })
    hl.bind("left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
    hl.bind("up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
    hl.bind("down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true })
    hl.bind("L", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })
    hl.bind("H", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
    hl.bind("K", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
    hl.bind("J", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true })
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)

local function workspaceForSlot(slot)
    local mon = hl.get_active_monitor()
    if mon and mon.name == monitorR then
        return slot + 5
    end
    return slot
end

for i = 1, 5 do
    hl.bind(mainMod .. " + " .. i, function()
        hl.dispatch(hl.dsp.focus({ workspace = workspaceForSlot(i) }))
    end)
    hl.bind(mainMod .. " + SHIFT + " .. i, function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspaceForSlot(i) }))
    end)
end

for i = 6, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("pgrep -x waybar >/dev/null && killall -SIGUSR1 waybar || " .. waybar), { release = true })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("dunstctl history-pop"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("dunstctl close-all"))
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m region --freeze --clipboard-only"))
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m region --freeze -o " .. os.getenv("HOME") .. "/Pictures/Screenshots"))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "m-1" }))

local logitechVol = {
    device = { inclusive = true, list = { "logitech-signature-m650" } },
    locked = true,
    repeating = true,
}

hl.bind("mouse:276", hl.dsp.exec_cmd(osdScript .. " volume-up"), logitechVol)
hl.bind("mouse:275", hl.dsp.exec_cmd(osdScript .. " volume-down"), logitechVol)
hl.bind("mouse_right", hl.dsp.exec_cmd(osdScript .. " volume-up"), logitechVol)
hl.bind("mouse_left", hl.dsp.exec_cmd(osdScript .. " volume-down"), logitechVol)

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(osdScript .. " volume-up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(osdScript .. " volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(osdScript .. " volume-mute"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(osdScript .. " brightness-up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(osdScript .. " brightness-down"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true })

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("systemctl suspend"), { locked = true })

local lidBind = { locked = true }

hl.bind("switch:on:Lid Switch", function()
    hl.dispatch(hl.dsp.dpms({ action = "off" }))
    hl.exec_cmd("systemctl suspend")
end, lidBind)

hl.bind("switch:off:Lid Switch", function()
    hl.dispatch(hl.dsp.dpms({ action = "on" }))
end, lidBind)

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.layer_rule({
    name = "wofi-blur",
    match = { namespace = "^wofi$" },
    blur = true,
    ignore_alpha = 0.2,
})
