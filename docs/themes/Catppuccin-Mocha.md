# Catppuccin Mocha

配色源自 Catppuccin 的 Mocha 变体（低饱和奶油暗色）。

- 索引：**2**（主题表第 3 套）
- 切换：`theme-next 2` 或 Super+Space → 外观 → 主题预览
- 壁纸：`wallpapers/03-catppuccin-mocha.png` → `~/Pictures/wallpapers/03-catppuccin-mocha.png`
- 预览图：`~/.local/share/hyprland-nixos/theme-previews/preview-2.png`

## 角色配色

| 色值 | 角色 | 实际落点 |
|---|---|---|
| `#1E1E2E` | 主面 | waybar 底、mako 卡片底、swayosd 底 |
| `#CDD6F4` | 正文 | waybar 前景、kitty 前景、mako 正文 |
| `#6C7086` | 次文 | 未激活工作区文字 |
| `#313244` | 激活面 | 工作区激活/hover 底、分组胶囊底 |
| `#CDD6F4` | 强调文字 | 激活工作区文字、fuzzel match、分组描边 |
| `#89B4FA` | 活动边框起色 | 活动边框渐变、polkit accent |
| `#CBA6F7` | 活动边框终色 | 活动边框渐变、polkit accent_secondary |
| `#6C7086` | 非活动边框 | 非活动窗口边框 |
| `#F38BA8` | 警示红 | urgent 工作区、mako critical |
| `#89DCEB` | 时钟 | clock 模块 |
| `#A6E3A1` | CPU | cpu 模块 |
| `#F9E2AF` | 内存 | memory 模块 |
| `#CBA6F7` | 电池 | battery 模块 |
| `#94E2D5` | 音频 | pulseaudio 模块 |
| `#CBA6F7` | agent | agent 用量模块 |
| `#1E1E2E` | 终端底 | kitty background |
| `#CDD6F4` | 终端正文 | kitty foreground |
| `#F5E0DC` | 终端光标 | kitty cursor |

活动边框：`rgba(89B4FAee) → rgba(CBA6F7ee) 45deg`。

## kitty ANSI 16 色

| idx | 值 | idx | 值 |
|---|---|---|---|
| 0 | `#45475A` | 8 | `#585B70` |
| 1 | `#F38BA8` | 9 | `#F38BA8` |
| 2 | `#A6E3A1` | 10 | `#A6E3A1` |
| 3 | `#F9E2AF` | 11 | `#F9E2AF` |
| 4 | `#89B4FA` | 12 | `#89B4FA` |
| 5 | `#CBA6F7` | 13 | `#CBA6F7` |
| 6 | `#94E2D5` | 14 | `#94E2D5` |
| 7 | `#BAC2DE` | 15 | `#CDD6F4` |

## 壁纸

- 文件：`03-catppuccin-mocha.png`
- 规格：2560×1440、8bit sRGB、3 通道（无 alpha）
- 明暗自检：mean=141（偏亮）
- 内容见 `preview-2.png` 或直接打开该 PNG。

## 派生配色（不手填）

mako 卡片/描边/进度、fuzzel `[colors]`、swayosd 五色、hyprlock 变量、hyprtoolkit 认证框均由
`scripts/theme-next` 按上表的 WB_*/HA* 用 `mixhex` 推导。改配色只改主题表那一行，本文件同步更新。
