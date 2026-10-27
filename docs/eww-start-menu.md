# eww 开始菜单：可行性验证（进行中）

目标：在 COSMIC 下用 eww（GTK + layer-shell）做一个"点图标弹出应用网格"的开始菜单。

## 已确认

| 项 | 结果 |
|---|---|
| eww 版本 | 0.6.0，已装 |
| layer-shell 在 COSMIC 下可用 | ✅ 测试窗口能渲染（前后截图 RMSE 11.6%） |
| 应用清单解析 | ✅ `scripts/start-menu-apps` 解析 .desktop，输出 25 个应用（name/exec/icon） |
| 网格生成 | ✅ `scripts/start-menu-gen` 生成静态 yuck（每行 6 个，主题图标） |

## 当前阻塞

窗口能打开（`eww list-windows` 可见 `start-menu`），但**样式未生效**：
菜单区域亮度 98，与背景 91 几乎相同，说明 `.menu` 的背景/边框没有被应用。

已排除的原因：
- `:icon-size 28` 是非法值（eww 只接受 menu/small-toolbar/toolbar/large-toolbar/button/dnd/dialog）
  → 已改为 `"large-toolbar"`，重载后错误归零
- `:path` 用于文件路径，主题图标必须用 `:icon`（已改）
- eww 配置文件必须用 `-c/--config` 指定，`EWW_CONFIG_DIR` 无效

未排除：
- `.menu` 的 CSS 是否因为 eww 的 scss 编译顺序未应用
- 窗口 anchor（bottom left + y=140px）计算是否导致窗口跑到屏幕外

## 下一步

1. 用 `eww debug` / `eww state` 确认窗口几何
2. 给窗口加 `:wm-ignore true` 之外的最小样式（纯色块）验证 CSS 链路
3. 样式通了之后接 `scripts/start-menu` 切换脚本 + 快捷键（COSMIC Shortcuts RON）
4. 与主题 token 联动（背景/描边跟随 `themes/*/tokens.json`）
