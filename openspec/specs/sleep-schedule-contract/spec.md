# sleep-schedule-contract Specification

## Purpose

On-disk JSON contract between Hermes (writer) and MalDaze (reader) for nightly sleep targets and day type.
## Requirements
### Requirement: 契约文件路径与所有权

系统 SHALL 使用 `~/.hermes/data/sleep/sleep_schedule.json` 作为 Hermes 与 MalDaze 之间的唯一睡眠调度契约。

Hermes SHALL 独占写入该文件。MalDaze SHALL 只读，且 MUST NOT 修改该文件。

#### Scenario: Hermes 写入

- **WHEN** Hermes Morning Briefing 睡眠段成功执行
- **THEN** Hermes 原子更新 `sleep_schedule.json`

#### Scenario: MalDaze 读取

- **WHEN** MalDaze 睡眠提醒需要调度或重调度
- **THEN** MalDaze 从上述路径读取 JSON
- **AND** MalDaze MUST NOT 写入该路径

### Requirement: 必填字段

契约 JSON SHALL 包含以下必填字段：

- `schemaVersion`（整数，当前为 `1`）
- `targetBedtime`（字符串，`HH:mm`，24 小时制）
- `lockBedtime`（字符串，`HH:mm`，为 `targetBedtime` 之后 5 分钟，由 Hermes 计算）
- `dayType`（字符串，`"training"` 或 `"rest"`）
- `updatedAt`（ISO 8601 时间戳，含时区）

#### Scenario: 完整契约

- **WHEN** MalDaze 读取到上述五个字段且格式合法
- **THEN** MalDaze 使用该契约调度当晚提醒

#### Scenario: 缺字段

- **WHEN** MalDaze 读取的 JSON 缺少任一必填字段
- **THEN** MalDaze MUST 报错并停止睡眠提醒调度
- **AND** MalDaze MUST NOT 使用默认值替代缺失字段

### Requirement: 强耦合假设

本集成 SHALL 记录为 intentional fragile coupling：MalDaze 与 Hermes 预期同时运行；Hermes 每日 08:00 cron 负责更新契约。

设计文档 MUST 包含排查指引：睡眠提醒异常时首先检查 `sleep_schedule.json` 是否存在且字段完整。

#### Scenario: 文件不存在

- **WHEN** `sleep_schedule.json` 不存在且 MalDaze 睡眠总开关为开
- **THEN** MalDaze MUST 报错并停止调度

### Requirement: 初始目标

当 Hermes 无睡眠历史状态时，Hermes SHALL 将 `targetBedtime` 初始化为 `00:00`，并将 `lockBedtime` 初始化为 `00:05`。

#### Scenario: 首次初始化

- **WHEN** Hermes 首次创建 `sleep_schedule.json`
- **THEN** `targetBedtime` 为 `00:00`
- **AND** `lockBedtime` 为 `00:05`

