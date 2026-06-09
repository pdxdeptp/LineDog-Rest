# Design · add-nutrition-today-panel

> 分仓细节：`design-hermes.md` · `design-maldaze.md`  
> Hub：`docs/integrations/features/nutrition-today-panel.md`（apply 时创建）

## Context

- **Hermes 营养域已上线**：`daily_log.json`（SSOT 记录）、`recommend.py`、`plan_engine.py`（`CALORIE_SLACK = 50`）、`nutrition-menu` skill。
- **MalDaze 集成先例**：睡眠 `sleep_schedule.json`（Hermes 写 · MalDaze 只读 · FSEvents）；学习 `projects.json` FSEvents。
- **用户定稿**：方案 A（`daily_log.panel`）；左栏默认 60/40（**设置可调**）；建议项点击 `log`；钠展示；smoke + `refresh-panel`；健身仅一行日型。

## Goals / Non-Goals

**Goals:**

- 飞书记录后 **1s 内**桌宠饮食区反映新剩余额度与建议（FSEvents + debounce）。
- Agent **不需**记住第二文件或额外 refresh 步骤；`recommend.py` 内集中 `_refresh_panel()`。
- MalDaze **零**本地营养计算、**不**手改 JSON；建议 `items[]` 点击 → `recommend.py log`。
- 展示 **钠**；左栏比例默认 60/40，设置持久化。
- 缺 `panel` 或非法 schema → 明确错误/空态。

**Non-Goals:**

- 面板 undo / 试算 / 改日型；已吃 `records` 行点击记录。
- 独立 `training_log` 视图或健身组数记录。
- LLM 多方案 `set-suggestions`（v1.1）。
- HTTP API、第二契约文件。

## Decisions

### D1 · 契约载体：方案 A（`daily_log.panel`）

| 选项 | 结论 |
|------|------|
| A：`daily_log.json` + `panel` | **选用** — 与 `_update_daily_log` 原子写一致；agent 无第二文件负担 |
| B：`today_nutrition.json` | 否决 — skill 易漏 refresh，stale 风险高 |

`panel` 为 **派生视图**；`records` 仍为 SSOT。MalDaze 读 `date`、`day_type`、`records`、`panel`。

### D2 · 集成模式对齐睡眠

| 层 | 睡眠 | 营养 |
|----|------|------|
| 写 | Hermes `sleep_tracker` | Hermes `recommend.py _refresh_panel` |
| 读 | MalDaze `SleepScheduleContract` | MalDaze `NutritionDailyLogContract` |
| 监听 | `SleepScheduleFileWatcher` | `NutritionDailyLogFileWatcher` |
| 路径 | `data/sleep/sleep_schedule.json` | `data/nutrition/daily_log.json` |

文件名不同，**模式相同**。

### D3 · `suggestions` v1 由 Python 生成

- `_refresh_panel()` 末尾：取 `remaining` → 调用 `plan_engine` 默认候选食物集（见 `design-hermes.md`）→ 写 1 条 `suggestions[0]`。
- `within_slack`：对比 `remaining.kcal` 与 suggestion `total.kcal`，容差 `panel.calorieSlack`（50）。
- LLM 库存过滤仍留在飞书；桌宠显示 Python 基线。v1.1 可加 `set-suggestions`。

### D4 · Dashboard 左栏比例（S6）

- 默认计划 **60%** / 饮食 **40%**；`MalDazeDefaults.dashboardLeftPlanFraction`（clamp 0.4–0.75）。
- 设置 → 生活/Dashboard：滑杆或步进调节；变更即时或下次打开 Dashboard 生效。
- 实现：`GeometryReader` + 持久化比例乘左栏高度。

### D7 · 建议项记录：点击 + 数字键（S7 / S7-K）

详设：[design-nutrition-log-interaction.md](./design-nutrition-log-interaction.md)

- 对象：仅 `suggestions[].items[]`；`records` 只读。
- **点击**整行 → `recommend.py log name grams`。
- **数字键 `1`–`9`**（无修饰）：扁平序号对应同一 `log`；>9 项仅点击；macOS 13 用 Dashboard `NSEvent` local monitor。
- 文本框聚焦 / Sheet 打开时数字键 **禁用**；单笔 `isLogging` 互斥。
- 序号随每次 `panel` 刷新重算，不持久绑定食物名。

### D8 · 钠展示（S5）

- `panel.consumed/remaining/targets.sodium_mg` 一行摘要（如 `钠 1200 / 2300 mg`）。

### D9 · smoke + refresh-panel（S3/S4）

- `integration_smoke.check_nutrition_panel` 必做。
- `recommend.py refresh-panel` 供晨报与无 mutating 重算。

### D5 · 归档剥离 `panel`

`_archive_day_to_profile` / 写入 `history/YYYY-MM-DD.json` 时只复制 `date`、`day_type`、`records`、`weight_kg`，**不**复制 `panel`。

### D6 · 日型一行

UI 使用 `panel.dayLabel`（「训练日」「休息日」）；不读 `training_log.json`。训练消耗已反映在 `get_targets()` 的当日 kcal 目标中。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| `daily_log` 变大，桌宠每次读全文件 | 单日 records 规模小；只 decode 需要的键 |
| Python 基线建议未做 LLM 库存过滤 | v1 标注「参考」；飞书仍是主决策；v1.1 `set-suggestions` |
| FSEvents 漏报 | 可选 30–60s 轻量轮询兜底（对齐 intervention 链） |
| `plan_engine` 无可用食物 → 空 suggestions | `panel` 仍写 consumed/remaining；UI 显示「暂无建议」 |
| 与 X9/X10 同改 `DashboardRootView` | tasks 串行或限定 diff 区域为左栏 `remindersSidebar` 包装 |

## Migration Plan

1. Hermes：先 ship `_refresh_panel` + 单测；手动 `recommend.py status` 验证 `panel` 出现。
2. MalDaze：契约 + watcher + UI；`integration_smoke` 可选断言 `panel.schemaVersion`。
3. 文档 + MANUAL_QA；用户目视后归档。
4. 回滚：MalDaze 隐藏饮食区；Hermes `panel` 字段可保留（向后兼容）。

## Open Questions（已 scope 关闭）

- **OQ-1** → **S1**：`recommend.py` 内常量默认食物集；不传全库、不另建配置文件 v1。
- **OQ-2** → **S2**：v1 **要** 45s 轮询兜底（Dashboard 打开时；`updatedAt` 变才 reload）。见 `scope-decision.md`。
