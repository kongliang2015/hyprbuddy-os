---
name: cosmic-ux
description: COSMIC 桌面的 UX 定制入口（面板/Dock/applet 布局、布局模板、快捷键、配色切换）。一切改动经 uxctl 受控执行：dump → diff → apply --yes → 校验，自带快照与回滚；禁止直接编辑 ~/.config/cosmic。
---

# cosmic-ux

在 SKY/COSMIC 会话里定制桌面 UX。仓库 `~/hyprland-nixos`，工具 `uxctl`（已部署到 PATH）。

## 铁律

1. **禁止直接编辑 `~/.config/cosmic/**`**——一切变更必须经 `uxctl`
   （例外：`docs/` 里明确说明的排查读取；写操作一律不行）
2. **先 `diff` 再 `apply`**：没有用户确认不得加 `--yes`
3. **单次变更 ≤ 12 个键**（`uxctl` 会拒绝超限；布局模板 apply 例外）
4. **每次改动必须在回复里给出快照 id**，并附回滚命令
5. **配色不归本技能**：切主题走 `theme-next` / `de-theme-apply`，不要动 `cosmic-themes/*.ron`

## 决策树

| 请求 | 入口 |
|---|---|
| 改面板/Dock 的形态（位置、自动隐藏、圆角、透明度、尺寸） | `uxctl diff` → `uxctl apply --yes` |
| 改 applet 布局（左右翼、中区） | 同上，键为 `plugins_center` / `plugins_wings` |
| 套用整套布局模板 | `uxctl layout list` → `uxctl layout apply <id> --yes` |
| 把当前布局存成模板 | `uxctl layout save <name>` |
| 切换主题/配色 | **不要用本技能**，用 `theme-next <idx>` 或 `de-theme-apply <slug>` |
| 快捷键 | 暂未接入（U2 待做），先如实告知用户 |
| 单键微调后想撤销 | `uxctl snapshot list` → `uxctl snapshot restore <id>` |

## 命令速查

```bash
uxctl dump [--ns panel|dock|comp|all] [--json]   # 只读：现状
uxctl diff profile.json [--json]                 # 只读：变更表 + 校验
uxctl apply profile.json [--yes] [--reason "..."] # 写入（默认 dry-run）
uxctl snapshot list|restore <id>                 # 快照
uxctl layout                                     # 系统/用户模板列表
uxctl layout apply <id> [--yes]                  # 整树应用模板
uxctl layout save <name>                         # 当前布局存为模板
```

退出码：`0` 可应用/成功，`1` 校验错误或写入失败，`2` 参数或文件问题。

## 标准工作流

```bash
# 1. 读现状（只读）
uxctl dump --ns panel --json

# 2. 写 partial profile：只写要改的键（写到 /tmp 或 ~/.cache）
cat > /tmp/ux-$(date +%s).json <<EOF
{"version":1,"panel":{"autohide":{"wait_time":500,"transition_time":200,"handle_size":2}},"panel_radius":0}
EOF
# 注意：正确写法是嵌套在 panel 里，上面只是示意

# 3. 出差异，贴给用户看
uxctl diff /tmp/ux-XXX.json

# 4. 用户确认后才写入
uxctl apply /tmp/ux-XXX.json --yes --reason "自动隐藏顶栏"

# 5. 复核
uxctl dump --ns panel | grep -E "autohide|border_radius"
```

**diff 输出示例**（回复用户时保持这个形态）：

```
将变更：
  panel.autohide       None  →  Some(( wait_time: 500, ...
  panel.border_radius  0     →  12
合计：2 处变更，0 处一致，0 处错误
```

## 场景配方

### 1) 顶栏自动隐藏 + 圆角 + 半透明

```json
{"version":1,"panel":{"autohide":{"wait_time":500,"transition_time":200,"handle_size":2},"border_radius":12,"opacity":0.92}}
```

### 2) 胶囊 Dock（视觉重点）

```json
{"version":1,"dock":{"border_radius":160,"expand_to_edges":false,"margin":4,"padding":4,"size":"L"}}
```

### 3) 顶栏精简（只留时钟 + 右侧托盘）

```json
{"version":1,"panel":{"size":"XS","plugins_center":["com.system76.CosmicAppletTime"],"plugins_wings":{"left":["com.system76.CosmicPanelWorkspacesButton"],"right":["com.system76.CosmicAppletAudio","com.system76.CosmicAppletNetwork","com.system76.CosmicAppletBattery","com.system76.CosmicAppletNotifications","com.system76.CosmicAppletPower"]}}}
```

### 4) 套用官方布局

```bash
uxctl layout                 # 只有 top-panel-and-bottom-dock / bottom-panel 两个系统模板
uxctl layout apply bottom-panel --yes
```

应用后要提醒用户：模板会**覆盖该面板全部 21 个键**，不是打补丁。

## 可用 applet（写布局前先确认）

```
com.system76.CosmicApplet{A11y,Audio,Battery,Bluetooth,InputSources,Minimize,
  Network,Notifications,Power,StatusArea,Tiling,Time,Workspaces}
com.system76.CosmicPanel{Workspaces,App,Launcher}Button
com.system76.CosmicAppList
```

拼错会被 `uxctl diff` 直接拒绝（白名单校验），不要绕过。

## 校验与回滚

- `apply` 内部已做**写后读回校验**，不一致会自动 restore 并返回 1
- 额外复核：`uxctl dump --ns panel`，或让用户看面板实际变化
- 面板改坏导致无 UI：从 TTY/SSH 执行
  ```bash
  uxctl snapshot list
  uxctl snapshot restore <最近一个 id>
  ```

## 已知限制（如实告知，不要编造）

| 限制 | 说明 |
|---|---|
| 快捷键未接入 | `uxctl` 还没有 `shortcuts` 子命令，需手工写 `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom`（本技能不做） |
| 模板是全量覆盖 | `layout apply` 重置面板所有键 |
| `layout save` 无缩略图 | 不生成 `icon.png`，COSMIC 设置页显示占位图 |
| 无 `cosmic-config` CLI | 只能写文件，所以必须经 `uxctl` |
| 主题无关 | 配色由 `exporters/cosmic/theme.sh` 生成，本技能不碰 |

## 边界：不要做的事

- ❌ 手写 RON 到 `~/.config/cosmic/**`（`Some(([...],[...]))` 容易写错）
- ❌ 改 `themes/*.ron` 或 `~/.local/share/cosmic-themes/*`（配色归 theme-next）
- ❌ 开发 applet / 自定义 Settings 页（需 Rust + 重编，超出范围）
- ❌ 一次 apply 超过 12 键（会被拒绝，拆成多次并分别确认）
- ❌ 未确认就 `--yes`（除非用户明确说“直接改”）
