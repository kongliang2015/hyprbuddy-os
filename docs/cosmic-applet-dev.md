> **已退役（2026-10-28，v1-nn 分支）**：COSMIC 桌面已从本分支移除，
> 第三桌面提供方改为 niri + Noctalia（见 `docs/niri-noctalia-plan.md`）。
> 本文保留为历史调研记录。

# COSMIC Applet 开发调研

结论：**可行，官方有现成模板与 hook**。成本不在"写"，而在"首次编译 + 长期跟进 API"。

## 一、官方资源

| 资源 | 地址 | 用途 |
|---|---|---|
| 模板仓库 | `github.com/pop-os/cosmic-applet-template` | 脚手架，`cargo generate` 直接生成 |
| 示例 | `libcosmic/examples/applet` | 最小可运行 applet |
| API 文档 | `pop-os.github.io/libcosmic/cosmic/` | trait 与 widget |
| 手册 | `pop-os.github.io/libcosmic-book/` | 教程 |
| 商标政策 | `cosmic-epoch/TRADEMARK.md` | **命名不能用 Cosmic 前缀** |

生成方式：

```bash
cargo generate gh:pop-os/cosmic-applet-template
```

模板自带 `justfile`：`just build-release` / `just run` / `just install` / `just check` / `just vendor`。

## 二、最小工程结构

```
my-applet/
  Cargo.toml
  justfile
  src/
    main.rs      # 入口：cosmic::applet::run::<AppModel>(())
    app.rs       # Application trait 实现（状态 / 视图 / 消息）
    config.rs    # cosmic-config 持久化（可选）
    i18n.rs      # 本地化（可选）
  resources/
    <appid>.desktop
    <appid>-symbolic.svg
```

`main.rs` 全文就这么长：

```rust
fn main() -> cosmic::iced::Result {
    let requested_languages = i18n_embed::DesktopLanguageRequester::requested_languages();
    i18n::init(&requested_languages);
    cosmic::applet::run::<app::AppModel>(())
}
```

`app.rs` 的核心是 `cosmic::Application`：

```rust
pub struct AppModel {
    core: cosmic::Core,
    popup: Option<Id>,        // 面板按钮弹出的 Popup 窗口
    config: Config,
}

pub enum Message { TogglePopup, PopupClosed(Id), ... }

impl cosmic::Application for AppModel {
    type Executor = cosmic::executor::Default;
    type Flags = ();
    type Message = Message;
    const APP_ID: &'static str = "com.example.MyApplet";   // RDNN 格式

    fn init(core, _flags) -> (Self, Task<...>) { ... }
    fn view(&self) -> Element<Message> { ... }              // 面板上显示的图标/文字
    fn view_window(&self, id: Id) -> Element<Message> { ... } // 弹出的面板内容
    fn update(&mut self, msg) -> Task<...> { ... }
}
```

弹出窗用 `iced::platform_specific::shell::wayland::commands::popup::{get_popup, destroy_popup}`。

## 三、面板如何发现 applet（关键机制，实测）

面板扫描 `share/applications/*.desktop`，认这几个字段（以官方 `com.system76.CosmicAppletTime.desktop` 为例）：

```ini
[Desktop Entry]
Name=Date, Time & Calendar
Exec=cosmic-applet-time
Categories=COSMIC;
Icon=com.system76.CosmicAppletTime-symbolic
X-CosmicApplet=true            # ← 关键：标记为 applet
X-CosmicShrinkable=true        # 面板空间不足时可收缩
X-HostWaylandDisplay=true
X-CosmicHoverPopup=Auto        # 悬停弹窗行为
```

**插件 id = desktop 文件名**（`com.system76.CosmicAppletTime`），
所以只要把 `.desktop` 装进 `share/applications/`，就可以直接写进面板：

```ron
plugins_center = Some([ "com.example.MyApplet" ])
```

我们的 `uxctl` 白名单是从 `share/applications` 里扫描 `com.system76.Cosmic*` 生成的，
自定义 applet 用 `com.example.*` 命名时**不在白名单内**，需要扩展扫描规则（见第六节）。

## 四、Nix 打包配方

nixpkgs 里 `cosmic-applets` 用的是：

```nix
rustPlatform.buildRustPackage {
  pname = "cosmic-applets";
  src = fetchFromGitHub { owner = "pop-os"; repo = "cosmic-applets"; tag = "epoch-1.2.0"; ... };
  cargoHash = "...";
  nativeBuildInputs = [ libcosmicAppHook just pkg-config ... ];
  buildInputs = [ dbus glib libinput pulseaudio pipewire udev xkeyboard_config ... ];
}
```

关键点是 **`libcosmicAppHook`**：它提供 `just install` 需要的环境（安装 .desktop/图标到正确位置），
少了它 applet 会在面板里"不可见"。

我们自己的 applet 打包骨架：

```nix
{ lib, rustPlatform, libcosmicAppHook, just, pkg-config, ... }:
rustPlatform.buildRustPackage {
  pname = "cosmic-applet-hello";
  version = "0.1.0";
  src = ./.;
  cargoHash = lib.fakeHash;          # 首次构建后填真实 hash
  nativeBuildInputs = [ libcosmicAppHook just pkg-config ];
}
```

接入系统：

```nix
# modules/desktop/cosmic.nix
environment.systemPackages = [ (pkgs.callPackage ../../pkgs/cosmic-applet-hello { }) ];
```

## 五、接到我们的工具链

1. 装包后 `.desktop` 出现在 `share/applications/`，面板"加组件"列表里能看到
2. 用 `uxctl` 注册到面板：

```json
{ "version": 1,
  "panel": { "plugins_wings": { "left": ["com.example.MyApplet"], "right": [...] } } }
```

3. `uxctl` 的 applet 白名单需要放行：把 `known_applets()` 的扫描从
   `com.system76.Cosmic*` 扩展到"所有带 `X-CosmicApplet=true` 的 .desktop"

## 六、成本与风险

| 项 | 说明 |
|---|---|
| 首次编译 | libcosmic 依赖树很大，**10–20 分钟**（之后增量） |
| API 稳定性 | COSMIC 1.x 迭代快，`Application` trait 与 popup API 有变动风险 |
| 学习曲线 | 需要 Rust + iced 的立即模式 UI 思维（不是 CSS 那套） |
| 调试 | 靠 `RUST_LOG` + 日志，面板里看不到报错细节 |
| 商标 | 命名不能以 Cosmic 开头（官方政策），建议 `com.example.*` 或自建域名 |
| 打包 | 需要 `libcosmicAppHook` + 正确的 `cargoHash`，首次构建要试几轮 |

## 七、候选 applet（按难度）

| 难度 | 想法 | 说明 |
|---|---|---|
| ★ | **状态文字** | 面板显示负载/NixOS 代数/网络状态，点击弹小窗 |
| ★ | **快捷动作按钮** | 点一下执行命令（截图/锁屏/切主题），复用现有脚本 |
| ★★ | **系统监控** | 弹窗里画 CPU/内存曲线（libcosmic 有图表 widget） |
| ★★★ | **开始菜单按钮** | 点开应用网格 + 搜索（补齐 COSMIC 缺失的"菜单"形态） |

## 八、建议的第一步：最小验证

先做一个"Hello applet"只验证四件事，不做业务逻辑：

1. `just build-release` 能编译（验证工具链）
2. `.desktop` 装进 `share/applications/` 后，面板组件列表能看到
3. 加到面板后能显示图标/文字
4. 点击能弹出 popup 窗口

四件事都通，再谈做哪个功能。预计首次跑通 **2–3 小时**（主要是编译等待与 hash 调试）。

## 九、结论

- **技术上没有障碍**：模板 + hook + Nix 打包路径都清晰
- **真正的成本在维护**：每次 COSMIC 升级要跟着改 API，且 applet 质量直接暴露在面板上
- 如果你只是想要"某个按钮能执行命令"，**用现有脚本 + 面板 LauncherButton 更划算**
- 真正值得自研 applet 的场景：需要**面板常驻显示状态**（如负载/温度/NixOS 代数），
  或需要**弹出面板做交互**（如自定义监控/菜单）
