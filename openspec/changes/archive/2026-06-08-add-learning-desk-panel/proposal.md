## Why

飞书 Hermes 已是学习任务的执行引擎（`schedule.py` + `projects.json`），但缺少 **Mac 前一屏纵览**：用户无法一眼看到今天要做什么、还剩几条、是否超预算。需要在桌宠 Dashboard **中栏**恢复轻量可视化，并通过 CLI 完成勾选、推迟、改日期等快操，而不重建已移除的嵌入版 SQLite/FastAPI 学习系统。

总目录：[docs/integrations/ROADMAP.md](../../../docs/integrations/ROADMAP.md) Phase 6a · 设计：[docs/integrations/features/learning-desk-panel.md](../../../docs/integrations/features/learning-desk-panel.md)

## v1 交付边界（scope-decision A）

| 本 change（v1） | 延后（已单独写文档） |
|-----------------|----------------------|
| L1 Today 只读 + 三栏 | L3 增删 / Week / FSEvents / review → [`add-learning-desk-panel-l3`](../add-learning-desk-panel-l3/) |
| L2 complete + move（含预览） | H-L1 rollover 日历 → [`fix-learning-rollover-calendar`](../fix-learning-rollover-calendar/) |
| H-L2 `move --dry-run` | H-L3 `pending[]` auto_roll_days、H-L4 week-load → `add-learning-desk-panel-l3` |

**v1 验收**：MANUAL_QA §域 C 面板 M-L-1～6（不含增删/Week/FSEvents/review）。

## What Changes

### MalDaze · 学习桌宠面板 v1

- 恢复 Dashboard **三栏**布局，中栏 `LearningDeskPanelView`。
- 读：`schedule.py rollover` + `today`（`HERMES_HOME=~/.hermes`）。
- 写：`complete`、`move`（经 `--dry-run` 预览后 apply）；**不在 Swift 复刻**级联。

### Hermes · v1 必需

- `move --dry-run`（H-L2）：L2 级联预览；spec `hermes-learning-calendar` SHALL。

### 文档

- 延后工作见 `add-learning-desk-panel-l3`、`fix-learning-rollover-calendar`。

## Capabilities

### New Capabilities

- `learning-desk-panel`: MalDaze 中栏今日视图、预算/警告、complete/move 快操。

### Modified Capabilities

- `desk-pet-controls`: 中栏承载学习面板；三栏最小宽度。
- `hermes-learning-calendar`: MalDaze CLI complete；`move --dry-run`。

## Impact

- **MalDaze**：`MalDaze/LearningDeskPanel/`；`DashboardRootView` 三栏。
- **Hermes**：`schedule.py move --dry-run` only（v1）。
- **不改动**：L3 功能、rollover 日历 patch、域 A/B、Smart Input、SQLite 嵌入。

## Affected Specs

- `learning-desk-panel`（新建）
- `desk-pet-controls`（中栏）
- `hermes-learning-calendar`（complete + dry-run）
