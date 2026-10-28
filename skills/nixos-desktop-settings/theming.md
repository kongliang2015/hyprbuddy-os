# theming：tokens → Noctalia 配色 + 壁纸

## 唯一真相

`themes/<slug>/tokens.json`：每套主题一个文件，含 bg/fg/accent/urgent/terminal 16 色/
bar 颜色/wallpaper 文件名等。**不要手改 `~/.config/noctalia/*` 来「修主题」**——下次切主题就被覆盖。

## 链路

```
themes/<slug>/tokens.json
   │  theme_env_load（exporters/lib.sh，展开成 T_* 环境变量）
   ▼
exporters/niri/theme.sh  (noctalia_theme_apply)
   ├─ 写  ~/.config/noctalia/colorschemes/<slug>/<slug>.json   ← Material 键，dark/light 两份
   ├─ 改  ~/.config/noctalia/settings.json（jq 合并）
   │        colorSchemes.useWallpaperColors = false
   │        colorSchemes.predefinedScheme   = <slug>
   │        colorSchemes.darkMode           = tokens.dark
   ├─ IPC noctalia-shell ipc call colorScheme set <slug>
   └─ IPC noctalia-shell ipc call wallpaper set <绝对路径> all
```

入口：

| 命令 | 用途 |
|---|---|
| `theme-next` | 切到下一套（索引存 `~/.local/state/theme-next/idx`） |
| `theme-next restore` | 应用已保存的索引（登录/手动恢复） |
| `theme-next <idx>` | 指定第 idx 套（`theme-picker` 用） |
| `theme-next --print-themes` | 输出主题清单（选择器数据源） |
| `theme-picker` | 交互式选择（`Mod+Shift+T`） |
| `de-theme-apply <slug>` | 按 slug 应用（能力层 `de_theme_apply`，niri 分支同上） |

## 壁纸

- 文件：`~/Pictures/wallpapers/<tokens.wallpaper>`（`install.sh` 从仓库 `wallpapers/` 拷入）
- 由 **Noctalia 壁纸服务**显示（awww 已移除）；`de_wallpaper_set` 走 `wallpaper set`
- `wallpaper-next` 换下一张壁纸，也走同一能力层

## 新增一套主题

1. 造壁纸放进 `wallpapers/`
2. 复制任一 `themes/<slug>/tokens.json`，改配色与 `wallpaper` 字段
3. `./install.sh --host <host> --yes`（部署 tokens + 拷壁纸）
4. `de-theme-apply <slug>` 验证
5. `theme-next --print-themes` 应能看到新主题（`theme-picker` 自动收录）

## 已知坑（都是实测踩过的）

1. **`predefinedScheme` 必须同步写**：若 settings.json 里它为空或指向别的方案，
   Noctalia 启动时会用预设方案覆盖 `colorscheme` 里的配色 → 看起来「切了没反应」
2. **必须传壁纸绝对路径**：`settings.wallpaper.directory` 会被 Noctalia 启动时重置，
   依赖目录扫描会失败（日志里 `Wallpaper Scan failed … (directory might not exist)`）
3. **新方案首次 IPC 会失败**：运行中的 shell 只认启动时扫描到的方案列表。
   exporter 用 `colors.json` 的 mtime 做探测，1.5s 未更新就重启 shell 兜底
4. **别直接调 `noctalia-shell ipc call colorScheme set` 指望它读 tokens**：
   它只切换已存在的方案文件

## 排查

```bash
ls ~/.config/noctalia/colorschemes/            # 已生成的方案
grep -E "predefinedScheme|useWallpaperColors" ~/.config/noctalia/settings.json
noctalia-shell ipc call colorScheme get        # 当前生效的 source + name
noctalia-shell ipc call wallpaper get all      # 当前壁纸绝对路径
theme-next --print-themes                      # 主题清单与当前标记
```
