## MODIFIED Requirements

### Requirement: 跑屏休息
系统 SHALL 支持跑屏休息模式，让常态小窗在屏幕工作区内漫游。

#### Scenario: 开始跑屏
- **WHEN** `presentBreakRun` 被调用
- **THEN** 系统保存出发前常态窗口 frame
- **AND** `PetStageView` 进入 breakRun display
- **AND** 桌宠切换为 `.breakRunning`
- **AND** `BreakRunController` 开始移动窗口
- **AND** 显示屏幕左下角固定倒计时面板

#### Scenario: 跑屏移动
- **WHEN** 跑屏进行中
- **THEN** 系统以约 60 Hz 更新窗口位置
- **AND** 窗口在当前屏幕 visibleFrame 内边界反弹
- **AND** 按随机间隔和概率改变移动方向

#### Scenario: 跑屏时间到
- **WHEN** 跑屏休息时间到
- **THEN** 系统停止移动
- **AND** 隐藏遮罩和倒计时面板
- **AND** 桌宠用 1 秒动画返回休息前位置
- **AND** 调用休息结束回调
