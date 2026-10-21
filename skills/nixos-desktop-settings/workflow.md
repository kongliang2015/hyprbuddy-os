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

   行为：`nix build .#<host>` → 软链到 `~/.config`、`~/.local/bin`、`~/.codebuddy/skills`；
   已存在的真实文件备份到 `~/.config.bak-<时间戳>/`；复制 `wallpapers/` 到 `~/Pictures/wallpapers`；末尾自动跑 `hypr-check`
4. **系统级应用（用户执行）**：

       sudo nixos-rebuild switch --flake ~/hyprland-nixos#<host>

## 生效方式

| 改动 | 生效 |
|---|---|
| Hyprland 配置 | `hyprctl reload`（会话内）或重新登录 |
| waybar / mako | `install.sh` 后重新登录；mako 可 `makoctl reload` |
| 主题 | `theme-next`（整份重写 waybar style.css 并重启 waybar / mako） |
| 系统级 | `nixos-rebuild switch`（用户执行） |

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
