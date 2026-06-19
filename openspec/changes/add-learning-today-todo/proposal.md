## Why

学习面板「今日」Tab 已承载 Hermes 排期任务，但用户仍有大量**非学习、非提醒**的当日杂项（回邮件、买物、临时备忘）——目前只能切到备忘录手敲，与桌宠 Dashboard 工作流割裂。本 change 在学习栏今日视图内增加 **MalDaze 本地「今日 todo」**，快记、快勾、可查历史，且**不与左栏计划（EventKit）或 Hermes 学习任务混源**。

## What Changes

### MalDaze

- 学习面板 **今日 Tab**：Hermes 任务列表与「明天预告」之间新增 **「今日 todo」** 区块。
- **MalDaze 本地 JSON**（`Application Support/MalDaze/today-todo.json`）为 SSOT；增删改查、完成态、历史均只读写此文件。
- **未完成顺延**：打开面板 / 切到今日 Tab / 跨日时，未完成且归属日早于今天的条目自动滚到今日（可选展示「自 xx 顺延」）。
- **历史可查**：区块标题行 **「历史」** 打开 Sheet，按日期倒序展示过去日期的**已完成**条目；未完成项不在历史中（已顺延到今天）。
- **已完成**：保留在今日主视图，删除线样式，默认折叠在「已完成 N」区；可取消勾选回到未完成。
- **输入**：区块底部常驻单行输入框，**随 ScrollView 滚动**；回车添加，无 Sheet。
- 学习面板刷新（↻）**不**重载今日 todo；Hermes 报错 / 休息日时今日 todo 仍可用。
- 现有 Hermes **`+` insert** 与左栏 **计划** 行为不变。

### Hermes / EventKit

- **无变更**。不新增 CLI、不写 `projects.json`、不同步提醒事项。

### 文档

- `docs/integrations/features/learning-desk-panel.md` 增补今日 todo 章节
- `docs/integrations/MANUAL_QA.md` 域 C 增补 M-L-today-todo 验收项

## Capabilities

### New Capabilities

- `learning-today-todo`: MalDaze 本地今日 todo 存储、顺延、历史、学习面板 UI 与交互。

### Modified Capabilities

- `learning-desk-panel`: MODIFIED — 今日 Tab 在 Hermes 任务列表下方展示「今日 todo」区块，且该区块不影响学习预算与 Hermes CLI 刷新语义。

## Impact

- **MalDaze**：`LearningDeskPanel/` 新增 `TodayTodoStore`、Section、HistorySheet、Row；`LearningDeskPanelView` 嵌入；单元测试。
- **Hermes**：无。
- **EventKit / 左栏计划**：无。
- **非目标**：与提醒事项 / Hermes insert 互转；拖拽排序；提醒时间；跨设备同步；计入正课/复习预算；设置页配置项（第一版）。
- **依赖**：无；可与其它 learning-desk-panel change 并行 apply，仅 touch 中栏今日布局。

## Affected Specs

- `learning-today-todo`（新建）
- `learning-desk-panel`（修改 delta）
