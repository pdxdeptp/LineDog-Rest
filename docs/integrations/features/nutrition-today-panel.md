# 营养今日面板（MalDaze × Hermes）

> Facts/metrics 契约：`~/.hermes/data/nutrition/daily_log.json` 顶层 **`panel`**（`schemaVersion: 1`）<br>
> Recommendation 契约：`~/.hermes/data/nutrition/recommendation.json`（Hermes-authored user-visible recommendation）<br>
> OpenSpec：`add-nutrition-today-panel` + `use-hermes-authored-nutrition-recommendations`

## 数据流

```
Hermes agent / nutrition-menu skill（Menu Turn）
    → recommend.py log|…（写 records + 重算 panel）
    → daily_log.json（facts/metrics）
    → nutrition_authoring_publish.py publish + status（Menu Turn 完成门槛）
    → FSEvents（MalDaze NutritionDailyLogFileWatcher）
    → Dashboard 左栏下段 NutritionTodayPanelView
```

MalDaze 不直接编辑 `daily_log.json`；点击/数字键仅通过子进程 `recommend.py log <name> <grams>` 记录已吃项。
MalDaze **不写** `recommendation.json`，也不在 recommendation 缺失或过期时本地生成替代建议。

### 桌宠角色（当前倾向，可演进）

- **展示 facts/metrics**：读磁盘上的 `daily_log.json` `panel` / `records`；FSEvents 只在 Hermes **已改写文件** 后刷新 UI。
- **展示 recommendation**：读 `recommendation.json` 的 summary、rationale、warnings、items；只有 fresh 且 `loggable: true` 的 item 可点击或数字键记录。
- **唯一 nutrition 写动作**：通过 `recommend.py log` 记一笔已吃。桌宠**不**调用 `refresh-panel`、`plan_engine`、LLM，也不本地重算营养。
- **「现在可以吃」来源**：只来自 Hermes-authored `recommendation.json`。`daily_log.panel.suggestions` 第一版保留为空数组 `[]` 只作 schema 兼容；MalDaze 必须忽略它，即使 legacy 数据非空也不能展示。
- **推荐 item 展示字段**：`displayName` 是 Hermes author 的完整可见食物/数量/单位文案；`kcal` 是可选的 per-item 热量字段，存在时桌宠展示，缺失时桌宠不从 `foods.json` 或 planner 本地推算。

## panel 字段（摘要）

| 字段 | 说明 |
|------|------|
| `dayLabel` | 训练日 / 休息日 |
| `workoutLabel` | 训练日可选：练胸 / 练背和腿（由 `daily_log.workout_split` 派生；轮换历史只读 `training_log`） |
| `targets` / `consumed` / `remaining` | 含 `sodium_mg` |
| `targetBreakdown` | 今日目标 kcal 计算明细（与 `targets.kcal` 同源；Hermes `get_targets()._meta` 投影，随 panel 重算/backfill 自动写入） |
| `suggestions` | 第一版固定 `[]`，仅 schema 兼容；不是推荐来源 |
| `calorieSlack` | 固定 50 |
| `updatedAt` | ISO；与 recommendation `basedOn` 对齐判定 fresh/stale |

归档 `history/` **不含** `panel`。

## Dashboard 布局

左栏固定宽度，垂直分栏：

- 上：计划（EventKit），默认 **60%**
- 下：饮食面板，默认 **40%**
- 设置 → 学习面板区 → **Dashboard 左栏** 滑杆（计划 40%–75%）

## 快捷记录

- 点击 fresh `recommendation.json` 中 `loggable: true` 建议行，或主键盘 **1–9**（无修饰键）
- 扁平序号：遍历 fresh recommendation `suggestions` → `loggable items`，从 1 编号
- 文本框有焦点或 Sheet 打开时不响应数字键
- stale / missing / unavailable / invalid recommendation 状态下不响应点击或数字键

## 调试

```bash
cd ~/.hermes/data/nutrition
python3 recommend.py refresh-panel   # 仅重算 panel，不改 records
python3 ~/.hermes/scripts/integration_smoke.py  # nutrition_panel 项
```

晨报 `morning-briefing.py` 必须跑完整营养链路：`day_classification.py` → `refresh-panel` → `morning_briefing_nutrition.py`，每次都写 fresh `recommendation.json`（`source.kind: morning_briefing`）。不允许 facts-only 晨报。

## 手动 QA

见 [MANUAL_QA.md](../MANUAL_QA.md) § M-N1+。

## 常见问题：推荐缺失或过期

桌宠刷新逻辑一般**没问题**——它展示 `daily_log.json` facts/metrics，并只展示 Hermes 已写入的 `recommendation.json`。如果看到等待/过期：

- `recommendation.json` 不存在：显示 missing/waiting；MalDaze 不调用 `plan_engine` 或 `refresh-panel` 生成建议。
- `daily_log.panel.updatedAt` 与 `recommendation.basedOn.dailyLogPanelUpdatedAt` 不一致，或 `records` 条数与 `basedOn.recordsCount` 不一致：显示 stale（文案：「今日摄入已更新，Hermes 尚未写入匹配的饮食建议。」）；旧建议可作为上下文展示，但点击/数字键禁用。Hermes agent Menu Turn 须在 `nutrition_authoring_publish.py publish --stdin` + `status`（`ok: true`）通过后再对用户宣称已同步；不靠 gateway 自动补写。
- Hermes 无法可靠推荐：写 `state: "unavailable"` 或保持 stale；unavailable payload 第一版不含单独 `reason` 字段，`recommendation_store.py unavailable --reason` 把原因写入 `summary`，且 `suggestions` 必须是 `[]`；MalDaze 可显示 `summary`，但不 fallback。
