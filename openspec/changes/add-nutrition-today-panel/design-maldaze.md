# Design · MalDaze

## 模块 `MalDaze/NutritionToday/`

| 文件 | 职责 |
|------|------|
| `NutritionDailyLogContract.swift` | Decode `daily_log.json`：`date`、`day_type`、`records`、`panel` |
| `NutritionDailyLogContractReader.swift` | 默认路径 `~/.hermes/data/nutrition/daily_log.json` |
| `NutritionDailyLogFileWatcher.swift` | FSEvents debounce ~1s（抄 `SleepScheduleFileWatcher`） |
| `NutritionTodayPanelView.swift` | 宏量/钠/已吃/建议列表 UI |
| `NutritionTodayViewModel.swift` | load / watcher / **logItem(flatIndex:)** / 轮询 |
| `NutritionHermesCLI.swift` | `log(name:grams:)` 子进程 |
| `NutritionDigitKeyMonitor.swift` | Dashboard 内 `1`–`9` 监听 |

## 契约 decode

- `panel.schemaVersion` 必须为 `1`；否则 failed 态。
- 缺 `panel`：显示「尚无饮食面板数据」+ 提示飞书 Hermes 记录。
- 不 decode `foods.json` / `profile.json`。

## UI（左栏下段，高度 = 1 − 计划比例）

```
饮食
训练日 / 休息日
1200 / 1800 kcal  bar
蛋白 · 碳水 · 脂肪 · 钠 1200/2300 mg

── 已吃（只读）──
· 燕麦 50g  188 kcal

── 现在可以吃 ──
 1  希腊酸奶·去脂  170g   99 kcal   ← 点击或按 1
 2  燕麦          40g  150 kcal   ← 点击或按 2
按 1–9 快捷记录
```

交互详设：[design-nutrition-log-interaction.md](./design-nutrition-log-interaction.md)
- 比例来自 `MalDazeDefaults.dashboardLeftPlanFraction`（默认 0.6）。

## Dashboard 布局

`DashboardRootView`：

- 将 `remindersSidebar` 包入 `leftColumnStack`：
  - `planSection.frame(maxHeight: h * 0.6)`
  - `Divider()`
  - `NutritionTodayPanelView(...).frame(maxHeight: h * 0.4)`
- Watcher：`NutritionTodayViewModel.startWatching()` 在 Dashboard 出现时；消失时 `stop`（对齐 `LearningDeskPanelViewModel`）。

## 错误态

| 条件 | UI |
|------|-----|
| 文件不存在 | -caption 提示 Hermes 营养目录 |
| JSON 非法 | 错误文案 + 路径 |
| 无 `panel` | 空态 |
| `schemaVersion` ≠ 1 | 错误「不支持的契约版本」 |

## 测试

- `NutritionDailyLogContractTests`：fixture JSON decode
- 可选 ViewModel 测试：watcher debounce mock
