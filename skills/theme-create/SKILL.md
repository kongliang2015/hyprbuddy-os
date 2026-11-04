---
name: theme-create
description: 为 HyprBuddy OS 生成一套新主题（参考网站/品牌配色 → 壁纸 + themes/<slug>/tokens.json），并接入 theme-picker 预览选择。适用于「照 X 官网风格做套主题」这类请求。
---

# theme-create

一套主题 = **一张壁纸 + 一个 `themes/<slug>/tokens.json`**。
`theme-picker` / `theme-next` 会自动收录，无需改任何数组。

仓库：`~/hyprbuddy-os`；host 取 `hosts/` 下的真实目录名（当前机器是 `vmware`），不要照抄别处的示例 host。

## 0. 先定三件事

- **深色还是浅色**：官网常是浅色，桌面终端未必讨喜。给用户选，必要时两套都做
- **slug**：小写连字符（`deepin-blue`、`rose-pine`），会成为目录名
- **ImageGen 花 credits**（每张约 5–10）：生成壁纸前必须告知用户

## 1. 取真实色值（不要凭印象猜）

```bash
cd /tmp
curl -sL --max-time 20 https://<site>/ -o page.html
for f in $(grep -oE 'href="[^"]+\.css[^"]*"' page.html | sed 's/href="//;s/"$//'); do
  curl -sL "https:$f" -o "css_$(basename $f)"
done
grep -ohE -- '--[a-z0-9-]+:[^;} ]+' css_*.css | sort -u | head -60   # 设计令牌
cat css_*.css | grep -oE '#[0-9a-fA-F]{6}' | sort | uniq -c | sort -rn | head -20
```

要拿到：主色 / 文字三级 / 面（page / card）/ 描边 / 语义色（成功/警告/危险）。

## 2. 壁纸

```bash
ImageGen(prompt="...", size="1536x1024", quality="high", output_dir="/tmp/wbgen")
magick /tmp/wbgen/x.png -resize 2560x -gravity center -crop 2560x1440+0+0 +repage \
  -alpha off -depth 8 -define png:color-type=2 wallpapers/NN-<slug>.png
identify -format '%wx%h %[channels] %[bit-depth]bit\n' wallpapers/NN-<slug>.png
```

- 命名 `NN-<slug>.png`，序号接现有最大值（`ls wallpapers | tail -1`）
- **2560×1440、8bit、3 通道（无 alpha）**
- 深浅自检：`identify -format '%[fx:int(mean*255)]'`，浅色 >200、深色 <60

## 3. 写 `themes/<slug>/tokens.json`

```json
{
  "name": "Rose Pine",              // 显示名（picker 用）
  "wallpaper": "04-rose-pine.png",  // wallpapers/ 下的文件名
  "dark": true,                     // 决定 Noctalia darkMode 与 agent-theme-sync 方向
  "bg": "191724", "fg": "E0DEF4",
  "accent": "9CCFD8", "accent2": "C4A7E7",
  "inactive": "6E6A86", "surface": "2A283E",
  "muted": "6E6A86", "urgent": "EB6F92",
  "bar": { "clock": "...", "cpu": "...", "mem": "...", "battery": "...", "pulse": "...", "agent": "..." },
  "terminal": { "bg": "...", "fg": "...", "cursor": "...", "colors": ["16 个 ANSI 色"] },
  "order": 11                       // theme_list 按它排序，决定索引位置
}
```

规则：

- 色值**不带 `#`**（6 位十六进制）
- `terminal.colors` 必须 16 项：`[0]=黑/底，1..7=red..white，8..15=bright black..bright white`
- 浅色主题：`terminal.colors[7]`/`[15]` 别用近白，用中深灰（否则浅底不可读）
- **`order` 取当前最大值 +1，不要插在中间**——索引变化会打乱已保存的当前主题与预览图

## 4. 部署

```bash
scripts/agent-apply <host>        # 求值 + 构建（无 sudo）
./install.sh --host <host> --yes  # 部署 tokens + 复制 wallpapers/ 到 ~/Pictures/wallpapers
```

## 5. 应用与验证

```bash
theme-next --print-themes          # 新主题应在列表里（按 order 排序）
de-theme-apply <slug>              # 应用，看输出三行
head -3 ~/.config/kitty/theme.inc.conf     # 终端配色是否跟到
grep -A3 "^\[colors\]" ~/.config/fuzzel/fuzzel.ini   # 启动器配色
cat ~/.config/noctalia/theme.toml          # v5：source=wallpaper 时面板配色由壁纸推导
```

## 6. 写设计说明 `docs/themes/<Name>.md`

tokens 只有一个 JSON，读不出「哪个色用在哪」。每套配一份说明：

- slug / 索引号 / 切换命令 / 壁纸与预览图路径
- 角色配色表：色值 → 角色 → 实际落点（kitty 光标 / fuzzel 选中 / SDDM 按钮…）
- 与参考站点的对应关系（哪个色来自哪里）

## 7. 坑

1. **v5 的面板配色来自壁纸取色**（`theme.toml` 的 `source = "wallpaper"`），
   tokens 里 `accent` 不会直接影响 Noctalia bar。要让面板精确跟随 tokens，
   需走 v5 的 custom palette（`~/.config/noctalia/palettes/`），格式另需实测
2. 主题按 `order` 索引，只追加不插队
3. 壁纸必须 RGB（无 alpha），否则部分壁纸服务会黑屏
4. 新建/改动 skill 目录后要重跑 `install.sh`，`~/.codebuddy/skills` 才会更新
5. 文档里的「N 套主题」是硬编码文案：`README.md`、`skills/nixos-desktop-settings/{SKILL,theming}.md`
   需要一起改
