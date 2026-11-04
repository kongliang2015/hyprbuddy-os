# workflow：修改、构建、部署、回滚

## 四步流程

入口自查：`agent-commands list` 列出全部命令；`agent-commands show <name>` 查看参数、副作用、是否需 sudo / 是否交互。不确定时先查再动手。

1. **改仓库**：
   - 用户级 dotfiles → `home/`
   - host 差异 → `hosts/<host>/default.nix`（只写 `distro.*`）
   - 系统模块 → `modules/`；脚本 → `scripts/`；公共库 → `lib/`
2. **求值 + 构建**（无 sudo）：

       scripts/agent-apply <host>

   内部顺序：`git diff --stat` → `nix eval ...toplevel.drvPath` → `nixos-rebuild build` → 打印 sudo 命令
3. **用户级部署**：

       ./install.sh --host <host> --yes

   行为：`nix build .#<host>` → 软链到 `~/.config`、`~/.local/bin`、`~/.codebuddy/skills`、
   `~/.local/share/hyprbuddy-os/commands.json`（`~/.claude` 存在时同步 `~/.claude/skills`）；
   已存在的真实文件备份到 `~/.config.bak-<时间戳>/`；复制 `wallpapers/` 到 `~/Pictures/wallpapers`；末尾自动跑 `desktop-check`
4. **系统级应用（用户执行）**：

       sudo nixos-rebuild switch --flake ~/hyprbuddy-os#<host>

## ⚠️ rebuild ≠ 部署（最容易踩的坑）

`nixos-rebuild switch` 只换 `/run/current-system`（包、服务、systemd 单元）。
**用户级配置完全不归它管**，必须单独跑 `install.sh`：

| 层级 | 由谁部署 | rebuild 覆盖 |
|---|---|---|
| `/run/current-system`（包/服务） | `nixos-rebuild switch` | ✅ |
| `~/.config/niri/config.kdl` | `install.sh` | ❌ |
| `~/.local/bin/*`（脚本） | `install.sh` | ❌ |
| `~/.local/share/hyprbuddy-os/exporters/*` | `install.sh` | ❌ |
| `~/.codebuddy/skills/*` | `install.sh` | ❌ |

**真实事故（2026-10-29）**：`git pull` 拿到 Noctalia v5 迁移后只跑了 `nixos-rebuild switch`，
没有 `install.sh`，于是 `~/.config/niri/config.kdl` 还是 v4 版本：

```
spawn-at-startup "sh" "-c" "sleep 2; exec noctalia-shell …"   # v4 包名
/run/current-system/sw/bin/noctalia-shell                     # 已被删除
→ sh: exec: noctalia-shell: 未找到 → 进程立即退出 → 桌面没有面板
```

判据：`journalctl --user -b | grep niri` 里能看到其他 spawn 的 `app-niri-*` scope，
**唯独缺 noctalia 的 scope**。

**规则：`git pull` 或任何改动涉及 `home/`、`scripts/`、`exporters/`、`skills/` 后，
必须补跑 `./install.sh --host <host> --yes`，然后 `niri msg action load-config-file`。**

## ⚠️ 顺序：先 commit，再 install

flake 只认 **git 跟踪的文件**。`install.sh` / `agent-apply` 构建的是 `HEAD`，
工作区里未提交的改动**不会进 store**——表现为「改了没生效」，且没有任何报错。

```bash
git add -A && git commit -m ...     # 先
./install.sh --host <host> --yes    # 后
```

## 生效方式

| 改动 | 生效 |
|---|---|
| niri 配置 | `niri msg action load-config-file`（会话内，也可等自动重载） |
| 脚本 / exporters / skills | `install.sh` 后立即（新进程读取），无需重登 |
| 主题 | `theme-next` / `de-theme-apply <slug>`（写 `theme.toml` 壁纸取色 + kitty + fuzzel） |
| 包 / 服务 / 驱动 | `nixos-rebuild switch`（用户执行）+ 重新登录 |
| Noctalia 面板组件 | `Mod+Shift+S` GUI 调整（落 `~/.local/state/noctalia/settings.toml`，换机回默认） |

## 判读 agent-apply 输出

| 失败点 | 含义 |
|---|---|
| `nix eval` 失败 | 配置求值错误：选项不存在 / 类型不符 / 写了未定义的 `distro.*` |
| `nixos-rebuild build` 失败 | 包构建错误：网络、平台（如 x86_64-only 包）、依赖缺失 |
| 两步都过 | 可以交给用户 switch |

## 回滚

| 层级 | 方式 |
|---|---|
| 系统代际 | 用户执行 `sudo nixos-rebuild --rollback` |
| 仓库 | `git revert <sha>` 后重走流程 |
| 用户文件 | `~/.config.bak-*` 里是 install.sh 备份的真实文件 |

## 注意

- 仓库 `home/` 文本用 `@HOME@` 占位，构建时替换为家目录；不要写死 `/home/<user>`
- `scripts/` 下 agent 专用脚本（agent-menu / agent-apply / agent-theme-sync）仅当 `distro.agent.enable = true` 时部署
