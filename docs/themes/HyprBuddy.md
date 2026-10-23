# HyprBuddy

取自项目主视觉图（深黑底 + 霓虹青 / 品红 / 长春花紫）的深色主题。索引 **7**（主题表第 8 套）。

- 切换：`theme-next 7` 或 Super+Space → 外观 → 主题预览
- 壁纸：`wallpapers/10-hyprbuddy.png` → `~/Pictures/wallpapers/10-hyprbuddy.png`
- 预览图：`~/.local/share/hyprland-nixos/theme-previews/preview-7.png`

## 角色配色

| 色值 | 角色 | 实际落点 |
|---|---|---|
| `#0D0F10` | 主面 | waybar 底、mako 卡片底、swayosd 底 |
| `#0A0C0D` | 终端底 | kitty 背景、color0 |
| `#C6CDD0` | 冷白正文 | waybar 前景、kitty 前景、mako 正文 |
| `#5A656A` | 钢灰 | 未激活工作区文字 |
| `#14323A` | 青色浸润面 | 工作区激活/hover 底、分组胶囊底 |
| `#02F0FA` | 霓虹青（主强调） | 激活工作区文字、clock、kitty 光标、polkit accent、活动边框起色 |
| `#E926F5` | 品红（次强调） | pulseaudio、polkit accent_secondary、活动边框终色 |
| `#A19AF4` | 长春花紫 | cpu |
| `#9565E1` | 紫罗兰 | memory |
| `#39C6FF` | 天蓝 | battery |
| `#99A4AA` | 中性灰 | agent 用量 |
| `#FF5C7A` | 警示粉红 | urgent 工作区、mako critical |
| `#292C2E` | 深钢灰 | 非活动窗口边框 |

活动边框：`rgba(02F0FAee) → rgba(E926F5ee) 45deg`（霓虹青 → 品红渐变）。

## kitty ANSI 16 色

| idx | 值 | idx | 值 |
|---|---|---|---|
| 0 | `#0A0C0D` | 8 | `#5A656A` |
| 1 | `#FF5C7A` | 9 | `#FF7D93` |
| 2 | `#4FD8A8` | 10 | `#6FE8BE` |
| 3 | `#D9C27A` | 11 | `#F0D48A` |
| 4 | `#5AA7D6` | 12 | `#7FC4E8` |
| 5 | `#B77BF0` | 13 | `#CFA0FF` |
| 6 | `#02F0FA` | 14 | `#6FF6FC` |
| 7 | `#AAB3B6` | 15 | `#E6ECEE` |

注：终端保留红/绿/黄（k1–k3）以便 diff、git status、错误输出仍然可读；它们不参与桌面 UI 配色。

## 壁纸

- 文件：`10-hyprbuddy.png`
- 规格：2560×1440、8bit sRGB、3 通道（无 alpha）
- 明暗自检：mean=8（深色图）
- 内容：主视觉方形图居中等比放在纯黑画布上，四周 10% 羽化融入背景；
  背后叠一层 10% 不透明度的霓虹青径向辉光，避免整片死黑
- 生成：ImageGen 主视觉 → `magick` 缩放 / 羽化 / 合成

## 派生配色（不手填）

mako 卡片/描边/进度、fuzzel `[colors]`、swayosd 五色、hyprlock 变量、hyprtoolkit 认证框均由
`scripts/theme-next` 按上表的 WB_*/HA* 用 `mixhex` 推导。改配色只改主题表那一行，本文件同步更新。

Plymouth 开屏用的是同一张主视觉（`pkgs/plymouth-theme-hyprbuddy`），配色与本主题一致。
