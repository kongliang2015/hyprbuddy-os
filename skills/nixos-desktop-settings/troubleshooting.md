# troubleshooting：常见故障

## 先跑自检

    desktop-check

图形会话全量、非图形会话自动降级；覆盖进程 / portal / 壁纸 / bar / 字体 /
命令 / 键位引用 / 壁纸目录 / 夜间模式日程 / 配置告警。

面板或锁屏问题再看日志：

    journalctl --user -b | grep -i noctalia

## 中文变豆腐块 / kitty 字体难看

- 先查 `/etc/fonts` 是否存在：缺失时应用扫不到任何字体目录
- ISO 场景已知成因：`installation-cd-minimal.nix` 用 `mkOverride 500` 关闭
  `fonts.fontconfig.enable`；修法：`fonts.fontconfig.enable = lib.mkForce true;`
- 字体包（`modules/base.nix`）：`wqy_zenhei`、`noto-fonts-cjk-sans`、`nerd-fonts.jetbrains-mono`
- 验证：`fc-match "sans-serif:lang=zh-cn"`、`fc-list :lang=zh-cn | wc -l`

## 登录后没有面板 / 配置是 0 字节（store 产物损坏）

典型症状：桌面只有壁纸，没有 bar / 快捷键失效；`~/.config/niri/config.kdl` 大小为 0。

原因：install.sh 部署的是 store 里的产物，而某些 store 文件被**截断成 0 字节**
（异常关机 / 断电时 nix 正在写），但 nix 仍认为该路径有效，于是不会重建。
该事故最初发生在 Noctalia v4 时期，但根因与桌面版本无关，v5 同样适用。

诊断：

```bash
wc -c ~/.config/niri/config.kdl                       # 0 → 确认
p=$(readlink -f ~/.config/niri/config.kdl)
nix-store --verify-path "$p"                          # 报 "was modified!" 即损坏
```

修法（需要能写 store 的权限）：

```bash
rm -f ~/.local/share/hyprbuddy-os-home              # 先解除 GC root
nix-store --delete $(readlink -f ~/.config/niri/config.kdl)
cd ~/hyprbuddy-os && ./install.sh --host vmware --yes
```

若多处损坏，可先 `nix-store --verify --check-contents` 全量体检。

## fuzzel.ini 变成 0 字节

store 中间软链未就绪时直接写会得空文件；theme-next 已用「写 tmp → 非空才替换」规避。

## `~/.local/bin` 被误建为真实目录（脚本 / 快捷键失效）

`~/.local/bin` 必须是指向 store `.../bin` 的软链。若被误建为真实目录，
install.sh 会把脚本落到 `~/.local/bin/bin/`，PATH 里找不到 → 快捷键和自定义脚本静默失效。

```bash
ls -ld ~/.local/bin     # 应显示 -> /nix/store/...-user-config-<host>/bin
```

## VNC 里鼠标指针重叠黑色 X

virtio-gpu 软件渲染无硬件光标平面，宿主 VNC 客户端自绘光标叠加——仅影响观看，
截图不含，可忽略。

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

夜间模式需要 Location（地址或经纬度）或自定义日程才有依据；没有坐标时
`noctalia msg nightlight-toggle` 仍返回 `ok`，但不会改色温。

现已声明式配置（`hosts/<host>/default.nix`）：

```nix
distro.desktop.nightlight = {
  enable = true;
  autoLocate = true;        # 按公网 IP 定位；也可用 address 或 latitude/longitude
  temperatureDay = 6500;
  temperatureNight = 4000;  # 必须比白天低至少 100K
};
```

install.sh 会把它生成成 `~/.config/noctalia/nightlight.toml`（只读软链，勿手改）。
验证：

```bash
grep -a 'geo schedule' ~/.cache/noctalia/noctalia.log | tail -1   # 有日程即定位成功
noctalia msg nightlight-force-toggle                              # 立刻按夜间色温渲染
noctalia msg nightlight-force-toggle                              # 恢复随日出日落
```

生效时日志是 `[INF] [gamma] target 4000K (day=6500K night=4000K force=true ...)`。

## Noctalia v5：自定义调色板（source="custom"）加载失败

日志：`[WRN] [theme] custom palette '<name>' not found or invalid; falling back to builtin`

排查结论（2026-10-29，5.0.1 实测）：

- 文件路径确认无误：`~/.config/noctalia/palettes/<name>.json`（strace 确认被 open 成功）
- 失败原因是**内容校验**，不是路径。已试过并全部被判 invalid 的写法：
  1. 扁平 16 个 `m*` 键
  2. `{"dark":{m*},`light`:{m*}}`
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
