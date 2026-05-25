## MODIFIED Requirements

### Requirement: 跑屏遮罩与倒计时
系统 SHALL 在跑屏期间提供倒计时，并在长跑屏后显示轻遮罩。

#### Scenario: 固定倒计时面板
- **WHEN** 跑屏开始
- **THEN** 系统在菜单栏屏幕可见区左下角显示倒计时面板
- **AND** 面板层级高于跑屏遮罩、低于桌宠窗口

#### Scenario: 一分钟后遮罩
- **WHEN** 跑屏时长超过 60 秒
- **THEN** 系统在 60 秒后显示半透明遮罩
- **AND** 遮罩显示在跑屏小狗当前所在的物理显示器上
- **AND** 桌宠窗口升至 `.screenSaver` 层级，保持可点击

#### Scenario: 遮罩不跟随焦点屏
- **WHEN** 跑屏小狗在显示器 A 上运行
- **AND** 当前鼠标位置、键盘焦点或 `NSScreen.main` 指向显示器 B
- **THEN** 60 秒后的半透明遮罩显示在显示器 A 上

#### Scenario: 倒计时更新
- **WHEN** 跑屏进行中
- **THEN** 系统每秒更新小狗内倒计时和固定倒计时面板
