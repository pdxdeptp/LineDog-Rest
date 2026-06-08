# hermes-sleep-tracker Specification

## Purpose

Hermes pmset-based sleep tracking, target advancement, morning briefing section, and `sleep_schedule.json` writes.
## Requirements
### Requirement: Clamshell Sleep 解析

Hermes `sleep_tracker` SHALL 通过 `pmset -g log` 获取指定睡眠夜范围内最后一次 `Entering Sleep state due to 'Clamshell Sleep'` 的时间戳。

#### Scenario: 检测到合盖

- **WHEN** 日志中存在匹配行
- **THEN** 解析为 `actualBedtime` datetime 供算法使用

#### Scenario: 未检测到合盖

- **WHEN** 日志中无匹配行
- **THEN** 晨报注明昨夜未检测到合盖
- **AND** `targetBedtime` 保持不变

### Requirement: 达标判定

Hermes SHALL 将「达标」定义为：昨夜合盖时刻相对昨夜 `targetBedtime` 的偏差 `deltaMinutes ≤ 10`（含提前合盖）。

#### Scenario: 目标后 10 分钟内

- **WHEN** `actualBedtime` 晚于 `targetBedtime` 且差值 ≤ 10 分钟
- **THEN** 判定为达标

#### Scenario: 提前合盖

- **WHEN** `actualBedtime` 早于或等于 `targetBedtime`
- **THEN** 判定为达标

#### Scenario: 超时未达标

- **WHEN** `actualBedtime` 晚于 `targetBedtime` 超过 10 分钟
- **THEN** 判定为未达标

### Requirement: 目标推进

Hermes SHALL 在达标时将明晚 `targetBedtime` 前推 10 分钟；未达标时 `targetBedtime` 不变。`targetBedtime` MUST NOT 早于 `22:30`。

#### Scenario: 达标前推

- **WHEN** 昨夜达标且当前 target 晚于 22:30 超过 10 分钟
- **THEN** 新 target 为当前 target 减 10 分钟

#### Scenario: 触底 22:30

- **WHEN** 昨夜达标且前推后会早于 22:30
- **THEN** 新 target 固定为 `22:30`

#### Scenario: 未达标不变

- **WHEN** 昨夜未达标
- **THEN** `targetBedtime` 与昨夜相同

### Requirement: lockBedtime 计算

Hermes SHALL 将 `lockBedtime` 设为 `targetBedtime` 之后 5 分钟，并写入契约 JSON（含跨午夜情况）。

#### Scenario: 跨午夜 lock

- **WHEN** `targetBedtime` 为 `00:00`
- **THEN** `lockBedtime` 为 `00:05`

### Requirement: dayType 写入

Hermes SHALL 在 Morning Briefing 中于 `recommend.py auto` 之后读取当日 `day_type`，并作为 `dayType` 写入 `sleep_schedule.json`。`dayType` 为必填；缺失时脚本 MUST 以错误退出。

#### Scenario: 写入训练日

- **WHEN** `daily_log.day_type` 为 `training`
- **THEN** 契约 `dayType` 为 `"training"`

### Requirement: Morning Briefing 睡眠段

Hermes SHALL 在 `morning-briefing.py` 输出中追加 🌙 睡眠段落，包含昨夜合盖时间、与目标偏差、达标与否、今晚 `targetBedtime` / `lockBedtime`、今日 `dayType`。

#### Scenario: 达标晨报

- **WHEN** 昨夜达标
- **THEN** 晨报显示 ✅ 达标及新的今晚目标

### Requirement: Cron 集成

睡眠追踪 SHALL 在现有 Morning Briefing cron（`0 8 * * *`，`scripts/morning-briefing.py`）中执行，不新增独立 cron job。

#### Scenario: 每日更新

- **WHEN** Morning Briefing cron 触发成功
- **THEN** `sleep_schedule.json` 被更新
- **AND** 飞书晨报包含睡眠段落

