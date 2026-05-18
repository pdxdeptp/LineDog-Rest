## ADDED Requirements

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
