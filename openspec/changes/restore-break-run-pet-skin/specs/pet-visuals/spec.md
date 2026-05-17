## MODIFIED Requirements

### Requirement: LineDog GIF 资源映射
`PetRenderer` SHALL 为每个主要显示状态解析 LineDog GIF 资源。

#### Scenario: runningBlack 资源
- **WHEN** 桌宠模式为 `.runningBlack`
- **THEN** 可使用 `LineDog/idle` 下的无聊、晃脚脚、摆烂、甩耳朵 GIF

#### Scenario: restingRed 资源
- **WHEN** 桌宠模式为 `.restingRed`
- **THEN** 可使用 `LineDog/breakPrompt` 下的休息提示 GIF

#### Scenario: breakRunning 资源
- **WHEN** 桌宠模式为 `.breakRunning`
- **THEN** 可使用 `LineDog/breakRunning` 下的跑屏休息 GIF

#### Scenario: pausedWhiteOutline 资源
- **WHEN** 桌宠模式为 `.pausedWhiteOutline`
- **THEN** 使用 `LineDog/sleeping/线条小狗第12弹_困.gif`

#### Scenario: thinking 资源
- **WHEN** 桌宠模式为 `.thinking`
- **THEN** 可使用 `LineDog/focusGuard` 下的工作、努力、甩耳朵 GIF
