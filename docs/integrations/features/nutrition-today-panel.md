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

## panel 字段（摘要）

| 字段 | 说明 |
|------|------|
| `dayLabel` | 训练日 / 休息日 |
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
