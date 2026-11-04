# 路线图（v1-nn：niri + Noctalia v5）

> 更新：2026-10-29。Hyprland / COSMIC 时代的功能清单已归档到
> `docs/desktop-retire-hyprland.md` 与 `docs/niri-noctalia-plan.md`，本文只写当前现实。

## 当前形态

| 层 | 现状 |
|---|---|
| 合成器 | niri 26.04（唯一提供方，滚动平铺） |
| 外壳 | Noctalia v5（`pkgs.noctalia` 5.0.1，原生 C++，无 quickshell） |
| 主题 | `themes/<slug>/tokens.json` 单一真相 → kitty/fuzzel 精确 16 色 + 外壳壁纸取色 |
| 会话 | SDDM → niri；fcitx5 输入法；xwayland-satellite |
| 键位 | `home/niri/config.kdl` 60 条，速查见 `docs/KEYBINDS.md` |
| 自检 | `desktop-check`（图形会话全量、非图形降级） |
| agent 层 | 26 条命令 + 5 个技能，索引见 `docs/SKILLS.md` |

## 已完成

- **桌面抽象 P0–P3**：`distro.desktop.sessions`、能力层 `scripts/lib/de.sh`、
  tokens + exporters、Hyprland/COSMIC 退役（v1-nn）
- **Noctalia v4 → v5**：包装、PAM 锁屏、upower/bluetooth 前置、exporter 重写、
  13+ 处键位与脚本换 `msg`
- **键位补齐（B 套）**：窗口切换器、通知/勿扰、夜间模式、壁纸、btop、
  上下工作区、截图 overlay、`allow-when-locked`
- **agent 层 P0–P3**：sys-* 6 条、svc/net/power-status、技能 `nixos-system-ops`、
  过时技能重写（`theme-create` / `scifi-ui`）

## 待做（按优先级）

### P0 一致性

- [ ] bar 布局的定位写死：目前**不做声明式基线**（state 优先级更高 + schema 不稳），
      需在 `bar-notify.md` 与自检里持续提示「bar 属运行态」
- [x] `docs/ROADMAP.md` 重写（本次）
- [x] 清理 `~/.config/noctalia/` 的 v4 残留（settings.json / colors.json / colorschemes）

### P1 功能缺口

- [x] 夜间模式：`distro.desktop.nightlight`（vmware 用 auto_locate，6500/4000K），
      日志 `[gamma] target 4000K` 确认已下发
- [x] 录屏：`Mod+Alt+R` → `record-toggle`（输出到 XDG 视频目录 + 起停通知）
- [x] 快捷键 B 套（窗口切换器 / 通知 / 勿扰 / 夜间 / 壁纸 / btop / 工作区 / 截图）

### P1 暂缓（2026-11-04 决定搁置）

- [ ] 自定义调色板：5.0.1 的 `source="custom"` 格式试了 6 种写法均被判 invalid，
      外壳暂时只能壁纸取色；等上游文档明确或新版本再攻
- [ ] 多 host 验证：`leonard`（NVIDIA）、`vm-virtio`（aarch64）尚未实机跑 v5；
      需要那两台机器，暂不排期

### P2 质量

- [ ] 重建 live/install ISO（niri 提供方换 v5 后未验证）
- [ ] 剪贴板双轨收敛：`Mod+V`（cliphist+fuzzel）vs v5 `panel-toggle clipboard`
- [ ] 截图落盘策略确认（v5 overlay 保存路径）
- [x] `desktop-check` 增补：键位引用的命令存在性（负向已测）、壁纸目录可用性、
      夜间模式日程是否解析、Noctalia 配置 unknown setting 告警

### P3 长期

- [ ] `sys-doctor`：聚合 sys-health + net/power-status + desktop-check
- [ ] omarchy 差距表的中难度项（多终端/编辑器切换、开发栈、游戏套件）

## 明确不做

- 包管理命令（声明式即可）、需要 sudo 的写操作（只打印命令交给人）
- Hyprland/COSMIC 相关特性（已退役，勿回写）
