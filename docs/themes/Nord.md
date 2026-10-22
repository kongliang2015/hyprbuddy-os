# Nord

配色源自 Nord（极地蓝灰）。

- 索引：**4**（主题表第 5 套）
- 切换：`theme-next 4` 或 Super+Space → 外观 → 主题预览
- 壁纸：`wallpapers/05-nord.png` → `~/Pictures/wallpapers/05-nord.png`
- 预览图：`~/.local/share/hyprland-nixos/theme-previews/preview-4.png`

## 角色配色

| 色值 | 角色 | 实际落点 |
|---|---|---|
| `#2E3440` | 主面 | waybar 底、mako 卡片底、swayosd 底 |
| `#D8DEE9` | 正文 | waybar 前景、kitty 前景、mako 正文 |
| `#4C566A` | 次文 | 未激活工作区文字 |
| `#3B4252` | 激活面 | 工作区激活/hover 底、分组胶囊底 |
| `#D8DEE9` | 强调文字 | 激活工作区文字、fuzzel match、分组描边 |
| `#81A1C1` | 活动边框起色 | 活动边框渐变、polkit accent |
| `#B48EAD` | 活动边框终色 | 活动边框渐变、polkit accent_secondary |
| `#4C566A` | 非活动边框 | 非活动窗口边框 |
| `#BF616A` | 警示红 | urgent 工作区、mako critical |
| `#88C0D0` | 时钟 | clock 模块 |
| `#A3BE8C` | CPU | cpu 模块 |
| `#EBCB8B` | 内存 | memory 模块 |
| `#B48EAD` | 电池 | battery 模块 |
| `#8FBCBB` | 音频 | pulseaudio 模块 |
| `#B48EAD` | agent | agent 用量模块 |
| `#2E3440` | 终端底 | kitty background |
| `#D8DEE9` | 终端正文 | kitty foreground |
| `#D8DEE9` | 终端光标 | kitty cursor |

活动边框：`rgba(81A1C1ee) → rgba(B48EADee) 45deg`。

## kitty ANSI 16 色

| idx | 值 | idx | 值 |
|---|---|---|---|
| 0 | `#2E3440` | 8 | `#4C566A` |
| 1 | `#BF616A` | 9 | `#BF616A` |
| 2 | `#A3BE8C` | 10 | `#A3BE8C` |
| 3 | `#EBCB8B` | 11 | `#EBCB8B` |
| 4 | `#81A1C1` | 12 | `#81A1C1` |
| 5 | `#B48EAD` | 13 | `#B48EAD` |
| 6 | `#8FBCBB` | 14 | `#8FBCBB` |
| 7 | `#E5E9F0` | 15 | `#ECEFF4` |

## 壁纸

- 文件：`05-nord.png`
- 规格：2560×1440、8bit sRGB、3 通道（无 alpha）
- 明暗自检：mean=88（中等明度）
- 内容见 `preview-4.png` 或直接打开该 PNG。

## 派生配色（不手填）

mako 卡片/描边/进度、fuzzel `[colors]`、swayosd 五色、hyprlock 变量、hyprtoolkit 认证框均由
`scripts/theme-next` 按上表的 WB_*/HA* 用 `mixhex` 推导。改配色只改主题表那一行，本文件同步更新。
