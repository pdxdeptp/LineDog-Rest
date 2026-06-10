## ADDED Requirements

### Requirement: 自动休息锚点有效性
自动整点 / 半点休息调度 SHALL treat the scheduled half-hour anchor as the source of truth and SHALL NOT enter scheduled rest from a materially stale timer callback.

#### Scenario: 准时锚点触发进入休息
- **WHEN** `AutoTimerEngine` is waiting for a scheduled `:00` or `:30` anchor
- **AND** the one-shot timer fires within the allowed stale-grace window for that anchor
- **THEN** `AutoTimerEngine` SHALL enter scheduled rest
- **AND** it SHALL emit `.resting` for the configured rest duration

#### Scenario: 睡眠后过期锚点不触发休息
- **WHEN** `AutoTimerEngine` is waiting for a scheduled `:00` or `:30` anchor
- **AND** the one-shot timer callback runs after the allowed stale-grace window for that anchor
- **THEN** `AutoTimerEngine` MUST NOT enter scheduled rest
- **AND** it SHALL schedule the next valid `:00` or `:30` anchor from the current time
- **AND** it SHALL emit `.autoWatching(nextAnchor:)` for that next anchor

#### Scenario: 过期保护窗口有明确上限
- **WHEN** the implementation defines the stale-grace window for automatic rest anchors
- **THEN** the stale-grace window SHALL allow ordinary run-loop delay
- **AND** the stale-grace window MUST be less than one minute

### Requirement: 自动休息唤醒重对齐
系统 SHALL realign automatic rest scheduling after wake or app reactivation while preserving user-paused timer state.

#### Scenario: 唤醒后自动模式重新对齐
- **WHEN** macOS sends a wake notification or the app becomes active
- **AND** the current timer mode is automatic
- **AND** automatic timing is active
- **AND** automatic timing is not currently in scheduled rest
- **THEN** the system SHALL realign `AutoTimerEngine` to the next valid `:00` or `:30` anchor
- **AND** the status line SHALL publish the refreshed next rest time

#### Scenario: 用户暂停后唤醒不自动恢复
- **WHEN** macOS sends a wake notification or the app becomes active
- **AND** the automatic timer session was stopped by the user and is awaiting resume
- **THEN** the system MUST NOT restart automatic timing
- **AND** the persisted user-stopped timer state SHALL remain intact

#### Scenario: 重新对齐保持低唤醒等待
- **WHEN** wake or app reactivation realigns automatic rest scheduling
- **THEN** the waiting phase SHALL use a one-shot timer for the refreshed anchor
- **AND** the system MUST NOT run a repeating sub-second polling timer during the waiting phase
