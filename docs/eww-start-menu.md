# 决策记录：放弃 eww 自建开始菜单

日期：2026-10-27　状态：**放弃**（代码已删除，仅保留本记录）

## 背景

COSMIC 没有 Windows "开始菜单"/Cinnamon "应用菜单"那种点击弹出分类菜单的入口，
只有 Launcher（搜索优先弹窗）和 App Library（Super+A 全屏网格）。
尝试用仓库已有的 eww（GTK + layer-shell）自建一个"点图标弹应用网格"的菜单。

## 验证到什么程度

| 项 | 结果 |
|---|---|
| eww layer 窗口在 COSMIC 下渲染 | ✅ 成立（测试窗口开关前后截图 RMSE 11.6%） |
| 应用清单解析（.desktop） | ✅ 25 个应用，name/exec/icon 可用 |
| 静态网格 yuck 生成 | ✅ 生成成功，语法合法 |
| 带样式的菜单窗口 | ❌ 窗口能开（list-windows 可见），但 `.menu` 背景/边框未渲染 |

踩到的 eww 0.6 约束：

1. 配置目录只能用 `-c/--config`，`EWW_CONFIG_DIR` 环境变量无效
2. 主题图标必须用 `(image :icon "name")`，`:path` 只接受文件路径
3. `:icon-size` 只接受符号值（menu/small-toolbar/toolbar/large-toolbar/button/dnd/dialog），不接受像素

## 为什么放弃

1. **收益/成本失衡**：剩下的是纯样式调试（几何、CSS 链路），预计还要 2–3 轮迭代，
   最终产物也只是"形式上的开始菜单"——搜索、分类、最近使用都做不了（eww 列表能力有限）。
2. **已有可用替代**：`Super` 单按 / `Super+/` 打开 COSMIC 启动器（搜索 + 应用列表），
   `Super+A` 打开应用库网格。功能上覆盖"找应用并启动"。
3. **维护负担**：自建菜单要跟随主题 token、跟随 .desktop 变化、维护 eww 版本兼容，
   属于长期成本，而 COSMIC 每次升级都可能自带更好的启动器。

## 后续方向

- 短期：把 COSMIC 启动器入口做得更显眼（面板按钮位置/尺寸），并在快捷键文档里写清
  `Super` / `Super+/` / `Super+A` 三个入口
- 若将来确实需要分类菜单：优先等 COSMIC 上游（launcher 的分类能力），而不是自建
