---
name: nixos-system-ops
description: HyprBuddy OS 系统运维入口：机器变慢、服务挂了、磁盘满、要更新或回滚时的第一动作。先用 sys-* 只读命令拿事实，再决定是否把 sudo 命令交给人；不执行 sudo。
---

# nixos-system-ops

系统层运维与排障。**桌面外观/键位/主题**这类请求走 `nixos-desktop-settings`，这里只管"机器状态"。

仓库：`~/hyprbuddy-os`（`HYPRBUDDY_OS_REPO` 可覆盖）；host 取 `hosts/` 下的真实目录名（当前机器 `vmware`）。

## 铁律

1. **先只读，后动手**：能用 `sys-health` 拿到的结论，不要凭猜测直接重启服务
2. **agent 不执行 sudo**：需要特权的操作只打印命令交给人（`sys-rollback` / `sys-gc` 都是这么设计的）
3. **输出可追溯**：日志类命令不加工内容（只去 ANSI），保证能直接贴给用户
4. **改配置 ≠ 修系统**：需要改仓库时转 `nixos-desktop-settings`（构建/部署流程在那）

## 决策树

| 症状 / 请求 | 第一动作 | 后续 |
|---|---|---|
| "机器很卡 / 不知道哪里不对" | `sys-health` | 看磁盘/内存/failed 单元，再定位 |
| "某个服务挂了" | `svc-status` | `sys-log --unit <name> -n 100` |
| "桌面没反应 / 面板不见了" | `desktop-check` | 再 `svc-status`、`sys-log --grep noctalia` |
| "报错了，看下日志" | `sys-log --level err -n 100` | 加 `--unit` / `--since` 收窄 |
| "连不上网 / 网速异常" | `net-status` | 看网关通不通、DNS 能不能解析 |
| "发烫 / 风扇吵 / 想换性能档" | `power-status` | 看温度、档位、谁在阻止休眠 |
| "磁盘满了 / nix store 太大" | `sys-gc` | 按提示跑 `sudo nix-collect-garbage …` |
| "升级 / 回滚" | `sys-update --check` · `sys-rollback` | 见 `lifecycle.md` |
| "崩溃 / core dump" | 技能 `diagnose-crash` | — |
| 改桌面外观、键位、主题 | 技能 `nixos-desktop-settings` | — |

## 命令速查

| 命令 | 只读 | 退出码 | 耗时 | 说明 |
|---|---|---|---|---|
| `sys-health [--json]` | ✅ | 磁盘≥90%、有 failed 单元或关键进程缺失 → 1 | 0.15s | 磁盘/内存/负载/温度/服务/日志/进程 |
| `svc-status [unit…] [--json]` | ✅ | failed/not-found/进程缺失 → 1 | 0.2s | 7 个关键单元，`inactive` 视为按需启动 |
| `sys-log [--user\|--system] [--since T] [--unit U] [--grep P] [-n N] [--level L] [--json]` | ✅ | 仅权限问题 → 1 | <0.1s | journalctl 薄封装，自动去 ANSI |
| `sys-rollback [--limit N] [--json]` | ✅ | 0 | <0.1s | 列世代 + 打印 switch/boot 命令 |
| `net-status [--json]` | ✅ | 网关不通或 DNS 全失败 → 1 | ~5s | 接口/路由/Wi-Fi/网关时延/DNS 解析 |
| `power-status [--json]` | ✅ | 电池 <10% → 1 | <0.1s | 性能档位/CPU 温度/电池/亮度/空闲抑制 |
| `sys-gc [--fast] [--json]` | ✅ | 0 | 9s（`--fast` 8s） | 分区占用、dead 路径、可回收上限 |
| `sys-update [--check\|--apply] [--host H] [--json]` | 默认/`--check` ✅ | `--check` 有更新 → 1 | 30s（联网） | 更新 flake 输入并构建 |

## 三步排障法

```bash
sys-health                       # 1. 有没有客观异常（磁盘/内存/failed/进程）
svc-status                       # 2. 具体哪个单元不对
sys-log --unit <unit> -n 100     # 3. 上下文日志
```

拿到足够事实再动手；需要提权的修复，输出命令让用户执行，不要自己尝试 `sudo`。

## 参考

| 文件 | 内容 |
|---|---|
| `diagnose.md` | 常见症状 → 判读 → 处置（含本机踩过的坑） |
| `lifecycle.md` | 更新 / 回滚 / GC 的完整流程与提交顺序 |
| `../../docs/agent-coverage-review.md` | 能力覆盖矩阵与补齐方案（为什么只有这 6 条） |
