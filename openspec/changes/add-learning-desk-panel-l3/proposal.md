## Why

[`add-learning-desk-panel`](../add-learning-desk-panel/) v1 交付 Today 只读 + complete/move，满足「一眼看清今天 + 基本快操」。用户仍可能需要 **增删单任务、周负荷感知、飞书改计划后自动刷新、复习通过/失败**——这些增强 v1 刻意延后，以免与 Dashboard 首版并行改动过大。

本 change 在 v1 面板之上叠加 **L3 能力**，仍遵守 P10：所有写操作只调 `schedule.py`。

**前置**：`add-learning-desk-panel` v1 已归档或 M-L2 已上线。

总目录：[ROADMAP.md](../../../docs/integrations/ROADMAP.md) Phase 6b · 母本：[learning-desk-panel.md](../../../docs/integrations/features/learning-desk-panel.md)

## What Changes

### MalDaze

- `insert` / `remove` 轻量 UI（确认删）。
- **Week** Tab：未来 14–28 天每日已排分钟（条形/热力，超 cap 标红）。
- `projects.json` **FSEvents** debounce 自动刷新 Today。
- 复习行 **passed/failed** → `review` 子命令。

### Hermes

- **H-L3**：`today` 的 `pending[]` 含 `auto_roll_days`（简化面板，可选替代 Swift 合并）。
- **H-L4**：`week-load --from <date> --days 28` JSON（Week Tab 单一算法入口）。

## Capabilities

### New Capabilities

- （无全新 capability id；扩展 `learning-desk-panel`）

### Modified Capabilities

- `learning-desk-panel`: ADDED — insert/remove、week load view、FSEvents refresh、review actions。
- `hermes-learning-calendar`: ADDED — `week-load` CLI；`pending` 含 `auto_roll_days`（可选）。

## Impact

- **MalDaze**：`LearningDeskPanel/` 扩展 Tab、表单、FileWatcher。
- **Hermes**：`schedule.py` 小扩展；单测。
- **不改动**：SSOT 模型、Swift 级联、plan/对话。

## Affected Specs

- `learning-desk-panel`（delta ADDED）
- `hermes-learning-calendar`（delta ADDED）
