# lifecycle：更新、回滚、清理

## 更新输入（nixpkgs / unstable）

```bash
sys-update --check          # 临时副本里试更新，30s，有更新时退出码 1
sys-update --apply          # 真更新 flake.lock + 构建（不 switch）
sudo nixos-rebuild switch --flake ~/hyprbuddy-os#leonard
git add flake.lock && git commit -m "chore(flake): update inputs"
```

要点：

- `--apply` 只到「构建通过」。构建失败用 `git checkout flake.lock` 撤销
- 全量更新往往意味着上百个包重编；只想跟 unstable 时单独更：
  `nix flake update nixpkgs-unstable`
- **更新后必须重新部署用户配置**：`./install.sh --host <host> --yes`
  （rebuild 只换 `/run/current-system`，`~/.config`、`~/.local/bin`、skills 由 install.sh 管）

## 回滚

```bash
sys-rollback                                    # 先看有哪些代、当前是第几代
sudo /nix/var/nix/profiles/system-48-link/bin/switch-to-configuration switch
# 等价：sudo nixos-rebuild switch --rollback（只回上一代）
# 只改下次启动：… switch-to-configuration boot
```

什么时候回滚：

- switch 后桌面起不来 / 关键功能坏，且短期内定位不到原因
- 回滚**不回滚 git**：代码仍是新的，下次 rebuild 会再回到新版；
  要真正退回旧行为，需 `git revert` 或切分支

回滚后如果要保留当前换新的改动，记得把状态记下来再逐步排查（`sys-log --since` 配合时间点）。

## 清理（GC）

```bash
sys-gc                     # 分区占用 / 世代数 / dead 路径 / 可回收上限（9s）
sudo nix-collect-garbage --delete-older-than 3d   # 保留最近 3 天
sudo nix-collect-garbage -d                       # 只留当前代（失去回滚点）
sudo nix-collect-garbage                          # 只回收不可达路径，不删世代
```

判读：

- 「可回收上限」是 dead 路径 narSize 之和，**未扣除共享依赖**，实际回收更少
- 删世代 = 删回滚点。`-d` 之前先 `sys-rollback` 确认没有想保留的代
- GRUB/systemd-boot 的启动项会随世代删除自动减少

## 顺序铁律（踩过两次）

1. **先 commit，再 install**：flake 只读 git 跟踪的文件，未提交的改动不进 store，
   表现为「改了没生效」且无报错
2. **install 之后才 reload**：`niri msg action load-config-file`
3. **rebuild 之后检查用户配置**：涉及 `home/`、`scripts/`、`exporters/`、`skills/` 的改动，
   `nixos-rebuild switch` 一概不负责
