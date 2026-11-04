# agent：开关、用量、诊断、本地模型

## 开关（`distro.agent.*`，见 `modules/options.nix`）

| 选项 | 默认 | 作用 |
|---|---|---|
| `enable` | false | 安装 agent 包与专用脚本（agent-menu / agent-apply / agent-theme-sync） |
| `agents` | `[ "claude-code" ]` | 安装哪些 agent；**claude-code 构建期需访问 downloads.claude.ai**，网络不通时用 `[ "opencode" "codebuddy" ]` |
| `usage` | true | 部署 `~/.local/bin/agent-usage`，供 Noctalia bar 的 CustomButton 显示 |
| `diagnostics` | true | coredump 诊断单元；`modules/agent/diagnostics.nix` 内的断言要求 `localModels = true`（否则求值失败），且需已 `ollama pull` |
| `localModels` | false | 启用本地模型（ollama） |
| `model` | `qwen2.5-coder:1.5b` | 诊断/摘要使用的模型 |

## agent-usage

唯一实现：`lib/agent-usage.nix`（系统级与用户级共用同一份脚本）。

- 口径：**当日 output tokens**（/cost 口径，不受缓存影响）；tooltip 给各源 out/in/cache
- 数据源：
  - codebuddy `~/.codebuddy/projects/**/*.jsonl`（`message.usage`，与 Claude 同构）
  - claude `~/.claude/projects/**/*.jsonl`
  - opencode `~/.local/share/opencode/opencode-stable.db`
- 只统计 **mtime 为今天** 的文件；60 秒结果缓存在 `$XDG_RUNTIME_DIR/agent-usage.cache`
- 显示 `0` / tooltip「无数据」属正常（该机器没有当日会话）

## 脚本

- `agent-menu`：Super+Shift+Ctrl+A，只列出 PATH 中真实存在的 agent
- `agent-apply`：改动唯一入口（求值 → 构建 → 打印 sudo 命令）
- `agent-theme-sync`：随主题同步 agent 侧配色

## 诊断

`modules/agent/diagnostics.nix`（coredump-watch / coredump-analyze）。未开 `localModels` 时不启用。
排查：`coredumpctl list`、`journalctl --user -u <unit>`。
