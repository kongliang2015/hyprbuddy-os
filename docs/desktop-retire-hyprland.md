# Hyprland 退役记录（distro/v1-nn，2026-10-28）

本文记录从「Hyprland + niri 双提供方」收敛到「只有 niri」的改动、顺序与回滚方式。

## 最终形态

```
modules/desktop/
  hyprbuddy.nix   共享底座：SDDM / fcitx5 / Qt+dconf / firefox / portal.enable
                  / polkit-agent / 通用 CLI（kitty fuzzel grim slurp …）/ commands.json
  niri.nix        提供方：programs.niri + noctalia-shell + xwayland-satellite + portal 后端
  sessions.nix    defaultSession = cfg.default（niri）
home/niri/config.kdl   键位 / 自启（noctalia、awww）
exporters/niri/theme.sh  主题 → Noctalia 配色方案 + 壁纸
```

`distro.desktop.sessions = [ "niri" ]`、`default = "niri"`。

## 为什么必须先抽共享底座

原 `modules/desktop/hyprland.nix` 除了 Hyprland 本身，还承载了这些与合成器无关的配置：

| 内容 | 删掉后的后果 |
|---|---|
| `i18n.inputMethod` + fcitx5 用户服务 | 中文输入法消失 |
| SDDM（主题 / extraPackages / Qt6 greeter 补链） | 没有登录界面 |
| `qt` / `programs.dconf` / firefox | 应用主题与浏览器丢失 |
| polkit 认证代理 | 图形提权弹窗消失 |
| 通用包集（kitty/fuzzel/grim/thunar/…） | niri 键位里的命令找不到 |
| `commands.json` | agent 命令清单断掉 |

所以第 1 步是把它们搬到 `modules/desktop/hyprbuddy.nix`，第 2 步才删 Hyprland。

## 实施顺序（四个提交）

| 提交 | 内容 |
|---|---|
| `f843b45` | **阶段 A**：新增 `hyprbuddy.nix`，`hyprland.nix` 精简为 Hyprland 专属 |
| `c90651e` | **阶段 B**：删除 `hyprland.nix`、`home/{hypr,waybar,eww,swaync,swayosd,hyprshell,uwsm}`、`exporters/hyprland/`、`lib/waybar.nix`、6 个 hypr 脚本；默认会话切到 niri |
| `87f8c11` | **阶段 C**：`de.sh` / `theme-next` / `desktop-check` / `night-mode` / `install.sh` 去 Hyprland 化 |
| `d8dce8e` | **阶段 D**：清理 `waybarAgentCmd` 选项与 `modules/agent/usage.nix` |

## 关键取舍

1. **polkit 代理换实现**：`hyprpolkitagent` 在 niri 下 SIGABRT（原注释已记载），改用
   `polkit-kde-agent-1`；`distro.polkitAgent` 选项改为 `kde|gnome`，默认 `kde`。
   单元名从 `hyprpolkitagent` 改为 `polkit-agent`，由 `graphical-session.target` 拉起。
2. **PAM**：不再需要 `security.pam.services.hyprlock`；Noctalia 锁屏读
   `NOCTALIA_PAM_SERVICE`，缺省用 `/etc/pam.d/login`（NixOS 自带）。
3. **theme-next 保留**：`theme-picker` 依赖它；编排从「12 个 hyprland exporter」
   改成「`exporters/niri/theme.sh` + `noctalia_theme_apply`」。
4. **dpms / hypr-menu / eww-popup 直接删除**：前者依赖 `hyprctl output power`，
   后两者是 Hyprland 时代的菜单实现；niri 的息屏与菜单由 Noctalia / loginctl 接管。

## 验证

```bash
./scripts/agent-apply leonard              # 构建
sudo nixos-rebuild switch --flake .#leonard

# 登录 niri 后
desktop-check                              # 应全绿
journalctl --user -b | grep -i "Failed to open wayland connection"   # 应为空（输入法）
fcitx5-remote -o && fcitx5-remote -n       # 应输出 pinyin
```

构建产物核对：`hypr*` 二进制 0 个、无 `Hyprland`/`waybar`，
`niri`/`noctalia-shell`/`fcitx5`/`kitty`/`fuzzel` 齐全，
`DefaultSession=niri.desktop`，`polkit-agent.service` 存在。

## 回滚

```bash
# 配置级回滚：把会话加回去（代码已在历史里）
git revert --no-commit d8dce8e 87f8c11 c90651e f843b45   # 不建议：依赖顺序

# 更快：切到旧代 + 旧分支
sudo /nix/var/nix/profiles/system-44-link/bin/switch-to-configuration switch
cd ~/hyprland-nixos && git switch distro/v1-cosmic
```

注：物理删除后不建议逐提交 revert，直接用旧系统代回滚更快。
