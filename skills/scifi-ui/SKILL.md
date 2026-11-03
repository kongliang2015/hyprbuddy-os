---
name: scifi-ui
description: 科幻风（HUD / 霓虹）视觉规范：色令牌、形状与线宽、动效、无障碍约束。用于改造 SDDM 登录界面、kitty、fuzzel 与 Noctalia 配色；所有颜色必须来自 themes/<slug>/tokens.json。
---

# scifi-ui

把界面做成「科幻 HUD」：深空底、单一霓虹主色、切角、等宽字、克制的发光。
原则：**正文可读性优先于发光效果**。

## 一、适用面（v1-nn 现状）

| 界面 | 能否自定义 | 落点 |
|---|---|---|
| SDDM 登录界面 | ✅ QML 完全可控 | `pkgs/sddm-theme-hyprbuddy/Main.qml` |
| kitty 终端 | ✅ 16 色 + 前景背景 | `themes/<slug>/tokens.json` → `terminal` |
| fuzzel 启动器 | ✅ 背景/文字/选中/描边 | tokens 的 `bg/fg/accent/surface/accent2` |
| Noctalia（bar/面板/通知） | 🟡 只能给 palette 或让壁纸取色 | `~/.config/noctalia/theme.toml`、custom palette |

**已退役，不要再引用**：waybar、swaync、mako、eww、hyprshell、swayosd、hyprlock、COSMIC。
它们的 CSS/SCSS 配方已随组件删除，写出来就是死代码。

## 二、色令牌：只从 tokens 派生

| 令牌 | `tokens.json` | 用法 |
|---|---|---|
| bg | `bg` | 面板底、卡片底 |
| surface | `surface` | 次级面板、输入框、选中条 |
| fg | `fg` | 正文 |
| muted | `muted` | 标签、单位、辅助文字 |
| accent | `accent` | 描边、焦点、进度、主按钮 |
| accent2 | `accent2` | 渐变第二色、次要高亮 |
| urgent | `urgent` | 告警、危险操作 |
| glow | `accent` + alpha 20–35% | **只用于描边与图标**，不用于文字块 |

硬规则：**任何文件里不写死十六进制**。要新颜色，加进 tokens。

## 三、形状与线宽

| 元素 | 规格 |
|---|---|
| 大面板圆角 | 0（切角）或 2px，不用大圆角 |
| 切角 | 左上/右下 45°，边长 = 面板高度的 8–12% |
| 常规描边 | 1px `accent` @ 60% |
| 焦点描边 | 1px `accent` @ 100% + 外发光 2px |
| 分割线 | 1px `muted` @ 30% |
| 间距 | 8 的倍数（8/12/16/24） |

## 四、字体与排版

- 标题/数值：等宽（`JetBrainsMono Nerd Font`），用于数字对齐
- 正文：系统 sans（中文回退 `WenQuanYi Zen Hei`）
- 全大写标签加 `letter-spacing: 0.08em`，仅用于 ≤4 个字符的短标签

## 五、动效

| 场景 | 时长 | 曲线 |
|---|---|---|
| 面板出现/消失 | 120–160ms | ease-out |
| 焦点/悬停 | 80ms | linear |
| 呼吸/扫描线（装饰） | ≥2s | 必须可关闭 |

禁止：持续闪烁、超过 3 次/秒的动画、遮挡正文的扫描线叠加。

## 六、无障碍（WCAG 2.2 AA 底线）

- 正文对比度 ≥ 4.5:1（`fg` on `bg`）；大字号 ≥ 3:1
- 焦点态不能只靠颜色区分，需加 2px 描边或形状变化
- 发光层 `pointer-events: none`，不得拦截点击
- 有动效的组件需尊重「减少动态」偏好（SDDM 可用静态替代）

## 七、按组件的落地

### 7.1 SDDM（`pkgs/sddm-theme-hyprbuddy/Main.qml`）

- 背景：登录壁纸 + 暗化遮罩（`opacity 0.35–0.5`）
- 输入框：`surface` 底 + 1px `accent` 描边，聚焦时发光
- 按钮：主按钮 `accent` 底 + `bg` 字；次按钮透明底 + `accent` 描边
- 时钟/日期：等宽，`accent`，字号 ≥ 28pt
- 改完必须重新 `agent-apply` + `nixos-rebuild switch`（SDDM 是系统服务）

### 7.2 kitty

由 `exporters/niri/theme.sh` 从 `tokens.terminal` 生成 `theme.inc.conf`——
**不要手改该文件**，改 tokens 后重跑 `de-theme-apply <slug>`。

### 7.3 fuzzel

同样由 exporter 整份生成 `fuzzel.ini`：`background=bg`、`text=fg`、`match=accent`、
`selection=surface`、`border=accent`。要调形状改 `[border]` 段（width/radius）需改 exporter 模板。

### 7.4 Noctalia（受限于 v5）

v5 面板配色默认来自壁纸取色（`theme.toml` 的 `source = "wallpaper"`），
tokens 的 accent 不会自动进去。两条路：

- 换一张主色接近 `accent` 的壁纸（最省事）
- 用 custom palette（`~/.config/noctalia/palettes/<name>.json`），格式需实测确认

## 八、验收清单

```
- [ ] 所有颜色能追溯到 tokens.json（无硬编码 hex）
- [ ] fg/bg 对比度 ≥ 4.5:1
- [ ] 焦点态可辨（不只靠颜色）
- [ ] kitty/fuzzel 配色随 de-theme-apply 变化
- [ ] SDDM 改动后重新 switch 并实际注销验证
- [ ] 发光层不拦截点击
```
