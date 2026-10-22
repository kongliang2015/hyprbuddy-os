---
name: theme-create
description: 为 hyprland-nixos 生成一套新桌面主题（参考某网站/品牌的配色 → 壁纸 + waybar/mako/fuzzel/swayosd/kitty/hyprlock/polkit 配色），并接入 theme-picker 预览选择。适用于「照 X 官网风格做套主题」这类请求。
---

# theme-create

把「参考某个网站的品牌风格做一套桌面主题」固化成一个可复现流程。产出物是
`scripts/theme-next` 主题表里的一行 + 一张壁纸，自动被 `theme-picker` 收录。

仓库：`~/hyprland-nixos`；宿主：`leonard`（注意 `hostname` 输出是 `nixos`，
flake 里没有该 host，别照抄 hostname）。

## 0. 先定两件事

- **浅色还是深色**：官网常是浅色底，但桌面终端浅色未必讨喜。给出选项让用户选，
  必要时两套都做（同一批色令牌的浅/暗两个切面）。
- **ImageGen 会花 credits**（每张约 5–10）：动手前必须告知用户。

## 1. 从官网取真实色值（不要凭印象猜）

站点用 TDesign 时优先找它自己的设计令牌（本例 `--wb2-*`），比截图取色准：

    cd /tmp
    curl -sL --max-time 20 https://<site>/ -o page.html
    for f in $(grep -oE 'href="[^"]+\.css[^"]*"' page.html | sed 's/href="//;s/"$//'); do
      curl -sL "https:$f" -o "css_$(basename $f)"
    done
    grep -ohE -- '--[a-z0-9-]+:[^;}]+' css_*.css | sort -u | head -60   # 设计令牌
    grep -ohE -- '--wb[a-z0-9-]*:[^;}]+' css_*.css | sort -u             # 站点自有前缀更干净
    cat css_*.css | grep -oE '#[0-9a-fA-F]{6}' | sort | uniq -c | sort -rn | head -20
    grep -ohE 'linear-gradient\([^)]*\)' css_*.css | sort | uniq -c | sort -rn | head

拿到的是：主色 / 文字三级 / 面（page/sunken/card）/ 描边 / 语义色 / 渐变。
WorkBuddy 实测：`#00C29A` 主色、`#009273` 深主色、`#FFF` 面、`#1A1A1A` 文、
`#646464` 次文、`#EBEBEB` 描边、暗部 `#0A0A0A`、渐变 `135deg #28B894→#3B82F6`。

## 2. 壁纸

    ImageGen(prompt="...", size="1536x1024", quality="high", output_dir="/tmp/wbgen")
    magick /tmp/wbgen/x.png -resize 2560x -gravity center -crop 2560x1440+0+0 +repage \
      -alpha off -depth 8 -define png:color-type=2 wallpapers/08-<slug>.png
    identify -format '%wx%h %[channels] %[bit-depth]bit mean=%[fx:int(mean*255)]\n' wallpapers/08-<slug>.png

- 命名 `NN-<slug>.png`，序号接现有最大值（当前到 10）。
- **必须 2560×1440、8bit、3 通道（无 alpha）** —— 带透明通道会让 awww 出黑屏/花屏。
- 用 mean 自检方向：浅色应 >200，深色 <60。
- 壁纸会被 `wallpaper-next` 一起轮播，命名带主题前缀便于辨认。

## 3. 主题表：追加一行，36 个字段

`scripts/theme-next` 的 `THEMES=(...)`，字段顺序（`|` 分隔，一字段不能少）：

| # | 字段 | 含义 |
|---|---|---|
| 1 | NAME | 显示名（picker 用） |
| 2 | WALLPAPER | `wallpapers/` 下文件名 |
| 3-4 | HA1 HA2 | 活动边框渐变两端；同时是 polkit 的 accent / accent_secondary |
| 5 | HI | 非活动边框 |
| 6-7 | WB_BG WB_FG | waybar 底 / 前景 |
| 8-10 | WB_WS WB_WSAFG WB_WSABG | 工作区：静默文字 / 激活文字 / 激活与 hover 底 |
| 11-17 | WB_URGENT CLOCK CPU MEM BAT PULSE AGENT | 各模块前景色 |
| 18-20 | K_BG K_FG K_CURSOR | kitty 底/字/光标 |
| 21-36 | K0..K15 | kitty ANSI 16 色 |

追加前先算一下现有行宽度，写完逐行核：

    awk '/^THEMES=\(/{f=1;next} /^\)/{f=0} f && /^"/{n=split($0,a,"|"); print n, a[1]}' scripts/theme-next
    # 每行必须是 36

派生项不用手填：mako 卡片/描边/进度、fuzzel `[colors]`、swayosd 五色、hyprlock 变量、
hyprtoolkit 认证框配色，全部由脚本按 WB_*/HA* 用 `mixhex` 算出来。

**浅色主题的坑**
- kitty `K7/K15` 别用近白，用中深灰（如 `#57606A`/`#1A1A1A`），否则浅底上不可读。
- `WB_BG` 亮度决定 `agent-theme-sync` 收到 light 还是 dark（阈值 140）；
  浅色行必须真的接近白，否则 opencode 主题会跟错。

## 4. 部署与实测

    scripts/agent-apply leonard        # 求值 + 构建（无 sudo）
    ./install.sh --host leonard --yes  # 软链用户配置 + 复制壁纸 + hypr-check

    theme-next --print-themes          # 新行在列表里，壁纸路径存在
    theme-next <idx>                   # 实际应用
    grep -m2 'color:' ~/.config/waybar/style.css
    head -3 ~/.config/kitty/theme.inc.conf
    cat ~/.config/opencode/tui.json    # light/dark 是否跟对
    grim ~/.local/share/hyprland-nixos/theme-previews/preview-<idx>.png   # picker 预览图

预览图没有时 picker 会退回显示壁纸；要实拍就先切到该主题再 grim。
测完切回用户原来的主题（`--print-themes` 里带「← 当前」的那行）。

## 5. 别踩的坑

- `scripts/theme-preview-capture` 的主题总数已从 `--print-themes` 行数推导，**不要**再写死 N。
- 主题是按**索引**应用的：只往数组末尾追加，别插在中间（会打乱已保存的 idx 与预览图）。
- 不要改 `~/.config` 下的 store 软链；主题切换脚本自己会「摘链 → 写真实文件」。
- 文档里的「N 套主题」是硬编码文案：`README.md`、`docs/COMMANDS-JSON.md`、
  `skills/nixos-desktop-settings/{SKILL,theming}.md` 需要一起改，否则下一个人会被误导。
- 新建 skill 目录后必须重跑 `install.sh`，`~/.codebuddy/skills` 才会出现软链。

## 6. 验收清单

- [ ] 主题表每行 36 字段
- [ ] 壁纸 2560×1440 / 8bit / 无 alpha，mean 方向正确
- [ ] `--print-themes` 有该行且壁纸存在
- [ ] 实机切换后 waybar / kitty / hyprtoolkit / agent 主题同步变化
- [ ] 预览图已生成（或明确说明只有壁纸回退）
- [ ] 文档里的主题数量已更新
