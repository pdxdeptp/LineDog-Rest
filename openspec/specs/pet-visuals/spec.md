# pet-visuals Specification

## Purpose

MalDaze 桌宠使用 LineDog GIF 资源和菜单栏 pawprint 图标呈现应用状态。该规格描述当前宠物状态、GIF 资源映射、动画强度和 fallback 行为。
## Requirements
### Requirement: 宠物显示状态
系统 SHALL 使用 `PetDisplayMode` 表达桌宠和菜单栏图标状态。

#### Scenario: 计时运行状态
- **WHEN** 计时会话 active 且不在休息或智能输入思考中
- **THEN** 菜单栏图标使用 `.runningBlack`
- **AND** 常态桌宠窗口使用 `.runningBlack`

#### Scenario: 暂停状态
- **WHEN** 计时未 active 且不在智能输入思考中
- **THEN** 菜单栏图标使用 `.pausedWhiteOutline`
- **AND** 常态桌宠窗口使用 `.pausedWhiteOutline`

#### Scenario: 休息状态
- **WHEN** 测试休息或计时器休息正在进行
- **THEN** 菜单栏图标使用 `.restingRed`

#### Scenario: 智能输入思考状态
- **WHEN** 智能提醒正在等待 LLM 结果
- **THEN** 菜单栏图标和常态桌宠窗口使用 `.thinking`

#### Scenario: 跑屏状态
- **WHEN** 跑屏休息模式正在进行
- **THEN** 桌宠使用 `.breakRunning` 对应的跑屏显示流程

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

### Requirement: GIF fallback
系统 SHALL 在 GIF 资源不可用时使用 SF Symbol fallback。

#### Scenario: 无 GIF URL
- **WHEN** 当前模式没有可用 GIF URL
- **THEN** `PetRenderer` 显示 `pawprint.fill` SF Symbol
- **AND** 关闭 GIF 动画

#### Scenario: GIF 加载失败
- **WHEN** GIF 数据无法读取或无法创建 `NSImage`
- **THEN** `PetRenderer` 显示 `pawprint.fill` fallback

### Requirement: 动画强度
系统 SHALL 使用 0...1 的 `idlePetAnimationIntensity` 控制常态桌宠 GIF 动态强度。

#### Scenario: 旧布尔设置迁移
- **WHEN** `idlePetAnimationIntensity` 尚未写入
- **THEN** 系统从旧键 `idlePetIconAnimationEnabled` 迁移
- **AND** 旧值 false 映射为 0.0，旧值 true 映射为 1.0
- **AND** 两个键都不存在时默认 1.0

#### Scenario: 静止强度
- **WHEN** animationIntensity <= 0.001
- **THEN** `PetRenderer` 显示 GIF 第一帧
- **AND** 不启动素材轮换 Timer
- **AND** 不启动手动逐帧 Timer

#### Scenario: 中间强度
- **WHEN** animationIntensity 大于 0.001 且小于 0.999
- **THEN** `PetRenderer` 解码 GIF 帧
- **AND** 使用手动 Timer 逐帧播放
- **AND** 帧间隔随强度增大而缩短

#### Scenario: 满速强度
- **WHEN** animationIntensity >= 0.999
- **THEN** `PetRenderer` 使用 `NSImageView.animates = true` 播放原生 GIF

### Requirement: 连续状态素材轮换
系统 SHALL 只在满速原生路径下为连续状态轮换 GIF 变体。

#### Scenario: idle/thinking 轮换
- **WHEN** 当前模式为 `.runningBlack` 或 `.thinking`
- **AND** animationIntensity >= 0.999
- **AND** 当前模式有多个 GIF URL
- **THEN** 系统每 5 分钟随机切换到不同变体

#### Scenario: 非连续状态不轮换
- **WHEN** 当前模式为 `.restingRed` 或 `.pausedWhiteOutline`
- **THEN** 系统不启动变体轮换 Timer

### Requirement: 菜单栏图标
系统 SHALL 使用 SF Symbols 展示菜单栏状态图标。

#### Scenario: 运行图标
- **WHEN** 菜单栏模式为 `.runningBlack` 或 `.breakRunning`
- **THEN** 显示 `pawprint.fill`，颜色使用 `.primary`

#### Scenario: 暂停图标
- **WHEN** 菜单栏模式为 `.pausedWhiteOutline`
- **THEN** 显示黑色较大 `pawprint.fill` 叠加白色较小 `pawprint.fill`

#### Scenario: 休息图标
- **WHEN** 菜单栏模式为 `.restingRed`
- **THEN** 显示红色 `pawprint.fill`

#### Scenario: 思考图标
- **WHEN** 菜单栏模式为 `.thinking`
- **THEN** 显示 indigo `sparkles`

### Requirement: GIF 帧解码缓存
`PetRenderer` SHALL reuse decoded GIF frames for bundled pet GIF URLs when rendering static first frames or intermediate animation intensity.

#### Scenario: 静止路径复用解码结果
- **WHEN** animationIntensity <= 0.001 and the same GIF URL is displayed more than once
- **THEN** `PetRenderer` SHALL reuse previously decoded frames when available
- **AND** it SHALL NOT re-read and re-decode the GIF from disk for each display refresh

#### Scenario: 中间强度路径复用解码结果
- **WHEN** animationIntensity is greater than 0.001 and less than 0.999 and the same GIF URL is displayed more than once
- **THEN** `PetRenderer` SHALL reuse cached frames for manual playback when available
- **AND** manual playback SHALL still honor the current animation intensity when scheduling frame delays

#### Scenario: GIF fallback remains available
- **WHEN** GIF data cannot be decoded or cached frames are unavailable
- **THEN** `PetRenderer` SHALL continue using the existing SF Symbol fallback behavior

### Requirement: 跑屏视觉独立于常态动态强度
系统 SHALL 在跑屏休息模式中以满速播放 `.breakRunning` GIF 视觉，不受 `idlePetAnimationIntensity` 常态桌宠动态强度设置影响。

#### Scenario: 静态常态设置下开始跑屏
- **WHEN** `idlePetAnimationIntensity` 为 0
- **AND** 桌宠显示模式切换为 `.breakRunning`
- **THEN** `PetRenderer` 使用 full-motion GIF 播放路径
- **AND** 不显示静态首帧

#### Scenario: 中间强度常态设置下开始跑屏
- **WHEN** `idlePetAnimationIntensity` 大于 0.001 且小于 0.999
- **AND** 桌宠显示模式切换为 `.breakRunning`
- **THEN** `PetRenderer` 使用 full-motion GIF 播放路径
- **AND** 不使用常态动态强度的手动慢速逐帧播放路径

#### Scenario: 跑屏移动速度保持独立
- **WHEN** 桌宠动态强度发生变化
- **AND** 跑屏休息模式正在进行
- **THEN** 跑屏窗口移动速度仍由 `BreakRunController` 的移动策略决定
