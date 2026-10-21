# skill 改造方案（设计稿，未实施）

> 状态：待实施　|　目标：把 `skills/nixos-desktop-settings` 从单文件升级为
> 「路由器 + 专题指南 + 示例表」结构，提升 agent 一次做对的概率。
> 灵感来自 Omarchy skill 的组织形式，但操作模型按 NixOS 不可变系统重写（见 §7 对比结论）。

## 1. 目标结构

```
skills/
├── nixos-desktop-settings/
│   ├── SKILL.md            # 路由器（≤120 行）：窄触发 + 铁律 + 决策树 + 示例表
│   ├── workflow.md         # 修改流程详解：agent-apply → install.sh → switch / 回滚 / 生效方式
│   ├── hyprland.md         # 键位、窗口规则、layer 规则、monitor、动画、输入法
│   ├── bar-notify.md       # waybar（lib/waybar.nix 唯一来源）+ mako + swayosd
│   ├── theming.md          # theme-next 全链路：5 主题、壁纸、waybar/mako/fuzzel/swayosd 联动
│   ├── agent.md            # agent 层：菜单、用量、诊断、本地模型（受 distro.agent.* 开关）
│   └── troubleshooting.md  # hypr-check 判读、状态栏消失、锁屏双输入框、字体豆腐块、virtio 光标
└── diagnose-crash/         # 阶段 2：对接 modules/agent/diagnostics.nix
    └── SKILL.md
```

每个文件由 `install.sh` 自动链接（`skills/<dir>/*` 规则），新增指南零代码改动。
SKILL.md 保留窄描述——不引入 Omarchy 式「任何 ~/.config 编辑都触发」，
因为在本系统中直改 ~/.config 恰恰是错误操作。

## 2. SKILL.md 构成

### 铁律（置于最前）

1. 改仓库源文件，**绝不改** `~/.config` 下的 store 软链
   （例外：theme-next 重写的 `~/.config/waybar/style.css` 本就应被脚本覆盖）
2. agent **不执行 sudo**；系统级改动构建验证后把命令交给用户
3. `/etc/nixos/configuration.nix` 是防误用桩，**绝不修改**

### 决策树（7 步）

| 请求类型 | 入口 |
|---------|------|
| ① 即时生效的运行时动作（主题/壁纸/免打扰/录屏/夜间模式） | `theme-next` / `wallpaper-next` / `notif-dnd` / `record-toggle` / `night-mode` |
| ② 桌面外观/行为（键位、规则、bar、通知、终端） | 改 `home/` → `scripts/agent-apply <host>` → `./install.sh --host <host> --yes` |
| ③ 系统组件/服务/驱动 | 改 `modules/` 或 `hosts/<host>/` → agent-apply → 交用户 `sudo nixos-rebuild switch` |
| ④ agent 能力 | `modules/agent/` + `lib/agent-usage.nix` + `scripts/agent-*`（受 `distro.agent.*` 开关） |
| ⑤ 硬件差异 | `hosts/<host>/default.nix` 只写 `distro.*`（选项以 `modules/options.nix` 为准） |
| ⑥ 新 host | `hosts/<name>/default.nix` + `hardware-configuration.nix` |
| ⑦ 不确定入口/报错 | `scripts/hypr-check` → `docs/KEYBINDS.md` → `git log --oneline -10` |

## 3. 示例表（SKILL.md 末尾）

| 用户请求 | 操作 | 文件/命令 |
|---------|------|-----------|
| "Super+E 改成打开 Nautilus" | 改绑定 | `home/hypr/hyprland.conf` `bind = $mainMod, E, exec, nautilus` |
| "加个 Super+G 打开 btop" | 加绑定 | 同文件 `bind = $mainMod, G, exec, btop` |
| "外接 2K 显示器放右边" | 改 monitor | `monitor = DP-1, 2560x1440@60, 1920x0, 1` |
| "圆角大一点、窗口间隙小一点" | decoration/general 段 | `home/hypr/hyprland.conf`（0.55 语法，改完必过 `hypr-check`） |
| "让 GIMP 窗口默认浮动" | windowrule | `windowrule = match:class (gimp), float`（0.55 必须带 `match:` 前缀） |
| "waybar 右侧加 CPU 温度" | 改生成器 | `lib/waybar.nix`（唯一来源，系统级与用户级共用） |
| "通知 3 秒消失、紧急常驻" | mako 段 | `home/mako/config`（新增颜色键须同步 `scripts/theme-next` 替换列表） |
| "10 分钟无操作锁屏" | idle 配置 | `home/hypr/hypridle.conf` |
| "终端字号改 13" | kitty 配置 | `home/kitty/kitty.conf` |
| "换个主题" | 运行时 | `theme-next`（5 套循环；`theme-next restore` 仅供登录时 exec-once） |
| "换壁纸" | 运行时 | `wallpaper-next` |
| "夜间模式 / 勿扰 / 录屏 / 区域截图标注" | 运行时 | `night-mode` / `notif-dnd` / `record-toggle` / `screenshot-annotate` |
| "现在有哪些快捷键" | 只读 | `show-keybinds`（浮动 kitty）或 `docs/KEYBINDS.md` |
| "这台新机器是 N 卡" | host 选项 | `hosts/<name>/default.nix` `distro.gpu.vendor = "nvidia"` |
| "waybar 显示 agent 用量" | agent 开关 | `hosts/<host>` 设 `distro.agent.enable/usage = true`；逻辑在 `lib/agent-usage.nix` |
| "桌面报错 / 状态栏没了 / 中文变方块" | 自检+排障 | `scripts/hypr-check` → `troubleshooting.md` |
| "回到上一个系统版本" | 用户执行 | `sudo nixos-rebuild --rollback`（agent 只给命令） |
| "用户级配置改了没生效" | 重新部署 | `./install.sh --host <host> --yes`（真实文件备份到 `~/.config.bak-*`） |

## 4. 各指南内容要点

- **workflow.md**：四步流程；三处生效方式（`hyprctl reload` / `makoctl reload` / 重新登录）；备份与回滚；agent-apply 输出判读（eval 失败 vs build 失败）
- **hyprland.md**：绑定语法表；windowrule/layerrule 0.55 `match:` 语法；monitor 写法；decoration；fcitx5 注意（须用 `config.i18n.inputMethod.package` 才带拼音）
- **bar-notify.md**：`lib/waybar.nix` 唯一来源（`/etc/xdg/waybar` 与用户级共用）；CSS 禁用 `:root`/`var()`（GTK 解析失败会拒绝启动）；mako 颜色键与 theme-next 的耦合
- **theming.md**：5 套主题结构；theme-next 改写范围（waybar/style.css 整份重写、fuzzel 变色、mako 颜色、swayosd 5 色）；awww 壁纸守护前提（`exec-once` 已含 sleep 1）
- **agent.md**：`distro.agent.*` 开关矩阵；agent-usage 三数据源与 /cost 口径；diagnostics 需 localModels；claude-code 构建期网络限制
- **troubleshooting.md**：hypr-check 三项检查含义；状态栏消失（CSS 非法 / 进程 comm 是 `.waybar-wrapped`，须 `pgrep waybar`）；锁屏双输入框（hyprlock `source` 是 APPEND）；字体豆腐块（`/etc/fonts` 缺失，安装 CD 的 `mkOverride 500` 曾关闭 fontconfig）；VNC 黑 X 光标（虚拟机特性，可忽略）

## 5. 实施约束

| 项 | 约定 |
|----|------|
| 体积 | SKILL.md ≤120 行，各 guide ≤80 行，总计 <400 行 |
| 单一事实源 | 绑定/路径只在 guide 写一次，SKILL.md 只做路由与索引 |
| 兼容性 | 纯 markdown；不改 flake 与 `home/default.nix`（`skills/<dir>/*` 已通用收纳） |
| 分发 | `install.sh` 自动链接；`~/.claude` 存在时同步 |

## 6. 阶段计划

- **阶段 1**：拆出 6 个文件 + 示例表（现有单文件内容不丢失）
- **阶段 2**（已实施）：`diagnose-crash` 技能，对接 `modules/agent/diagnostics.nix`（coredump-watch / coredump-analyze）

## 7. 与 Omarchy skill 的对比结论（决定不照搬的原因）

| 维度 | Omarchy | 本仓库 |
|------|---------|--------|
| 配置真相源 | `~/.config/`（用户直接拥有） | 仓库 git；`~/.config` 是 store 软链产物 |
| 应用机制 | 保存即热重载 + `omarchy refresh/restart` | `agent-apply` 求值构建 + `install.sh` 重链 + 用户 switch |
| 特权模型 | agent 可 `sudo`/`pkexec` | agent 永不提权 |
| 命令面 | 统一 `omarchy` CLI（14 组） | 离散脚本 + `hyprctl`/`makoctl` |
| 结构 | SKILL.md + 6 篇专题指南 | （本方案补齐） |

结论：可直接借鉴**多文件结构、决策树、示例表、命令发现、diagnose-crash**；
不可移植**直改 ~/.config 的工作流、omarchy CLI 语义、sudo/pkexec 提权规则**、
以及宽泛触发描述。
