# WorkBuddy Dark

同一批 WorkBuddy 令牌的**暗色**切面：`#0A0A0A` 面 + `#28B894→#3B82F6` 渐变强调。

- 索引：**6**（主题表第 7 套）
- 切换：`theme-next 6` 或 Super+Space → 外观 → 主题预览
- 壁纸：`wallpapers/09-workbuddy-dark.png` → `~/Pictures/wallpapers/09-workbuddy-dark.png`
- 预览图：`~/.local/share/hyprland-nixos/theme-previews/preview-6.png`

## 角色配色

| 色值 | 角色 | 实际落点 |
|---|---|---|
| `#111417` | 主面 | waybar 底、mako 卡片底、swayosd 底 |
| `#F2F4F8` | 正文 | waybar 前景、kitty 前景、mako 正文 |
| `#8A8F98` | 次文 | 未激活工作区文字 |
| `#172A25` | 激活面 | 工作区激活/hover 底、分组胶囊底 |
| `#7CE0C0` | 强调文字 | 激活工作区文字、fuzzel match、分组描边 |
| `#1BC69B` | 活动边框起色 | 活动边框渐变、polkit accent |
| `#3B82F6` | 活动边框终色 | 活动边框渐变、polkit accent_secondary |
| `#2A2F36` | 非活动边框 | 非活动窗口边框 |
| `#FF6B6B` | 警示红 | urgent 工作区、mako critical |
| `#34D399` | 时钟 | clock 模块 |
| `#60A5FA` | CPU | cpu 模块 |
| `#A78BFA` | 内存 | memory 模块 |
| `#4ADE80` | 电池 | battery 模块 |
| `#2DD4BF` | 音频 | pulseaudio 模块 |
| `#8B5CF6` | agent | agent 用量模块 |
| `#0E1116` | 终端底 | kitty background |
| `#E6EAF0` | 终端正文 | kitty foreground |
| `#1BC69B` | 终端光标 | kitty cursor |

活动边框：`rgba(1BC69Bee) → rgba(3B82F6ee) 45deg`。

## kitty ANSI 16 色

| idx | 值 | idx | 值 |
|---|---|---|---|
| 0 | `#0E1116` | 8 | `#6B7280` |
| 1 | `#FF6B6B` | 9 | `#FF8787` |
| 2 | `#34D399` | 10 | `#6EE7B7` |
| 3 | `#E3B341` | 11 | `#F2CC60` |
| 4 | `#60A5FA` | 12 | `#93C5FD` |
| 5 | `#A78BFA` | 13 | `#C4B5FD` |
| 6 | `#2DD4BF` | 14 | `#5EEAD4` |
| 7 | `#C9D1D9` | 15 | `#F8FAFC` |

## 壁纸

- 文件：`09-workbuddy-dark.png`
- 规格：2560×1440、8bit sRGB、3 通道（无 alpha）
- 明暗自检：mean=42（深色图）
- 内容见 `preview-6.png` 或直接打开该 PNG。

## 派生配色（不手填）

mako 卡片/描边/进度、fuzzel `[colors]`、swayosd 五色、hyprlock 变量、hyprtoolkit 认证框均由
`scripts/theme-next` 按上表的 WB_*/HA* 用 `mixhex` 推导。改配色只改主题表那一行，本文件同步更新。
