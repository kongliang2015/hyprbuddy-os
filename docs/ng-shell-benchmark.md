# 同类桌面栈调研（NG 外壳方案对照）

> **历史 / 设计稿（2026-11-04 标注）**：本文是 2026-10-25 对 NG 外壳栈（swaync / eww / hyprshell / waybar）的社区调研，相关组件均已退役。
> 当前实现为 **niri 26.04 + Noctalia v5**（唯一桌面提供方），现状以
> `docs/ROADMAP.md`、`docs/SKILLS.md`、`skills/nixos-desktop-settings/` 与代码为准。
> 本文保留为历史与决策依据，勿按现状引用。

本文记录 `docs/ng-shell.md` 那套栈（swaync + eww + hyprshell + waybar）在社区里的
实际使用情况、可借鉴的界面功能，以及本项目已采纳 / 计划采纳的部分。

调研时间：2026-10-25。发行版与 dotfiles 项目迭代很快，组件清单以文中链接为准。

## 一、同类项目与发行版

严格说，**没有发行版原样使用「swaync + eww + hyprshell + waybar」**——这个组合更像
dotfiles 拼装。最接近的是下面几类：

| 项目 / 发行版 | 组件构成 | 与本项目差异 | 可信度 |
|---|---|---|---|
| **JaKooLit Hyprland-Dots**（Arch/Fedora/Debian/Ubuntu/openSUSE 的安装脚本都在用） | waybar + **swaync** + rofi + **wallust** + wlogout + ags | 栈几乎一样：少 rofi/ags，多 eww/hyprshell；用 wallust 从壁纸取色 | 高（仓库 README 明确列出配置目录） |
| **ML4W OS**（Hyprland 基础发行版 + dotfiles 双形态） | waybar + 自研 Quick Settings + 图形化设置 App + 通知守护 | 走"发行版化"路线：Welcome 引导、GUI 配置器 | 中（官网描述，未逐一核对组件） |
| **CachyOS Hyprland edition** | **Noctalia**（Quickshell 单进程 shell）：Control Center `Super+X`、通知历史 `Super+A`、启动器 `Super+Space` | 已转向单进程方案，功能密度最高 | 高（CachyOS wiki 明确写 Noctalia v5） |
| **end-4 dots-hyprland（illogical-impulse）** | Quickshell：Overview 实时预览、AI（Gemini/Ollama）、屏幕翻译、Material You 取色 | 功能最全的现代化外壳参考 | 高（README「Notable features」） |
| **Garuda / EndeavourOS 的 Hyprland spin** | waybar + 各自的通知/启动器 | 随版本变化，组件不如上表稳定 | 低（未找到逐项组件清单） |
| **NixOS 阵营：ZaneyOS、nixos-hyprland 模板** | Hyprland + waybar，home-manager 声明式生成 | 与本项目最接近（同为 NixOS 声明式） | 中 |

**趋势**：社区正从"waybar + swaync + 若干小进程"转向 **Quickshell 单进程外壳**
（CachyOS 已切换）。本项目的拼装法优点是组件可替换，代价是进程多、视觉一致性
要靠 `theme-next` 手工对齐。

## 二、可借鉴的界面功能

### 顶栏（waybar）

| 功能 | 来源 | 本项目状态 |
|---|---|---|
| 多布局切换（top / bottom / none） | JaKooLit | 未做：只有顶部一条 |
| GPU 温度 / 显存模块 | ML4W | 未做：只有 CPU / 内存 / 电池 |
| 待更新计数 | Garuda、ML4W | 未做 |
| 天气模块 | 多个 rice | 未做 |

### 控制中心 / Quick Settings（差距最大）

| 功能 | 来源 | 本项目状态 |
|---|---|---|
| 亮度 / 音量**滑条**（可拖动） | Noctalia、ML4W | 部分：swaync 只有音量控件 |
| Wi-Fi / 蓝牙 toggle + 设备列表 | Noctalia | 未做：需点 nm-applet |
| 供电 / 性能模式切换 | CachyOS、ML4W | 未做 |
| 一键切 blur / 动画 / 夜间 / DND | ML4W Quick Settings | 部分：只有夜间、录屏两个 toggle |
| 壁纸 / 主题预览网格 | ML4W、JaKooLit | 部分：fuzzel 列表，无预览图 |

### 通知

| 功能 | 来源 | 本项目状态 |
|---|---|---|
| **通知历史归档**（关闭后仍可翻） | Noctalia `Super+A`、end-4 侧栏 | 未做：swaync 关闭即丢 |
| 按 App 静音规则 | swaync 原生 | 可用但未配置 |
| 通知内直接回复（inline reply） | swaync 原生 | 未开启 |

### 启动器

| 功能 | 来源 | 本项目状态 |
|---|---|---|
| 应用搜索 + 计算 + 网页搜索 | hyprshell 插件 | 部分：只开了 applications / calc / path / actions |
| **Emoji 选择器** | CachyOS `Super+Space` | 未做 |
| 剪贴板历史带图片预览 | end-4 | 未做：fuzzel 纯文本 |

### 弹窗 / 其他

| 功能 | 来源 | 本项目状态 |
|---|---|---|
| 系统监控仪表（环形图） | ML4W、多个 rice | 未做 |
| AI 助手侧栏（本地 ollama） | end-4 | 未做（仓库已有 ollama，用于 coredump 分析，可复用） |
| 屏幕翻译 / Google Lens | end-4 | 未做 |
| 防闪光（唤醒渐亮） | end-4 | 未做 |
| 键盘快捷键速查 | 各家 | 已有 `keybinds-popup` |
| 电源菜单 | wlogout / 各家 | 已有 eww 会话面板 |

## 三、已采纳（P1 玻璃拟态）

2026-10-25 落地，见 commit `c1a846c`：

- **overview / launcher 图层模糊**：`hyprshell_overview`、`hyprshell_launcher` 走
  `layer_rule blur`（`ignore_alpha 0.55`），实测区域内局部标准差 10.2（屏外 41.6）
- **hyprshell 玻璃化**：窗口底 0.72 透明、条目 0.55、悬停 accent 18%、
  1px 边框 + inset 顶边高光 + 外投影
- **swaync 快捷面板**：`buttons-grid` 4 列 8 项（截图/夜间/录屏/壁纸/锁屏/主题/菜单/信息），
  夜间与录屏为 toggle（`update-command` 反映真实状态）
- 控制中心保持 0.94 近不透明：它是 2560×1402 全屏 layer，开模糊等于每帧整屏卷积

## 四、建议后续落地（按性价比）

1. **动态取色（wallust / matugen 思路）** ⭐
   JaKooLit 与 end-4 都用"壁纸提主色 → 全组件跟随"。本项目是固定 8 套主题，
   换壁纸与配色脱节。做法：给 `theme-next` 加 `generate` 模式，用 matugen/wallust
   从当前壁纸产出 9 个 token，复用已有的 10 个 writer，不改架构只换色源。
2. **可拖动滑条的控制中心**
   eww 做 Quick Settings（亮度/音量滑条 + Wi-Fi/蓝牙/性能 toggle + 系统状态），
   swaync 专注通知。正好发挥 eww 的强项。
3. **通知历史归档**
   swaync 的 `scripts` 钩子把通知写 `~/.local/state/notifications.jsonl`，
   eww 做"历史"窗口；比整包换 Noctalia 便宜。
4. **壁纸网格选择器**
   现为 `wallpaper-next` 盲切；改成 eww 缩略图网格（数据源 `~/Pictures/wallpapers/`），
   点击即切、当前壁纸高亮。
5. **Emoji 选择器**
   hyprshell 启动器加插件或单开 `Super+.`（`rofi -show emoji` 或 fuzzel + emoji 列表）。

## 五、不建议照搬

- **整包换 Quickshell**：功能密度高，但要重写全部 theme writer 与键位层，周期以周计
- **全屏 surface 开模糊**：NVIDIA + 2560×1440 代价明显（本项目控制中心特意不开）
- **每个组件配独立 daemon**（wlogout + polkit + 通知 + 剪贴板 + OSD …）：
  常驻进程已达 4 个、约 455 MB，继续膨胀不划算

## 六、参考链接

- JaKooLit Hyprland-Dots — https://github.com/JaKooLit/Hyprland-Dots
- ML4W — https://www.ml4w.com/
- CachyOS Hyprland edition wiki — https://wiki.cachyos.org/configuration/desktop_environments/hyprland/
- end-4 dots-hyprland — https://github.com/end-4/dots-hyprland
- swaync 配置手册（man swaync 5）
