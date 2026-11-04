# WorkBuddy

取色自 workbuddy.cn 官网设计令牌（`--wb2-*`）的**浅色**面：主色 `#00C29A`、面 `#FFF`、文字 `#1A1A1A`。浅色主题，agent-theme-sync 会自动收到 light。

- 索引：**5**（主题表第 6 套）
- 切换：`theme-next 5` 或 Super+Space → 外观 → 主题预览
- 壁纸：`wallpapers/08-workbuddy-light.png` → `~/Pictures/wallpapers/08-workbuddy-light.png`
- 预览图：`~/.local/share/hyprbuddy-os/theme-previews/preview-5.png`

## 角色配色

| 色值 | 角色 | 实际落点 |
|---|---|---|
| `#FFFFFF` | 主面 | waybar 底、mako 卡片底、swayosd 底 |
| `#1A1A1A` | 正文 | waybar 前景、kitty 前景、mako 正文 |
| `#646464` | 次文 | 未激活工作区文字 |
| `#DDF0EC` | 激活面 | 工作区激活/hover 底、分组胶囊底 |
| `#009273` | 强调文字 | 激活工作区文字、fuzzel match、分组描边 |
| `#00C29A` | 活动边框起色 | 活动边框渐变、polkit accent |
| `#3B82F6` | 活动边框终色 | 活动边框渐变、polkit accent_secondary |
| `#BDBDBD` | 非活动边框 | 非活动窗口边框 |
| `#D14343` | 警示红 | urgent 工作区、mako critical |
| `#009273` | 时钟 | clock 模块 |
| `#1F6FEB` | CPU | cpu 模块 |
| `#8B5CF6` | 内存 | memory 模块 |
| `#079D55` | 电池 | battery 模块 |
| `#00A383` | 音频 | pulseaudio 模块 |
| `#6C4DFF` | agent | agent 用量模块 |
| `#FFFFFF` | 终端底 | kitty background |
| `#1A1A1A` | 终端正文 | kitty foreground |
| `#00C29A` | 终端光标 | kitty cursor |

活动边框：`rgba(00C29Aee) → rgba(3B82F6ee) 45deg`。

## kitty ANSI 16 色

| idx | 值 | idx | 值 |
|---|---|---|---|
| 0 | `#1A1A1A` | 8 | `#8B949E` |
| 1 | `#CF3B45` | 9 | `#E5534B` |
| 2 | `#0E8F55` | 10 | `#2DA44E` |
| 3 | `#9A6700` | 11 | `#BF8700` |
| 4 | `#1F6FEB` | 12 | `#4C8DFF` |
| 5 | `#8250DF` | 13 | `#A475F9` |
| 6 | `#009273` | 14 | `#12A594` |
| 7 | `#57606A` | 15 | `#1A1A1A` |

## 壁纸

- 文件：`08-workbuddy-light.png`
- 规格：2560×1440、8bit sRGB、3 通道（无 alpha）
- 明暗自检：mean=234（偏亮）
- 内容见 `preview-5.png` 或直接打开该 PNG。

## 派生配色（不手填）

mako 卡片/描边/进度、fuzzel `[colors]`、swayosd 五色、hyprlock 变量、hyprtoolkit 认证框均由
`scripts/theme-next` 按上表的 WB_*/HA* 用 `mixhex` 推导。改配色只改主题表那一行，本文件同步更新。
