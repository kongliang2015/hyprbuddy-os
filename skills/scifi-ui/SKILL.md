---
name: scifi-ui
description: 科幻风（sci-fi / HUD / 霓虹）UI 组件规范：令牌、组件配方、动效与无障碍约束。用于改造 waybar、swaync、eww、hyprshell、swayosd、hyprlock、fuzzel、SDDM 与 COSMIC 的视觉风格；参考 bergside/awesome-design-md-skills 的 cosmic 设计系统，落地到本仓库的 theme token 体系。
---

# scifi-ui

把桌面组件做成"科幻 HUD"风格：深空底、霓虹描边、切角、等宽字、克制的发光。
参考：`bergside/awesome-design-md-skills` 的 cosmic 技能（科幻定位、令牌优先、WCAG 2.2 AA、QA 清单）。
本技能把它**改写成本仓库可落地的版本**——所有颜色来自 `themes/<slug>/tokens.json`，不引入平行色板。

## 一、上下文与目标

**适用**：改 `exporters/hyprland/*` 生成的 CSS/SCSS、`pkgs/sddm-theme-hyprbuddy` 的 QML、
`themes/*/tokens.json` 的配色，或新增一套 sci-fi 主题。

**不适用**：COSMIC 的运行时 UI 细节（它没有 CSS，只能改 palette + `is_frosted`，见第六节）。

**设计意图一句话**：深色背景 + 单一霓虹主色 + 轻量网格/切角 + 等宽字体，营造"仪表盘"感，
但**正文可读性优先于发光效果**。

## 二、设计令牌

### 2.1 颜色：只允许从 theme token 派生

| 令牌 | 来源（`tokens.json`） | sci-fi 用法 |
|---|---|---|
| `--sci-bg` | `bg` | 面板/卡片底（可叠 3–6% 主色做冷调） |
| `--sci-surface` | `surface` | 次级面板、输入框 |
| `--sci-fg` | `fg` | 正文 |
| `--sci-muted` | `muted` | 标签、单位、辅助文字 |
| `--sci-accent` | `accent` | 描边、焦点、进度、主按钮 |
| `--sci-accent2` | `accent2` | 渐变第二色、次要高亮 |
| `--sci-urgent` | `urgent` | 告警、危险操作 |
| `--sci-glow` | `accent` + alpha | 发光只用于**描边与图标**，不用于文字块 |

**必须**：不得在 CSS 里写死十六进制色值；新增主题只改 `tokens.json`。

### 2.2 形状与线宽

```
切角        8px（卡片四角用 clip-path 或 border-image 实现）
圆角        2px（对切角组件）  /  6px（对普通卡片）
描边        1px 常态 · 2px 聚焦 · 1px 发光线（外层再叠 1px、alpha 20%）
网格        24px 间距、alpha 3%（仅面板背景，禁止满屏）
扫描线      2px 周期、alpha 2–3%，只允许出现在锁屏/登录这类静态画面
```

### 2.3 间距与字号

```
间距  4 / 8 / 12 / 16 / 24 / 32
字号  11（单位）/ 12（标签）/ 13（正文）/ 14（卡片标题）/ 20（面板标题）/ 32（锁屏时钟）
字体  正文 JetBrainsMono Nerd Font（等宽，已有）；标题可加 0.08em 字距 + 大写
字重  400 正文 / 700 标题 / 500 数值
```

### 2.4 动效

```
时长  120ms（hover）/ 180ms（出现）/ 240ms（布局变化）
曲线  cubic-bezier(0.23, 1, 0.32, 1)   # 与 Hyprland 一致
禁止  持续闪烁、无限旋转、扫描线动画（耗电且干扰阅读）
```

## 三、组件规则

### 3.1 HUD 卡片（swaync 通知 / eww 弹窗 / hyprshell 项）

**结构**：底 → 1px 描边 → 左上角 2px 强调短线（"角标"）→ 内容。

```css
.notification, .card {
  background: alpha(@bg, 0.86);
  border: 1px solid alpha(@accent, 0.38);
  border-radius: 6px;
  box-shadow: inset 0 1px 0 alpha(@accent, 0.18), 0 0 12px alpha(@accent, 0.10);
}
/* 角标：左上 12px 短线 */
.card::before { content: ""; }  /* GTK 无伪元素 → 用单独 Rectangle 实现 */
```

- GTK CSS **没有** `::before`，角标要用一个 12×2px 的 `Rectangle`/`box` 元素实现
- 发光 `box-shadow` 半径 ≤ 12px、alpha ≤ 0.12；超过即为过度设计
- 状态：默认 / hover（描边 alpha 0.38→0.60）/ 聚焦（2px 描边 + 外发光）/ 禁用（alpha 0.4）

### 3.2 状态栏模块（waybar）

```css
#clock, #cpu, #memory, #battery, #pulseaudio {
  padding: 0 10px;
  margin: 0 2px;
  border-left: 1px solid alpha(@accent, 0.22);   /* 竖分隔线 = 仪表盘刻度感 */
  font-feature-settings: "tnum";                /* 数字等宽，跳动不抖 */
}
#workspaces button.active {
  border-bottom: 2px solid @accent;             /* 下划线而非整块填充 */
  color: @accent;
}
```

**必须**：数值类模块启用 `tnum`（表格数字），否则时间/CPU 变化时宽度抖动。

### 3.3 OSD（swayosd）

```css
window { background: alpha(@bg, 0.92); border: 1px solid alpha(@accent, 0.5); border-radius: 6px; }
progressbar trough { background: alpha(@surface, 0.9); border-radius: 2px; }
progressbar progress { background: linear-gradient(90deg, @accent, @accent2); border-radius: 2px; }
```

### 3.4 锁屏（hyprlock）

- 时钟 32–64px、`font-weight: 300`、字距 `0.12em`（HUD 感的来源是**字距**不是字体）
- 允许在背景层加 2–3% alpha 的扫描线（静态，无动画）
- 输入框：下划线式（`border-bottom: 1px`），聚焦时改为 2px 主色

### 3.5 启动器与菜单（fuzzel / hypr-menu）

- 选中项：左侧 2px 主色竖条 + 背景 `alpha(@accent, 0.14)`，**不要**整行填充高饱和色
- 输入框提示符用 `>` 或 `:`，配等宽字体，保持终端感

### 3.6 SDDM 登录（QML）

- 登录卡片：切角 8px（QML 用 `Rectangle` + 两个小三角拼，或用带 alpha 的边框图）
- 主按钮：主色描边 + 8% alpha 填充；hover 时描边升到 60%
- 会话选择器向上弹出（已实现），保持 260×36，不要为了"科幻感"缩窄

## 四、无障碍（可测试）

| 规则 | 阈值 | 验证方式 |
|---|---|---|
| 正文对比度 | ≥ 4.5:1 | 下方脚本 |
| 大字/标题（≥20px bold） | ≥ 3:1 | 同上 |
| 描边可见性 | 与背景 ≥ 1.5:1 | 目测 + 脚本 |
| 焦点指示 | 2px、与相邻色差明显 | 手动 Tab 一遍 |
| 发光不得降低文字对比 | 文字下方禁止叠加 glow 层 | 截图取色 |

```bash
# 对比度检查（无外部依赖）
python3 - <<PY
def lum(h):
    h=h.lstrip("#"); c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    c=[x/12.92 if x<=0.03928 else ((x+0.055)/1.055)**2.4 for x in c]
    return 0.2126*c[0]+0.7152*c[1]+0.0722*c[2]
def ratio(a,b):
    la,lb=sorted([lum(a),lum(b)],reverse=True); return (la+0.05)/(lb+0.05)
print("fg/bg", round(ratio("DCD7BA","16161D"),2))
print("accent/bg", round(ratio("7E9CD8","16161D"),2))
PY
```

**冲突处理**：若霓虹色对比不足，**提亮文字**或**降低发光**，不得为了效果牺牲可读性。

## 五、内容与语气

- 标签全大写 + 短词：`CPU`、`MEM`、`BAT`、`NET`；中文用两字：`电量`、`内存`
- 数值保留单位并用小号字：`72%`、`3.2G`、`48°C`
- 告警用词直接：`过热`、`离线`，不用"哎呀"这类语气词

## 六、COSMIC 的限制

COSMIC 没有 CSS，只能：
- `is_frosted: true` 获得毛玻璃（对应我们的玻璃拟态）
- `neutral_0..10` 做明暗阶梯、`accent_*` 上主色
- `radius_*` / `gaps` 调形状

→ 想套 sci-fi 风格，COSMIC 侧只改 palette；**不要**试图在 COSMIC 上实现切角/扫描线。

## 七、反模式

| 反模式 | 为什么不行 | 改成 |
|---|---|---|
| 满屏扫描线/网格 | 视觉噪声、耗电、影响阅读 | 只在锁屏/登录静态画面用，alpha ≤3% |
| 三层叠加发光 | 文字边缘发虚，低分屏不可读 | 单层 `box-shadow`，半径 ≤12px |
| 彩虹渐变（3 色以上） | 破坏单一主色的仪表盘感 | 最多 accent → accent2 两色 |
| 纯 `#00FFFF` on `#000000` | 对比 21:1 但刺眼、易疲劳 | 降到 75–85% 亮度 |
| 动画 > 300ms | 操作迟滞感 | 120/180/240ms 三档 |
| 每组件独立配色 | 不一致 | 全部从 tokens 派生 |

## 八、QA 清单（代码审查逐条过）

- [ ] CSS/SCSS 里没有硬编码十六进制色值（全部走 token/`@define-color`）
- [ ] 正文对比度 ≥ 4.5:1（脚本验证）
- [ ] 发光 `box-shadow` 半径 ≤ 12px、alpha ≤ 0.12
- [ ] 数值模块启用 `font-feature-settings: "tnum"`
- [ ] 焦点态有 2px 可见描边，键盘可走完全流程
- [ ] 动效时长在 120/180/240ms 三档内，无无限动画
- [ ] 8 套主题切换后无对比度崩坏（逐套跑脚本）
- [ ] `theme-next <idx>` 后截图对比，无布局跳动

## 九、落地路径

| 想改什么 | 改哪里 | 验证 |
|---|---|---|
| 某组件样式 | `exporters/hyprland/<name>.sh` 里的 CSS 模板 | `theme-next <idx>` → 看效果 |
| 新增 sci-fi 主题 | `themes/<slug>/tokens.json` + `order` | `theme-next` 切到它 → 跑对比度脚本 |
| COSMIC 配色 | `exporters/cosmic/theme.sh`（读同一份 tokens） | `uxctl` 无关；`theme-next` 自动写 RON |
| 登录界面 | `pkgs/sddm-theme-hyprbuddy/Main.qml` | `sddm-greeter --test-mode --theme <path>` |

**改动纪律**：先 `agent-apply <host>` 构建，再 `./install.sh --host <host> --yes` 部署，
最后 `desktop-check` 自检；系统级改动把 `sudo nixos-rebuild switch` 交给用户。
