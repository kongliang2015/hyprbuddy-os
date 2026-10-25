-- Hyprland 用户配置（Lua 配置管理器）
-- 迁移自 hyprland.conf：hyprshell 的自注册键位需要 Lua 配置管理器（eval dispatcher）。
-- 改完执行 hyprctl reload；若 Lua 报错，删掉本文件即可回退到 hyprland.conf。

local home = os.getenv("HOME")
local mainMod = "SUPER"

-- ── 启动项 ────────────────────────────────────────────────
-- 壁纸守护 / waybar 由 theme-next restore 内部拉起，避免与 restore 的 pkill 竞态。
hl.on("hyprland.start", function()
    hl.exec_cmd(home .. "/.local/bin/theme-next restore")
    hl.exec_cmd("swaync")
    hl.exec_cmd("eww daemon")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprsunset")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("hyprshell run")   -- 窗口总览 Super+`；热键由 hyprshell 自己注册（需 Lua 管理器）
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-- ── 环境变量 ──────────────────────────────────────────────
hl.env("XCURSOR_SIZE", "24")
hl.env("GTK_THEME", "Adwaita:dark")

-- ── 外观 ──────────────────────────────────────────────────
hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
        },
    },
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        resize_on_border = true,
        col = {
            active_border = { colors = { "rgba(7aa2f7ee)", "rgba(bb9af7ee)" }, angle = 45 },
            inactive_border = "rgba(565f89aa)",
        },
    },
    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 0.95,
        blur = { enabled = true, size = 8, passes = 2, new_optimizations = true },
        shadow = { enabled = true, range = 4, render_power = 3, color = "rgba(00000099)" },
    },
    dwindle = { force_split = 0 },
})

hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 6, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 6, bezier = "easeInOutCubic", style = "slide" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "easeOutQuint", style = "slidefade" })

-- ── 快捷键 ────────────────────────────────────────────────
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("fuzzel"))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(home .. "/.local/bin/hypr-menu"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(home .. "/.local/bin/theme-next"))
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(home .. "/.local/bin/eww-popup calendar"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(home .. "/.local/bin/eww-popup session"))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 0"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))
hl.bind(mainMod .. " + ALT + left", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -30 0"))
hl.bind(mainMod .. " + ALT + right", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 30 0"))
hl.bind(mainMod .. " + ALT + up", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -30"))
hl.bind(mainMod .. " + ALT + down", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 30"))

for i = 1, 4 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m output"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(home .. "/.local/bin/screenshot-annotate"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(home .. "/.local/bin/night-mode"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(home .. "/.local/bin/record-toggle"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(home .. "/.local/bin/wallpaper-next"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"))
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))

-- ── 窗口 / 图层规则 ───────────────────────────────────────
hl.window_rule({ name = "keybinds-popup", match = { class = "^(keybinds-popup)$" },
                 float = true, center = true, size = "monitor_w*0.72 monitor_h*0.72" })
hl.window_rule({ name = "theme-picker", match = { class = "^(theme-picker)$" },
                 float = true, center = true, size = "monitor_w*0.92 monitor_h*0.55" })
hl.window_rule({ name = "fastfetch-popup", match = { class = "^(fastfetch-popup)$" },
                 float = true, center = true })

hl.layer_rule({ name = "menu-blur", match = { namespace = "^hypr-menu$" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ name = "menu-dim", match = { namespace = "^hypr-menu$" }, dim_around = true, no_anim = true })
hl.layer_rule({ name = "notif-blur", match = { namespace = "^swaync-notification-window$" }, blur = true, ignore_alpha = 0.5 })

-- ── 主题生成的边框色（theme-next 写入；Lua 管理器下 keyword 不可用）──
pcall(dofile, home .. "/.config/hypr/theme.lua")

-- ── 发行版生成的条件片段（亮度键 / 终端 / agent）──────────
local extra = home .. "/.config/hypr/extra.lua"
local ok, err = pcall(dofile, extra)
if not ok then
    -- 片段缺失（比如 install.sh 还没跑）时不让整份配置加载失败
    print("hyprland.lua: 跳过 extra.lua: " .. tostring(err))
end
