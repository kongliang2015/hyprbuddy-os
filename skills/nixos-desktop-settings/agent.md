# agent：开关、用量、诊断、本地模型

## 开关（`distro.agent.*`，见 `modules/options.nix`）

| 选项 | 默认 | 作用 |
|---|---|---|
| `enable` | false | 安装 agent 包与专用脚本（agent-menu / agent-apply / agent-theme-sync） |
| `agents` | `[ "claude-code" ]` | 安装哪些 agent；**claude-code 构建期需访问 downloads.claude.ai**，网络不通时用 `[ "opencode" "codebuddy" ]` |
| `usage` | true | 部署 `~/.local/bin/agent-usage`，供 **fastfetch 的 command 模块**调用；v5 下若要上栏需在 Noctalia 设置里自行加组件（`CustomButton` 是 v4 字段，已失效） |
| `diagnostics` | true | coredump 诊断单元；`modules/agent/diagnostics.nix` 内的断言要求 `localModels = true`（否则求值失败），且需已 `ollama pull` |
| `localModels` | false | 启用本地模型（ollama） |
| `model` | `qwen2.5-coder:1.5b` | 诊断/摘要使用的模型 |
| `localEndpoint` | 回环 / `lan = false` / 并发 1 / 无 token | 端点暴露策略；见下节 |

## 端点（`distro.agent.localEndpoint`）

- 默认 `bind = "127.0.0.1"`、`maxConcurrent = 1`（即 `OLLAMA_NUM_PARALLEL=1`，串行排队）
- 对外暴露：`lan = true` + `bind = "0.0.0.0"`（或具体网卡地址）。只改一半会被断言拦下——三条断言分别是「非回环 bind 必须开 lan」「lan 必须配非回环 bind」「lan 必须开 localModels」
- `token` 写进 `~/.config/hyprbuddy-os/local-endpoint.env`（`OLLAMA_*` / `OPENAI_*` 各一份），让客户端共用配置；**ollama 不校验它**，不是鉴权
- 验证：`ss -lntp | grep 11434`、`systemctl show ollama -p Environment | grep NUM_PARALLEL`

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
- 本地模型：`model-status` / `model-bench`，用法见下一节

## 本地模型状态与基准（P1）

两个 `check` 类命令，`@doc` 指向本文件。前提：`distro.agent.localModels = true`、系统已 switch、已 `ollama pull`。

### model-status

```bash
model-status          # 文本
model-status --json   # 机器可读
```

只读：查 `ollama.service` 状态、`127.0.0.1:11434/api/tags` 可达性、模型列表、GPU 显存 / 功耗。**端点不可达时退出码 1**。

JSON 字段：`service`、`endpoint_ok`、`models[]`、`gpu.{source,memory_used_mib,memory_total_mib,power_w}`、`ok`。

### model-bench

```bash
model-bench                     # 默认 qwen2.5-coder:1.5b
model-bench --model <name> --json
```

跑三档并输出 tok/s 与功耗：idle（无请求）、单请求、3 路并发。**有副作用**：会向本机 ollama 发推理请求，并把三档结果写入 `~/.local/state/hyprbuddy-os/power-bench.json`（`power-status --json` 的 `power.scenarios` 从这里读）。端点不可达时直接退出 1，不写文件。

**功耗口径**：只采 `nvidia-smi power.draw`（GPU 功耗，非整机瓦数）。CPU 版下 CPU 推理时 GPU 几乎空闲，三档读数接近 idle；读不到（本机 GTX 1050 Ti 返回 `[N/A]`）则为 `null`、`power_source` 标 `unavailable`——这是如实留空，不是故障，**不要为了让数字好看而伪造**。需要 CPU 侧功耗时用 `/sys/class/powercap/*/energy_uj` 两次采样求差。

### 一次完整验收

```bash
model-status --json     # 端点可达、模型在列表里
model-bench --json      # 三档 tok/s；功耗可为 null
power-status --json     # power.scenarios 应回显 model-bench 的三档值
```

## 诊断

`modules/agent/diagnostics.nix`（coredump-watch / coredump-analyze）。未开 `localModels` 时不启用。
排查：`coredumpctl list`、`journalctl --user -u <unit>`。
