# 睡眠提醒（sleep）

Hub：[../hermes.md](../hermes.md)

## 职责

| | Hermes | MalDaze |
|---|:------:|:-------:|
| pmset / 目标算法 / 写 JSON / 晨报 | ✅ | ❌ |
| 读 JSON / 铃铛 / 霸屏 / 控制面板 | ❌ | ✅ |

## 契约

**路径**：`~/.hermes/data/sleep/sleep_schedule.json`（Hermes 独占写，MalDaze 只读）

```json
{
  "schemaVersion": 1,
  "targetBedtime": "00:00",
  "lockBedtime": "00:05",
  "dayType": "training",
  "updatedAt": "2026-06-06T08:05:32-04:00"
}
```

`lockBedtime` = `targetBedtime + 5min`（Hermes 算）。`dayType` 来自 `recommend.py auto` 后的 `daily_log.day_type`。缺字段 → MalDaze 停调度。

## Hermes 写端

- **Cron**：`0 8 * * *` → `scripts/morning-briefing.py`
- **顺序**：体重 → 学习 → `recommend.py auto` → 睡眠段 → 饮食
- **模块**：`scripts/sleep_tracker.py`；可选 `data/sleep/sleep_history.json`（桌宠不读）
- **算法**：合盖 ≤ target+10min 为达标；达标则 target 前推 10min/天，下限 22:30

```bash
python3 ~/.hermes/scripts/morning-briefing.py
cat ~/.hermes/data/sleep/sleep_schedule.json
pmset -g log | rg -i clamshell
```

## MalDaze 读端

| 模块 | 路径 |
|------|------|
| 契约 | `SleepScheduleContract.swift` |
| 调度 | `SleepReminderController.swift` |
| 计划 | `SleepReminderPlan.swift` |
| 监听 | `SleepScheduleFileWatcher.swift` |

提醒链：T-90（training+洗澡）/ T-60 / T-30 / deadline → `lockBedtime` 霸屏。  
重调度：启动、FSEvents、唤醒、唤醒+10min、前台、设置变更、21:00–02:00 watchdog。

## 排查

| 现象 | 查什么 |
|------|--------|
| 桌宠报错 | JSON 五字段 |
| 目标不对 | 晨报 🌙、`updatedAt` |
| 合盖/推进 | `sleep_tracker.py`、`pmset -g log` |

OpenSpec：`openspec/specs/sleep-reminder/spec.md` · `sleep-schedule-contract` · `hermes-sleep-tracker`（[archive/2026-06-08-add-sleep-schedule](../../openspec/changes/archive/2026-06-08-add-sleep-schedule/)）
