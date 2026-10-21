---
name: nixos-desktop-settings
description: hyprland-nixos 桌面配置修改的标准工作流：改仓库 → 求值构建 → 自检 → 交用户应用。适用于部署了本发行版的机器（CodeBuddy / Claude 等 agent）。
---

# nixos-desktop-settings

管理 hyprland-nixos 发行版（NixOS + Hyprland）的桌面配置。

仓库位置：`~/hyprland-nixos`（环境变量 `HYPRLAND_NIXOS_REPO` 可覆盖）。
host 名默认取 `$(hostname)`，须存在 `hosts/<host>/default.nix`。

## 修改流程（唯一入口）

1. **改仓库源文件**，不要直接改 ~/.config 下的 store 软链：
   - 用户级 dotfiles：`home/`（hypr/waybar/fuzzel/kitty/mako/swayosd/Thunar）
   - 主机差异：`hosts/<host>/default.nix`（只写 distro.* 选项，见 modules/options.nix）
   - 系统模块：`modules/`；公共脚本：`scripts/`；公共库：`lib/`
2. **求值 + 构建**（不执行 sudo）：

       scripts/agent-apply <host>

3. **用户级部署**（软链 ~/.config、~/.local/bin、~/.codebuddy/skills，末尾自动跑 hypr-check）：

       ./install.sh --host <host> --yes

4. **系统级应用**：构建通过后，把命令交给用户执行（agent 不执行 sudo）：

       sudo nixos-rebuild switch --flake ~/hyprland-nixos#<host>

## 关键约束

- agent 永不执行 sudo；系统级改动一律先 agent-apply 构建验证
- `/etc/nixos/configuration.nix` 是防误用桩，绝不修改
- channel 时代配置已归档于 `docs/configuration-25.11-archive.nix`，仅作参考，不要引用
- 运行时被改写的文件（如 theme-next 重写的 ~/.config/waybar/style.css）以 `home/` 源为准
- 主题配色统一走 `~/.local/bin/theme-next`；新增 waybar/mako 配色键时须同步 `scripts/theme-next`
- 会话内即时生效：`hyprctl reload`、`makoctl reload`

## 参考

- 分层架构（六层）：`docs/AGENT-LAYER.md`
- 故障排查：`docs/TROUBLESHOOTING.md`
- 路线图：`docs/ROADMAP.md`
