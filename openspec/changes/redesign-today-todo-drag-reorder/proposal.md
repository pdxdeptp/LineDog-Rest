## Why

今日 todo 虽已支持通过左侧 **≡** 手柄拖动排序，但额外控件挤占行宽、视觉像工具栏而非随手记；且当前 `onDrag`/`DropDelegate` 在 `dropEntered` 时瞬时换位，缺少跟手与让位动画，手感生硬。需要在不破坏现有 inline 编辑、compact/pinned 布局与 `sortIndex` 持久化的前提下，改为 **拖文字本体 + 全程 spring 动画** 的排序体验。

## What Changes

- **移除 ≡ 手柄**：未完成条目恢复 `checkbox · 文字 · 删除` 三列布局，无额外排序控件。
- **长按文字抓起排序**：在标题/顺延 hint 文字区长按（默认 350ms）进入排序；快速单击仍进入 inline 编辑。
- **连续动画 reorder**：拖动中被拖行跟手、邻行 spring 让位、松手 spring 落定；取消（Esc / 拖出列表）回弹原位。
- **保留数据契约**：仍写入 `today-todo.json` 的 `sortIndex`；复用/扩展 `TodayTodoStore.moveIncomplete`，删除 `TodayTodoReorderDropDelegate` 与 AppKit 拖放路径。
- **与 pinned 布局共存**：排序在 `TodayTodoContentLayout` 内进行；pinned 时靠近 viewport 边缘自动 scroll；不触发 layout mode 动画或 draft focus token。
- **手势边界**：编辑中不排序；仅 1 条未完成时不启用；checkbox/删除仍独立点击。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `learning-today-todo`: 为未完成条目增加「长按文字、动画拖动排序」的产品与交互要求；明确与 inline 编辑、pinned 滚动锚定的边界。

## Impact

- **MalDaze**：新增 `TodayTodoReorderController`（或等价状态机）与行 frame Preference；重构 `TodayTodoSection`/`TodayTodoRow`/`TodayTodoInlineText` 手势分工；删除 `TodayTodoReorderDropDelegate.swift`。
- **测试**：Store reorder 单测保留；新增 presentation/手势/动画 smoke 与 pinned 下 auto-scroll 回归。
- **文档**：更新 `docs/integrations/features/learning-desk-panel.md` §4.4 排序交互说明。
- **Hermes / JSON schema**：无版本变更；`sortIndex` 语义不变。

## Affected Specs

- `learning-today-todo`（delta；主 spec 待 `add-learning-today-todo` 归档后合并）
