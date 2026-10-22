# Kanagawa

配色源自同名 Neovim 配色方案 Kanagawa（墨色底 + 蓝紫强调）。**默认主题**（索引 0）。

- 索引：**0**（主题表第 1 套）
- 切换：`theme-next 0` 或 Super+Space → 外观 → 主题预览
- 壁纸：`wallpapers/01-kanagawa.png` → `~/Pictures/wallpapers/01-kanagawa.png`
- 预览图：`~/.local/share/hyprland-nixos/theme-previews/preview-0.png`

## 角色配色

| 色值 | 角色 | 实际落点 |
|---|---|---|
| `#16161D` | 主面 | waybar 底、mako 卡片底、swayosd 底 |
| `#DCD7BA` | 正文 | waybar 前景、kitty 前景、mako 正文 |
| `#54546D` | 次文 | 未激活工作区文字 |
| `#2A2A37` | 激活面 | 工作区激活/hover 底、分组胶囊底 |
| `#DCD7BA` | 强调文字 | 激活工作区文字、fuzzel match、分组描边 |
| `#7E9CD8` | 活动边框起色 | 活动边框渐变、polkit accent |
| `#957FB8` | 活动边框终色 | 活动边框渐变、polkit accent_secondary |
| `#54546D` | 非活动边框 | 非活动窗口边框 |
| `#FF5D62` | 警示红 | urgent 工作区、mako critical |
| `#7AA89F` | 时钟 | clock 模块 |
| `#76946A` | CPU | cpu 模块 |
| `#DCA561` | 内存 | memory 模块 |
| `#957FB8` | 电池 | battery 模块 |
| `#7E9CD8` | 音频 | pulseaudio 模块 |
| `#957FB8` | agent | agent 用量模块 |
| `#1F1F28` | 终端底 | kitty background |
| `#DCD7BA` | 终端正文 | kitty foreground |
| `#DCD7BA` | 终端光标 | kitty cursor |

活动边框：`rgba(7E9CD8ee) → rgba(957FB8ee) 45deg`。

## kitty ANSI 16 色

| idx | 值 | idx | 值 |
|---|---|---|---|
| 0 | `#1F1F28` | 8 | `#717C7C` |
| 1 | `#C34043` | 9 | `#C34043` |
| 2 | `#76946A` | 10 | `#76946A` |
| 3 | `#C0A36E` | 11 | `#C0A36E` |
| 4 | `#7E9CD8` | 12 | `#7E9CD8` |
| 5 | `#957FB8` | 13 | `#957FB8` |
| 6 | `#6A9589` | 14 | `#6A9589` |
| 7 | `#C5C9C5` | 15 | `#DCD7BA` |

## 壁纸

- 文件：`01-kanagawa.png`
- 规格：2560×1440、8bit sRGB、3 通道（无 alpha）
- 明暗自检：mean=77（中等明度）
- 内容见 `preview-0.png` 或直接打开该 PNG。

## 派生配色（不手填）

mako 卡片/描边/进度、fuzzel `[colors]`、swayosd 五色、hyprlock 变量、hyprtoolkit 认证框均由
`scripts/theme-next` 按上表的 WB_*/HA* 用 `mixhex` 推导。改配色只改主题表那一行，本文件同步更新。
