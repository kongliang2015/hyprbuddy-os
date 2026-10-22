# theming：theme-next 与壁纸

## 主题切换

    theme-next            # 切到下一套（默认动作，循环切换）
    theme-next restore    # 应用已保存主题（登录时 exec-once 调用，不前进索引）
    theme-next <idx>      # 应用指定主题（theme-picker 使用）

内置主题（顺序即索引）：Kanagawa / Tokyo Night / Catppuccin Mocha / Rose Pine / Nord /
WorkBuddy / WorkBuddy Dark。WorkBuddy 两套取自 workbuddy.cn 官网设计令牌（薄荷绿
#00C29A、白面 #FFF、文字 #1A1A1A、暗部 #0A0A0A + #28B894→#3B82F6 渐变），浅色那套会让
`agent-theme-sync` 收到 light——脚本按 waybar 背景色亮度自动判定，无独立字段。

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

## 主题预览（theme-picker）

Omarchy 风格的预览选择器：kitty 内 fzf 浏览主题列表，右侧用 `kitten icat` 实时渲染
该主题的壁纸，Enter 应用整套主题，Esc 取消。

- 入口：Super+Space → 外观 → 主题预览（浮动 kitty 窗口，class=theme-picker）
- 数据源：`theme-next --print-themes`（idx/名称/壁纸单一事实源）
- 选择后按索引应用：`theme-next <idx>`（写状态并应用全套）
- 依赖：fzf（modules/base.nix）与 kitten（kitty 包自带）；须在 kitty 内运行

## 壁纸

- 守护进程：`awww-daemon`（nixpkgs 26.05 将 swww 更名为 awww）
- 启动：`exec-once = bash -c 'sleep 1; awww-daemon || swww-daemon'`（等显示器就绪）
- 切换：`wallpaper-next` 循环 `~/Pictures/wallpapers`（install.sh 会把仓库 `wallpapers/` 复制过去）
- 壁纸必须是真实图片：换壁纸后无视觉变化时先确认文件不是单色/低色数

## 联动验证

主题切换后应同时变化：waybar、fuzzel、mako、swayosd、壁纸、hyprland 兜底边框。
验证：`grep -m1 color ~/.config/waybar/style.css` 与 mako 颜色键是否同步更新。

## SDDM 登录界面主题

    sddm-theme list        # 已安装主题（id / 显示名 / 路径，当前项带 ✓）
    sddm-theme current     # 当前生效主题
    sddm-theme set <id>    # 切换（polkit 原生密码框；代理不可用时回退 sudo+kitty）
    sddm-theme reset       # 删除 override，回到声明式默认
    sddm-theme --json      # 机器可读（菜单/脚本消费）

- 入口：Super+Space → 外观 → 登录界面主题，当前项带 ✓，末项可恢复默认
- 原理：`/etc/sddm.conf.d/00-nixos.conf` 由 NixOS 托管，重建会重写 `Current=`；
  切换写的是 `/etc/sddm.conf.d/50-sddm-theme.conf`，conf.d 按字典序后者覆盖前者，
  所以 `nixos-rebuild switch` 不会冲掉运行时的选择
- 生效时机：SDDM 只在 greeter 启动时读配置 —— **注销/重启后**才看得到，无需重启 sddm
- 主题来源：`ThemeDir` 下含 `Main.qml` 的目录 + `Current` 指向的目录外绝对路径（catppuccin）
- 换 catppuccin 的 flavor/accent 不在这里：那是构建期参数（`modules/desktop/hyprland.nix:5`），
  需要 `nixos-rebuild`；本命令只切换"已安装主题"
- 提权：优先 pkexec + hyprpolkitagent（无终端窗口），SDDM_THEME_SUDO_MODE=kitty 可强制回退
- 安全：id 只接受枚举白名单内的值；写入失败或取消时原配置不动；
  `hypr-check` 会校验 override 指向的主题存在，避免登录页黑屏

## polkit 认证框（hyprpolkitagent）

- polkitd 是 freedesktop 的系统授权服务，本身没有 UI；有界面的是认证代理 hyprpolkitagent
- 实现由 `distro.polkitAgent`（modules/options.nix）选择：
  - `qt`（默认）= stable 的 0.1.3，Qt6 + hyprland-qt-support，颜色来自 QQuickSystemPalette → Adwaita，**无法跟随主题**
  - `hyprtoolkit` = 0.2.0（来自 flake 的 `nixpkgs-unstable` 输入），认证框由 hyprtoolkit 渲染，
    颜色读 `~/.config/hypr/hyprtoolkit.conf`
- theme-next 每次切换都会重写该文件（background / base / alternate_base / text / bright_text /
  accent / accent_secondary / rounding_large / rounding_small / font_*），颜色格式 `rgba(rrggbbaa)`；
  agent 在每次弹窗前重读，**切主题不需要重启代理**
- 回滚：`distro.polkitAgent = "qt"` 后 `sudo nixos-rebuild switch`
- 前提：flake 里要有 `nixpkgs-unstable` 输入（清华镜像 nixexprs），只为这一个包服务；
  升级 `nix flake update` 后要回归一次认证框
