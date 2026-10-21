# theming：theme-next 与壁纸

## 主题切换

    theme-next            # 切到下一套（默认动作，5 套循环）
    theme-next restore    # 应用已保存主题（登录时 exec-once 调用，不前进索引）

## theme-next 改写的文件

| 目标 | 方式 |
|---|---|
| `~/.config/waybar/style.css` | 整份重写（先删 store 软链，再写真实文件） |
| `~/.config/fuzzel/fuzzel.ini` | awk 拼接 `[colors]` 段；写 tmp 后非空才替换 |
| `~/.config/mako/config` | 替换颜色键 + urgency 段；随后 `makoctl reload` |
| `~/.config/swayosd/style.css` | 替换 5 个颜色键；flock 串行重启 swayosd-server |
| 壁纸 | 按主题设置 awww 壁纸 |

要点：
- waybar 重启用 flock 串行化（防止 exec-once 与自动重载并发重复 spawn）；子进程需 `200>&-` 关闭 fd
- waybar 是整份重写，新增样式无需改脚本；mako / fuzzel / swayosd 是**按键替换**，新增颜色键必须同步

## 壁纸

- 守护进程：`awww-daemon`（nixpkgs 26.05 将 swww 更名为 awww）
- 启动：`exec-once = bash -c 'sleep 1; awww-daemon || swww-daemon'`（等显示器就绪）
- 切换：`wallpaper-next` 循环 `~/Pictures/wallpapers`（install.sh 会把仓库 `wallpapers/` 复制过去）
- 壁纸必须是真实图片：换壁纸后无视觉变化时先确认文件不是单色/低色数

## 联动验证

主题切换后应同时变化：waybar、fuzzel、mako、swayosd、壁纸、hyprland 兜底边框。
验证：`grep -m1 color ~/.config/waybar/style.css` 与 mako 颜色键是否同步更新。
