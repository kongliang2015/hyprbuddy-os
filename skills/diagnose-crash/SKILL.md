---
name: diagnose-crash
description: 分析进程崩溃/段错误/core dump：定位原因、排除资源耗尽、符号化栈，输出客观诊断报告。适用于 HyprBuddy OS的机器（含 coredump 自动分析链路）。
---

# diagnose-crash

分析 Linux 崩溃（segfault / abort / OOM kill）与 core dump。

## 先查自动分析产物

若 `distro.agent.diagnostics = true`，systemd 会监听 `/var/lib/systemd/coredump`，
自动分析**最新一次**崩溃并写报告：

    ~/.local/state/agent/coredump-report.md

同时弹桌面通知（应用名 `agent-diagnostics`，标题「崩溃诊断」）。
报告含：`coredumpctl info` 头部 40 行 + 本地模型分析（300 字内）。

前提：断言在 `modules/agent/diagnostics.nix` **模块内部**（不在 `modules/assertions.nix`），
当 `enable && diagnostics` 时要求 `localModels = true`；不满足会在求值阶段**构建失败**，
不是运行时降级。另需已 `ollama pull <distro.agent.model>`，否则分析脚本拿不到模型响应、
只写 coredumpctl 头部或不写报告。

## 手动排查顺序

1. 列出近期崩溃：

       coredumpctl list

2. 看最近一次的完整信息（可执行文件、信号、栈、单元、UID）：

       coredumpctl info --no-pager -1

3. 关联服务日志：

       journalctl -u <unit> -b --no-pager | tail -50

4. 排除资源耗尽（OOM 最常见）：

       journalctl -k -b --no-pager | grep -iE 'out of memory|oom-kill'
       systemctl status <unit> --no-pager

5. 需要精确栈时（可能缺调试符号）：

       coredumpctl debug -1 --debugger=gdb
       # 非交互：coredumpctl dump -1 -o /tmp/core && gdb <exe> /tmp/core -batch -ex bt

## 权限与边界

- 用户自己的崩溃无需 root；**系统级/其它用户的 dump 需要 root**——本发行版规则是
  agent 不执行 sudo，把整理好的命令交给用户
- 只读分析：**不要** `coredumpctl vacuum`，不要删 `/var/lib/systemd/coredump`
- 诊断不联网：本地模型走 `127.0.0.1:11434`，core dump 不出本机

## 报告格式（给用户）

1. **现象**：进程、信号（SEGV / ABRT / KILL）、时间、服务是否重启
2. **证据**：coredumpctl 关键行、相关日志片段、内存/OOM 证据
3. **排除项**：资源耗尽、信号由谁发出（OOM killer / systemd / 用户 kill）
4. **结论**：最可能根因（不确定时明确标注）
5. **建议**：可执行修复（升级版本、改配置、加 swap、限制内存、上报上游）

## 启用自动诊断

    # hosts/<host>/default.nix
    distro.agent = {
      enable = true;
      localModels = true;    # 必需：diagnostics 的断言依赖
      diagnostics = true;
      # agents 里不要放 claude-code（构建期需访问 downloads.claude.ai）
    };

随后 `ollama pull qwen2.5-coder:1.5b`，再走 `agent-apply` → `install.sh` → 用户 `switch`。
