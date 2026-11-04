# troubleshooting：常见故障

## 先跑自检

    scripts/hypr-check

四项检查：① 0.55 的 Lua 优先（存在 `hyprland.lua` 时 `.conf` 被忽略）
② `hyprctl configerrors`（需会话内）③ 规则语法 lint（缺 `match:` 前缀会静默失效）
④ 命令清单一致性（清单标记可用的命令是否都已部署）

## 状态栏不显示

1. CSS 非法：`:root` / `var()` 会让 waybar 解析失败拒绝启动 → 全部改具体色值
2. 进程检测：wrapper 的 comm 是 `.waybar-wrapped`，用 `pgrep waybar`，不要 `pgrep -x`
3. 并发 spawn：exec-once 与配置变更自动重载可能各起一个 → 用 flock 串行化

## 锁屏解锁后工作区数字消失

`lib/waybar.nix` 的 `hyprland/workspaces` 需要 `"persistent-workspaces" = { "*" = 4; }`。

## 锁屏出现两个输入框

hyprlock 的 `source` 是**追加**语义，不是覆盖：主题文件只放变量，默认值在前、`source` 在后。

## 中文变豆腐块 / kitty 字体难看

- 先查 `/etc/fonts` 是否存在：缺失时应用扫不到任何字体目录
- 已知成因：`installation-cd-minimal.nix` 用 `mkOverride 500` 关闭 `fonts.fontconfig.enable`；
  修法：`fonts.fontconfig.enable = lib.mkForce true;`
- 字体包（`modules/base.nix`）：`wqy_zenhei`、`noto-fonts-cjk-sans`、`nerd-fonts.jetbrains-mono`
- 验证：`fc-match "sans-serif:lang=zh-cn"`、`fc-list :lang=zh-cn | wc -l`

## Super+Space 菜单打不开

绑定是绝对路径 `@HOME@/.local/bin/hypr-menu`。若 `~/.local/bin` 被误建为真实目录，
脚本会落到 `~/.local/bin/bin/` 导致失效。正确形态：`~/.local/bin` 本身是指向 store `.../bin` 的软链。

## VNC 里鼠标指针重叠黑色 X

virtio-gpu 软件渲染无硬件光标平面，宿主 VNC 客户端自绘光标叠加——仅影响观看，截图不含，可忽略。

## 登录后没有面板（noctalia 没起）+ ~/.config 里配置是空的

典型症状：桌面只有壁纸，没有 bar / 快捷键失效；`~/.config/niri/config.kdl` 大小为 0。

原因：install.sh 部署的是 store 里的产物，而某些 store 文件被**截断成 0 字节**
（上次异常关机/断电时 nix 正在写），但 nix 仍认为该路径有效，于是不会重建。

诊断：

```bash
wc -c ~/.config/niri/config.kdl                       # 0 → 确认
p=$(readlink -f ~/.config/niri/config.kdl)
nix-store --verify-path "$p"                          # 报 "was modified!" 即损坏
```

修法（需要能写 store 的权限）：

```bash
rm -f ~/.local/share/hyprland-nixos-home              # 先解除 GC root
nix-store --delete $(readlink -f ~/.config/niri/config.kdl)
cd ~/hyprland-nixos && ./install.sh --host vmware --yes
```

若多处损坏，可先 `nix-store --verify --check-contents` 全量体检。

## fuzzel.ini 变成 0 字节

store 中间软链未就绪时直接写会得空文件；theme-next 已用「写 tmp → 非空才替换」规避。

## Noctalia v5：bar 突然消失

**现象**：登录后或解锁后看不到 bar，桌面只有壁纸。

**判读顺序**：

```bash
noctalia msg status          # {"barVisible": false, "locked": false}
ls ~/.config/noctalia/       # 应该只有 theme.toml（+ GUI 生成的 state 不在这里）
```

- `locked: true` + `barVisible: false` → **锁屏中，bar 本来就会隐藏**，解锁后自动恢复。
- `locked: false` + `barVisible: false` → bar 被**显式隐藏**了：`noctalia msg bar-toggle` /
  `bar-hide` 都会留下运行态标志，锁屏→解锁**不会**清除它。

**恢复**：

```bash
noctalia msg bar-show
```

该标志不写进 `~/.local/state/noctalia/settings.toml`，也不在 `shell-state.json` 里，
所以重启/重登也会恢复；但**当次会话必须手动 bar-show**。

> 教训：验证命令可用性别用 `bar-toggle`（有副作用）。用 `noctalia msg --help`
> 或 `status` / `*-status` 这类只读命令。

## Noctalia v5：配置里有 unknown setting 告警

日志形如：

```
[WRN] [config] ~/.config/noctalia/theme.toml:11:13: wallpaper.recursive: unknown setting
```

5.0.1 的 schema 比官网文档（2.0/新版）窄，文档里有的键它不一定认。已踩过：
`wallpaper.recursive`、`theme.sync_color_scheme`。处理：从 exporter 里删掉该键。
校验方式：改完 `noctalia config validate` 应无 warning。

## Noctalia v5：夜间模式没反应

日志：`[WRN] [gamma] no schedule: enable auto-locate, set an address, ...`

夜间模式需要 Location（地址或经纬度）或自定义日程才有依据。`noctalia msg nightlight-toggle`
依然返回 `ok`，但不会真的改色温。修法：Noctalia 设置 → Location 填地址，或设自定义日程。

## Noctalia v5：自定义调色板（source="custom"）加载失败

日志：`[WRN] [theme] custom palette '<name>' not found or invalid; falling back to builtin`

排查结论（2026-10-29，5.0.1 实测）：

- 文件路径确认无误：`~/.config/noctalia/palettes/<name>.json`（strace 确认被 open 成功）
- 失败原因是**内容校验**，不是路径。已试过并全部被判 invalid 的写法：
  1. 扁平 16 个 `m*` 键
  2. `{"dark":{m*},``light``:{m*}}`
  3. `{"name","dark":{plain},"light":{plain}}`（社区 catalog 的写法）
  4. 数组 `[{"name","dark","light"}]`
  5. `{"name","colors":{m*}}`
  6. `noctalia theme <image> --both` 的完整 token 表（72 键、无 null），含/不含 `name`

当前策略：外壳配色走 `source="wallpaper"`（壁纸取色），不写死 custom palette。
`~/.local/state/noctalia/settings.toml` 的优先级高于 `~/.config/noctalia/*.toml`，
GUI 里点过主题设置后，手写 config 会被 state 覆盖——验证时先删 state 里对应段落。

## Noctalia v5：bar 布局改在仓库里无效

仓库**只**声明 `[theme]` 与 `[wallpaper]`（exporter 生成的 theme.toml）。
`[bar.*]` 故意不做声明式基线，原因有两个：

1. GUI 改动写进 `~/.local/state/noctalia/settings.toml`，优先级更高，基线会被逐项覆盖，
   容易造成"改了仓库没反应"的错觉；
2. 5.0.1 的 bar/widget schema 与文档版本不一致，写错就是 unknown setting。

所以 bar 布局属于**本机运行态**：换机/重装会回默认，需要重新在 GUI 里调。
