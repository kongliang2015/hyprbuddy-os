# theming：tokens → 壁纸取色 + 终端/启动器配色

## 唯一真相

`themes/<slug>/tokens.json`：每套主题一个文件，含 bg/fg/accent/urgent/terminal 16 色/
bar 颜色/wallpaper 文件名等。**不要手改 `~/.config/noctalia/*` 来「修主题」**——下次切主题就被覆盖。

## 链路（Noctalia v5）

```
themes/<slug>/tokens.json
   │  theme_env_load（exporters/lib.sh，展开成 T_* 环境变量）
   ▼
exporters/niri/theme.sh  (noctalia_theme_apply)
   ├─ 写  ~/.config/noctalia/theme.toml
   │        [theme] mode / source="wallpaper" / wallpaper_scheme="m3-tonal-spot"
   │        [wallpaper] enabled=true
   ├─ 写  ~/.config/kitty/theme.inc.conf（16 色 ANSI，来自 tokens.terminal）
   │        + kitty @ set-colors -a 热加载（仅 KITTY_LISTEN_ON 存在时尝试）
   ├─ 写  ~/.config/fuzzel/fuzzel.ini（整份重写，[colors] 来自 tokens）
   └─ IPC noctalia msg wallpaper-set <绝对路径>
          + color-scheme-set wallpaper m3-tonal-spot
          + theme-mode-set dark|light
```

v5 外壳配色**由壁纸派生**（Material You），所以「切主题 = 换壁纸 + 换 mode」。
终端/启动器仍严格用 tokens 的 16 色，二者同源于同一次切换。

## 入口

| 命令 | 用途 |
|---|---|
| `theme-next` | 切到下一套（索引存 `~/.local/state/theme-next/idx`） |
| `theme-next restore` | 应用已保存的索引（登录/手动恢复） |
| `theme-next <idx>` | 指定第 idx 套（`theme-picker` 用） |
| `theme-next --print-themes` | 输出主题清单（选择器数据源） |
| `theme-picker` | 交互式选择（`Mod+Shift+T`） |
| `de-theme-apply <slug>` | 按 slug 应用（能力层 `de_theme_apply`） |

## 壁纸

- 文件：`~/Pictures/wallpapers/<tokens.wallpaper>`（`install.sh` 从仓库 `wallpapers/` 拷入）
- 由 **Noctalia 壁纸服务**显示；`de_wallpaper_set` 走 `noctalia msg wallpaper-set`
- `wallpaper-next` 换下一张壁纸，外壳配色随之重算

## 新增一套主题

1. 造壁纸放进 `wallpapers/`
2. 复制任一 `themes/<slug>/tokens.json`，改配色与 `wallpaper` 字段
3. `./install.sh --host <host> --yes`（部署 tokens + 拷壁纸）
4. `de-theme-apply <slug>` 验证
5. `theme-next --print-themes` 应能看到新主题（`theme-picker` 自动收录）

## 已知坑

1. **v5 的 state 覆盖 config**：GUI 改过的值写在 `~/.local/state/noctalia/settings.toml`，
   优先级**高于** `~/.config/noctalia/*.toml`。所以 exporter 除了写 theme.toml，
   还要走 `msg color-scheme-set / theme-mode-set` 把 state 一起对齐。
2. **必须传壁纸绝对路径**：壁纸目录在启动时会被重置为默认值，靠目录扫描会失败。
3. **自定义调色板（`source="custom"`）暂不可用**：`~/.config/noctalia/palettes/<name>.json`
   在 5.0.1 上没有跑通（16 色 m*、完整 token 表、社区数组格式都被判 invalid），
   当前统一走 `source="wallpaper"`。等上游文档明确格式再切，别凭猜写死。
4. **v4 的 `colorschemes/*.json` + `settings.json` 已作废**，留在目录里也不会被 v5 读取。

## 排查

```bash
cat ~/.config/noctalia/theme.toml
noctalia msg color-scheme-get    # 当前 source + scheme
noctalia msg theme-mode-get      # dark / light
noctalia msg wallpaper-get       # 当前壁纸绝对路径
tail -f ~/.cache/noctalia/noctalia.log
theme-next --print-themes
```
