# 踩坑与修复记录

记录搭建过程中实际遇到的问题，便于以后复现/排障。

## 1. LightDM 启动 Hyprland 后键鼠全死

**现象**：SDDM/LightDM 登录进入 Hyprland，桌面显示正常，但鼠标不动、键盘无响应；而 `Ctrl+Alt+F2` 切 TTY 后直接运行 `Hyprland` 一切正常。

**原因**：LightDM 启动 Wayland 会话时 seat/输入设备交接有问题，Hyprland 没拿到输入设备。

**修复**：改用 **SDDM**（`services.displayManager.sddm.enable = true`）。SDDM 正确交接 seat。

**验证**：日志 `journalctl -b | grep -iE 'hyprland|seat|libinput'`；`loginctl seat-status seat0` 查看键鼠是否挂在 seat0。

## 2. `programs.hyprland.nvidiaPatches` 报错

**现象**：`nixos-rebuild switch` 断言失败：`nvidiaPatches ... no longer has any effect; please remove it.`

**原因**：NixOS 25.11 起 NVIDIA 支持已并入 wlroots/Hyprland 本体，该选项废弃。

**修复**：删除 `nvidiaPatches = true;`。保留 `boot.kernelParams = [ "nvidia-drm.modeset=1" ]`。

## 3. Hyprland 配置报错（28~32 行）+ 键位失效

**现象**：顶部错误浮层提示某几行有错，之后的键位都不生效。

**原因**：Hyprland `bind` 语法中修饰键用**空格**分隔，逗号只出现在按键之前。写成 `bind = $mainMod, SHIFT, 1, ...` 会把 `SHIFT` 当成按键名。

**修复**：改为 `bind = $mainMod SHIFT, 1, ...`（`$mainMod` 与 `SHIFT` 之间是空格）。

## 4. 鼠标冻结 / 整个会话冻结

**现象**：NVIDIA 上 Hyprland 鼠标指针不动；尝试加 `env = WLR_NO_HARDWARE_CURSORS,1` 后反而键盘也一起冻结。

**原因**：该变量在本机驱动版本下让合成器渲染线程挂起，连带输入全部冻结。

**修复**：移除 `WLR_NO_HARDWARE_CURSORS`。确认 `nvidia-drm.modeset=1` 已生效（`cat /proc/cmdline | grep nvidia-drm`），换 SDDM 后光标正常。

## 5. `kitty` 找不到（Super+Return 无反应）

**原因**：回退 home-manager 配置时 `kitty` 被移出用户环境。

**修复**：把 `kitty` 加进系统 `environment.systemPackages`。

## 6. Home Manager 里 Hyprland 选项名写错

**原因**：`programs.hyprland` 是 **NixOS 系统**选项；Home Manager 里应为 `wayland.windowManager.hyprland`。

**修复**：home-manager 模块中改用 `wayland.windowManager.hyprland`（本项目最终选择系统层安装，不再用 HM 管 Hyprland）。

## 7. Obsidian 安装卡住

**原因**：`obsidian` 的源码包直接从上游服务器拉取，在本机网络下会一直挂起（非二进制缓存问题）。

**修复**：从包列表移除，需要时另行安装。

## 8. `home-manager switch` 报 palette 路径不存在

**原因**：模块在 `omarchy/` 子目录，却用 `import ../palette.nix`，实际应为 `./palette.nix`。

**修复**：改为同目录相对路径。

## 常用排障命令

```bash
# Hyprland 会话日志（从 TTY 直接启动可看到完整输出）
Hyprland > /tmp/hypr.log 2>&1

# 当前会话错误
journalctl -b | grep -iE 'hyprland|seat|libinput|nvidia' | tail -50

# 输入设备是否在 seat 上
loginctl seat-status seat0

# 查看 DRM 设备 / 显卡
ls /dev/dri/ && lspci | grep -iE 'vga|3d'

# 内核参数是否生效
cat /proc/cmdline

# 回滚系统
sudo nixos-rebuild switch --rollback
```
