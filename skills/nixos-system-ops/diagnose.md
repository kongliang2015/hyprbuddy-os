# diagnose：症状 → 判读 → 处置

## 1. 机器变慢 / 卡顿

```bash
sys-health
```

| 看到 | 含义 | 下一步 |
|---|---|---|
| 磁盘 ≥90% | 空间不足导致 io 抖动、nix 构建失败 | `sys-gc` → 清理 |
| swap 用量高 + 内存接近满 | 内存压力 | `ps aux --sort=-%mem \| head` 找大户 |
| load 远高于核数 | CPU/IO 饱和 | `btop`，或 `sys-log --level err` |
| CPU 温度 >90°C | 散热/降频 | `power-status` 看档位与温度，见第 7 节 |
| failed 单元 >0 | 有服务没起来 | `svc-status` 找到它 |

## 2. 服务没起来

```bash
svc-status                       # 先看哪个不是 active
sys-log --unit <unit> -n 100     # 再看完整上下文
systemctl --user cat <unit>      # 确认 ExecStart（改了单元但没 switch 是常见原因）
```

判读要点：

- `inactive` **不等于**坏了：`udisks2` 这类 D-Bus 按需启动的单元常态就是 inactive
- `not-found` 说明单元不存在——多半是改了仓库没 `nixos-rebuild switch`，或单元名写错
- 用户级单元要带 `--user`（`sys-log --user` 默认就是用户日志）

## 3. 会话启动后缺东西（面板/输入法/托盘）

```bash
desktop-check
journalctl --user -b | grep -iE "noctalia|fcitx5|polkit" | tail -20
```

**本机踩过的三类真实原因**：

| 现象 | 原因 | 判据 |
|---|---|---|
| 没有面板 | `~/.config/niri/config.kdl` 还是旧版，spawn 了不存在的二进制 | 日志 `exec: noctalia-shell: 未找到`；journal 里缺 noctalia 的 `app-niri-*` scope |
| 输不了中文 | fcitx5 抢在 wayland socket 之前启动 | `Failed to open wayland connection` |
| 无法提权（无密码框） | Qt 样式名 `adwaita-dark` 让代理 QML 加载失败 | `module "adwaita-dark" is not installed` |

## 4. 日志怎么查才不淹

```bash
sys-log --level err -n 50              # 先看错误级别
sys-log --since "10 min ago" -n 100    # 按时间窗
sys-log --unit niri -n 50              # 按单元
sys-log --grep wayland --since today   # 按关键词
sys-log --system --level err           # 系统侧（当前用户可读）
```

注意：`sys-log` 会剥掉消息体里的 ANSI 序列——polkit agent 等程序自带颜色，
不清洗会在管道里变成 `:5:245m` 这类垃圾。

## 5. 判断「是不是我改的东西坏了」

```bash
git -C ~/hyprbuddy-os log --oneline -5       # 最近改了什么
git -C ~/hyprbuddy-os status --short         # 有没有未提交改动（flake 会包含它们）
sys-rollback                                   # 上一代能不能回
```

如果最近一次 `install.sh` 部署过、但 `~/.config` 里的文件还是旧的，多半是**提交顺序**问题：
flake 只认 git 跟踪的文件，没 commit 的改动进不了 store（详见 `lifecycle.md`）。

## 6. 连不上网 / 网很慢

```bash
net-status
```

按「地址 → 路由 → 网关 → DNS」四层往下判：

| 现象 | 含义 | 下一步 |
|---|---|---|
| 接口没有 IP | DHCP 失败 | `nmcli device status`；`sudo systemctl restart NetworkManager` |
| 有 IP 但「无默认路由」 | 网关没下发 | 重连：`nmcli con up <name>` |
| 网关 ping 不通 | 二层/AP 层问题 | 换网线/重连 Wi-Fi；看 `sys-log --grep wlan` |
| 网关通、DNS 全 ✗ | 解析坏了 | `nmcli con mod <name> ipv4.dns "223.5.5.5 1.1.1.1"` 后 `nmcli con up <name>` |
| DNS 逐个 ✗ 但某些通 | 上游 DNS 慢/污染 | 同上换 DNS；对比 `resolvectl query <域名>` |
| 网关 RTT >100ms | 无线质量差 | 看 `signal`，<40 考虑换位置/换 5G 频段 |

**手工排查也要注意 locale**：中文环境下 `nmcli` 的 ACTIVE 字段是「是/否」、
`ping` 输出是「时间=3.24 毫秒」，按英文正则抓会一无所获。脚本里已统一 `LC_ALL=C`。

## 7. 发烫 / 风扇吵 / 想换性能档

```bash
power-status
```

| 现象 | 含义 | 下一步 |
|---|---|---|
| 温度 >90°C 且 load 低 | 散热问题（积灰/风道/风扇停转） | 物理检查；`sensors` 看各传感器 |
| 温度高且 load 高 | 有进程在跑 | `btop` 或 `ps aux --sort=-%cpu \| head` |
| 档位是 power-saver 但卡顿 | 被限频 | `powerprofilesctl set balanced`（或 `performance`） |
| 空闲抑制 >0 但机器不休眠 | 有程序在阻止 | `systemd-inhibit --list` 看 holder 与原因 |
| 电池 <10%（笔记本） | 即将断电 | 立即充电；低电量待机会丢未保存数据 |
| 电池/亮度显示「—」 | 台式机无对应硬件 | 正常，不是故障 |
