# Tokyo Night

配色源自社区流行的 Tokyo Night（深夜蓝底 + 霓虹蓝紫）。

- 索引：**1**（主题表第 2 套）
- 切换：`theme-next 1` 或 Super+Space → 外观 → 主题预览
- 壁纸：`wallpapers/02-tokyo-night.png` → `~/Pictures/wallpapers/02-tokyo-night.png`
- 预览图：`~/.local/share/hyprbuddy-os/theme-previews/preview-1.png`

## 角色配色

| 色值 | 角色 | 实际落点 |
|---|---|---|
| `#16161E` | 主面 | waybar 底、mako 卡片底、swayosd 底 |
| `#C0CAF5` | 正文 | waybar 前景、kitty 前景、mako 正文 |
| `#565F89` | 次文 | 未激活工作区文字 |
| `#1F2335` | 激活面 | 工作区激活/hover 底、分组胶囊底 |
| `#7AA2F7` | 强调文字 | 激活工作区文字、fuzzel match、分组描边 |
| `#7AA2F7` | 活动边框起色 | 活动边框渐变、polkit accent |
| `#BB9AF7` | 活动边框终色 | 活动边框渐变、polkit accent_secondary |
| `#565F89` | 非活动边框 | 非活动窗口边框 |
| `#F7768E` | 警示红 | urgent 工作区、mako critical |
| `#7DCFFF` | 时钟 | clock 模块 |
| `#9ECE6A` | CPU | cpu 模块 |
| `#E0AF68` | 内存 | memory 模块 |
| `#BB9AF7` | 电池 | battery 模块 |
| `#2AC3DE` | 音频 | pulseaudio 模块 |
| `#BB9AF7` | agent | agent 用量模块 |
| `#1A1B26` | 终端底 | kitty background |
| `#C0CAF5` | 终端正文 | kitty foreground |
| `#C0CAF5` | 终端光标 | kitty cursor |

活动边框：`rgba(7AA2F7ee) → rgba(BB9AF7ee) 45deg`。

## kitty ANSI 16 色

| idx | 值 | idx | 值 |
|---|---|---|---|
| 0 | `#15161E` | 8 | `#414868` |
| 1 | `#F7768E` | 9 | `#F7768E` |
| 2 | `#9ECE6A` | 10 | `#9ECE6A` |
| 3 | `#E0AF68` | 11 | `#E0AF68` |
| 4 | `#7AA2F7` | 12 | `#7AA2F7` |
| 5 | `#BB9AF7` | 13 | `#BB9AF7` |
| 6 | `#7DCFFF` | 14 | `#7DCFFF` |
| 7 | `#A9B1D6` | 15 | `#C0CAF5` |

## 壁纸

- 文件：`02-tokyo-night.png`
- 规格：2560×1440、8bit sRGB、3 通道（无 alpha）
- 明暗自检：mean=40（深色图）
- 内容见 `preview-1.png` 或直接打开该 PNG。

## 派生配色（不手填）

mako 卡片/描边/进度、fuzzel `[colors]`、swayosd 五色、hyprlock 变量、hyprtoolkit 认证框均由
`scripts/theme-next` 按上表的 WB_*/HA* 用 `mixhex` 推导。改配色只改主题表那一行，本文件同步更新。
