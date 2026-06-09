# 营养今日面板（MalDaze × Hermes）

> 契约：`~/.hermes/data/nutrition/daily_log.json` 顶层 **`panel`**（`schemaVersion: 1`）  
> OpenSpec：`add-nutrition-today-panel`

## 数据流

```
飞书 / nutrition-menu skill
    → recommend.py log|auto|…（写 records + 重算 panel）
    → daily_log.json
    → FSEvents（MalDaze NutritionDailyLogFileWatcher）
    → Dashboard 左栏下段 NutritionTodayPanelView
```

MalDaze **不写** `daily_log.json`；点击/数字键仅子进程 `recommend.py log <name> <grams>`。

### 桌宠角色（当前倾向，可演进）

- **展示**：读磁盘上的 `panel` / `records`；FSEvents 与轻量轮询只在 Hermes **已改写文件** 后刷新 UI。
- **唯一写操作**：`log`（记一笔已吃）。桌宠**不**调用 `refresh-panel`、`plan_engine`、LLM，也不本地重算营养。
- **「现在可以吃」来源**：不是飞书大模型实时菜单，而是 Hermes `recommend.py` 在每次 mutating 写入（含 `log`）末尾用 **`plan_engine` 默认候选食物** 生成的 Python 基线（OpenSpec D3）；飞书对话仍是更完整的推荐入口，v1.1 才可能 `set-suggestions` 覆盖 panel。

## panel 字段（摘要）

| 字段 | 说明 |
|------|------|
| `dayLabel` | 训练日 / 休息日 |
| `workoutLabel` | 训练日可选：练胸 / 练背和腿（由 `daily_log.workout_split` 派生；轮换历史只读 `training_log`） |
| `targets` / `consumed` / `remaining` | 含 `sodium_mg` |
| `suggestions[].items[]` | 须含 `name` + `grams`（可点击记录） |
| `calorieSlack` | 固定 50 |
| `updatedAt` | ISO；45s 轮询兜底 |

归档 `history/` **不含** `panel`。

## Dashboard 布局

左栏固定宽度，垂直分栏：

- 上：计划（EventKit），默认 **60%**
- 下：饮食面板，默认 **40%**
- 设置 → 学习面板区 → **Dashboard 左栏** 滑杆（计划 40%–75%）

## 快捷记录

- 点击建议行，或主键盘 **1–9**（无修饰键）
- 扁平序号：遍历 `suggestions` → `items`，从 1 编号
- 文本框有焦点或 Sheet 打开时不响应数字键

## 调试

```bash
cd ~/.hermes/data/nutrition
python3 recommend.py refresh-panel   # 仅重算 panel，不改 records
python3 ~/.hermes/scripts/integration_smoke.py  # nutrition_panel 项
```

晨报 `morning-briefing.py` 营养段结束后自动 `refresh-panel`。

## 手动 QA

见 [MANUAL_QA.md](../MANUAL_QA.md) § M-N1+。

## 常见问题：建议热量/碳水与「剩余」对不上

桌宠刷新逻辑一般**没问题**——它只是展示 Hermes 上次写入的 `panel`。若两行建议明显超出剩余额度，多半是 **Hermes 侧 `plan_engine` 在极小剩余窗口下的已知局限**，而非 MalDaze 又算了一遍：

- `remaining.kcal` 很小时（例如只剩 ~80 kcal），食物 `min_g` / 库存离散克重（如酸奶 200g）会把组合**顶穿**剩余热量；`within_slack` 为 `false` 时桌宠**不展示**「现在可以吃」（走「暂无建议」空态），不在 Swift 侧改克重或过滤单行。
- 宏量里**碳水列**是每行食物的碳水克数，不要和顶栏 **kcal 剩余**混读；应看 `remaining.carbs_g` 与建议 `total.carbs_g` 是否同量纲。
- 钠、脂肪已超标（`remaining` 为负）时，引擎仍可能给出组合——属于 Hermes 规划层待收紧的行为，应在 `recommend.py` / `plan_engine` 或飞书侧改菜单，而不是桌宠过滤行。
