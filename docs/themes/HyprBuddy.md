# HyprBuddy

变形金刚 / 赛博坦金属风的深色主题。索引 **7**（主题表第 8 套）。

- 切换：`theme-next 7` 或 Super+Space → 外观 → 主题预览（选第 8 项）
- 壁纸：`wallpapers/10-hyprbuddy.png` → `~/Pictures/wallpapers/10-hyprbuddy.png`
- 预览图：`~/.local/share/hyprland-nixos/theme-previews/preview-7.png`

## 角色配色

| 色值 | 角色 | 实际落点 |
|---|---|---|
| `#12161B` | 枪灰钢面（主面） | waybar 底、mako 卡片底、swayosd 底 |
| `#0F1318` | 更深的装甲底 | kitty 背景、color0 |
| `#D7DEE8` | 银白正文 | waybar 前景、kitty 前景、mako 正文 |
| `#6E7A8A` | 哑光钢灰 | 未激活工作区文字 |
| `#1B2A33` | 能量浸润面 | 工作区激活/hover 底、分组胶囊底 |
| `#35E0FF` | 能量青（主强调） | 激活工作区文字、clock、kitty 光标、polkit accent、活动边框起色 |
| `#E03A2F` | 汽车人红（次强调） | urgent 文字、pulse 系、polkit accent_secondary、活动边框终色 |
| `#F5B301` | 警戒黄 | cpu |
| `#9B5CFF` | 霸天虎紫 | memory |
| `#3DDC97` | 能量绿 | battery |
| `#FF7A45` | 热橙 | pulseaudio |
| `#B9C6D4` | 镀铬银 | agent 用量 |
| `#3A424D` | 钢灰 | 非活动窗口边框 |

活动边框：`rgba(35E0FFee) → rgba(E03A2Fee) 45deg`（能量青 → 汽车人红渐变）。

## kitty ANSI 16 色

| idx | 值 | idx | 值 |
|---|---|---|---|
| 0 | `#0F1318` | 8 | `#5A6675` |
| 1 | `#E03A2F` | 9 | `#FF6B5E` |
| 2 | `#3DDC97` | 10 | `#6EE7B7` |
| 3 | `#F5B301` | 11 | `#FFCC4D` |
| 4 | `#4A9EFF` | 12 | `#7CC0FF` |
| 5 | `#9B5CFF` | 13 | `#C0A0FF` |
| 6 | `#35E0FF` | 14 | `#6FF2FF` |
| 7 | `#A9B6C6` | 15 | `#E8EEF5` |

## 壁纸

- 内容：赛博坦装甲板分层、板缝漏出能量青光、少量汽车人红条灯与警戒黄标识、拉丝金属高光
- 生成：ImageGen（1536×1024）→ `magick` 裁切缩放到 **2560×1440 / 8bit / 3 通道（无 alpha）**
- 自检：`identify -format '%wx%h %[channels] %[bit-depth]bit mean=%[fx:int(mean*255)]'` → mean≈30（确认为深图）

## 派生配色（不手填）

mako 卡片/描边/进度、fuzzel `[colors]`、swayosd 五色、hyprlock 变量、hyprtoolkit 认证框
都由 `scripts/theme-next` 按上表的 WB_*/HA* 用 `mixhex` 推导；改主题只需改主题表那一行。
