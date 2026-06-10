## Why

> Superseded alignment: `use-hermes-authored-nutrition-recommendations` revises the recommendation source. `daily_log.json` / `panel` remains the facts and metrics contract, but user-visible "现在可以吃" recommendations now come only from `~/.hermes/data/nutrition/recommendation.json`. First-version compatibility keeps `daily_log.panel.suggestions: []`; MalDaze must ignore it as a recommendation source.

Hermes 营养域（`nutrition-menu` skill + `recommend.py` + `plan_engine.py`）已在飞书对话中实现「记录吃了什么 → 算剩余 → 推荐下一顿」，但桌宠 Dashboard **没有视图**；用户每次要看进度、确认吃了什么必须回飞书。ROADMAP **X2「营养菜单 Dashboard」** 长期 ⏸。

本 change 将营养「今日面板」落到 MalDaze 左栏（Hermes 写 `daily_log.panel` facts/metrics · MalDaze 读 + 轻交互 · FSEvents）。原方案只在 `daily_log.json` 内增 `panel` 派生块；当前 active 版本已由 `use-hermes-authored-nutrition-recommendations` 修正为 `daily_log.json` facts/metrics + `recommendation.json` Hermes-authored recommendation 双契约。

依据：`docs/nutrition_menu_system_requirement_handoff.md` · `docs/integrations/ROADMAP.md` X2 · explore 定稿（方案 A）· scope 用户追加（2026-06-09）

## What Changes

### Hermes `~/.hermes/data/nutrition/`

- `daily_log.json` 增顶层 **`panel`** 块（`schemaVersion: 1`）：`dayLabel`、`targets` / `consumed` / `remaining`（含 **`sodium_mg`**）、`suggestions[]`（第一版固定为空数组，仅 schema 兼容）、`calorieSlack: 50`、`updatedAt`。
- `recommend.py`：所有 mutating 子命令在 `_update_daily_log` 同一原子写内调用 **`_refresh_panel()`**。
- 新增子命令 **`refresh-panel`**：仅重算并写入 `panel`（晨报/调试；mutating 仍自动刷新）。
- v1 Python `plan_engine` 基线 `suggestions` 已被 `recommendation.json` supersede；`recommend.py` 不再向 MalDaze 发布用户可见建议。
- `history/` 归档不含 `panel`。
- `morning-briefing.py` 饮食段后刷新 `panel`。
- **`integration_smoke`**：断言 `daily_log.panel.schemaVersion == 1`（**必做，S3**）。
- `nutrition-menu` skill：禁止手改 `daily_log.json`；记录用 `recommend.py` 子命令。

### MalDaze

- Dashboard **左栏上下分栏**：上「计划」、下「饮食」；默认 **60% / 40%**，**设置可调比例**（S6）。
- 新模块 `NutritionToday/`：`daily_log.json` facts decode、`recommendation.json` 推荐 decode、FSEvents、**钠展示**、**fresh 推荐中 loggable 食物可点即记**（调 `recommend.py log`，不写 JSON）。
- **轻交互**：fresh `recommendation.json` 的 `loggable: true` 建议 `items[]` **点击或按 1–9** → `log`；stale/missing/unavailable/invalid 时禁用；**无** undo / 试算 / 改日型 / 手改文件。
- 健身不单独视图，仅 `dayLabel` 一行。

### 用户追加纳入（相对初版展示-only scope）

| ID | 内容 |
|----|------|
| **S3** | `integration_smoke` 断言 `panel.schemaVersion == 1` |
| **S4** | `recommend.py refresh-panel` 独立子命令 |
| **S5** | 桌宠展示 **钠 `sodium_mg`**（consumed/remaining/targets） |
| **S6** | **设置** 可调左栏计划/饮食高度比例（默认 60/40） |
| **S7** | fresh `recommendation.json` 中 `loggable: true` 建议食物项可点 → CLI `log` |
| **S7-K** | 同上项支持主键盘 **`1`–`9` 无修饰键** 快捷记录（扁平序号，详设 `design-nutrition-log-interaction.md`） |

### 文档

- `docs/integrations/features/nutrition-today-panel.md`
- `docs/integrations/hermes.md` · `ROADMAP.md` X2 转正
- `MANUAL_QA.md` 域 N

## Capabilities

### New Capabilities

- `nutrition-today-panel`: 饮食面板、FSEvents、钠展示、fresh Hermes-authored 建议项点击 log、左栏比例设置。
- `nutrition-daily-log-contract`: `daily_log.panel` facts/metrics 契约（含钠字段）、归档规则；`suggestions` 仅空数组兼容。
- `hermes-nutrition-panel`: `_refresh_panel`、`refresh-panel` CLI、smoke、晨报、skill 规则。

### Modified Capabilities

- `desk-pet-controls`: 左栏计划+饮食垂直分栏；**设置项**持久化高度比例。

## Impact

- **Hermes**：`recommend.py`、`morning-briefing.py`、`integration_smoke.py`、skill、单测。
- **MalDaze**：`NutritionToday/`、`DashboardRootView`、`MalDazeSettingsView`（左栏比例）、`MalDazeDefaults`、营养 CLI 子进程封装。
- **非目标**：面板 undo / 试算；读 `training_log.json` 独立视图；中栏学习饮食 Tab；MalDaze 本地生成/过滤建议；P3 健身助手；飞书深链。原“第二 JSON 文件”非目标已由 `use-hermes-authored-nutrition-recommendations` supersede 为 `recommendation.json` 推荐契约。
- **依赖**：无；`DashboardRootView` 左栏与设置页改动须与 X9/X10 串行 apply。

## Affected Specs

- `nutrition-today-panel`（新建）
- `nutrition-daily-log-contract`（新建）
- `hermes-nutrition-panel`（新建）
- `desk-pet-controls`（修改）
