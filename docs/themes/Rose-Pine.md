# Rose Pine

配色源自 Rose Pine（玫瑰灰紫 + 松绿）。

- 索引：**3**（主题表第 4 套）
- 切换：`theme-next 3` 或 Super+Space → 外观 → 主题预览
- 壁纸：`wallpapers/04-rose-pine.png` → `~/Pictures/wallpapers/04-rose-pine.png`
- 预览图：`~/.local/share/hyprland-nixos/theme-previews/preview-3.png`

## 角色配色

| 色值 | 角色 | 实际落点 |
|---|---|---|
| `#191724` | 主面 | waybar 底、mako 卡片底、swayosd 底 |
| `#E0DEF4` | 正文 | waybar 前景、kitty 前景、mako 正文 |
| `#6E6A86` | 次文 | 未激活工作区文字 |
| `#2A283E` | 激活面 | 工作区激活/hover 底、分组胶囊底 |
| `#E0DEF4` | 强调文字 | 激活工作区文字、fuzzel match、分组描边 |
| `#9CCFD8` | 活动边框起色 | 活动边框渐变、polkit accent |
| `#C4A7E7` | 活动边框终色 | 活动边框渐变、polkit accent_secondary |
| `#6E6A86` | 非活动边框 | 非活动窗口边框 |
| `#EB6F92` | 警示红 | urgent 工作区、mako critical |
| `#9CCFD8` | 时钟 | clock 模块 |
| `#31748F` | CPU | cpu 模块 |
| `#F6C177` | 内存 | memory 模块 |
| `#C4A7E7` | 电池 | battery 模块 |
| `#EBBCBA` | 音频 | pulseaudio 模块 |
| `#C4A7E7` | agent | agent 用量模块 |
| `#191724` | 终端底 | kitty background |
| `#E0DEF4` | 终端正文 | kitty foreground |
| `#E0DEF4` | 终端光标 | kitty cursor |

活动边框：`rgba(9CCFD8ee) → rgba(C4A7E7ee) 45deg`。

## kitty ANSI 16 色

| idx | 值 | idx | 值 |
|---|---|---|---|
| 0 | `#191724` | 8 | `#6E6A86` |
| 1 | `#EB6F92` | 9 | `#EB6F92` |
| 2 | `#31748F` | 10 | `#31748F` |
| 3 | `#F6C177` | 11 | `#F6C177` |
| 4 | `#9CCFD8` | 12 | `#9CCFD8` |
| 5 | `#C4A7E7` | 13 | `#C4A7E7` |
| 6 | `#EBBCBA` | 14 | `#EBBCBA` |
| 7 | `#908CA4` | 15 | `#E0DEF4` |

## 壁纸

- 文件：`04-rose-pine.png`
- 规格：2560×1440、8bit sRGB、3 通道（无 alpha）
- 明暗自检：mean=104（中等明度）
- 内容见 `preview-3.png` 或直接打开该 PNG。

## 派生配色（不手填）

mako 卡片/描边/进度、fuzzel `[colors]`、swayosd 五色、hyprlock 变量、hyprtoolkit 认证框均由
`scripts/theme-next` 按上表的 WB_*/HA* 用 `mixhex` 推导。改配色只改主题表那一行，本文件同步更新。
