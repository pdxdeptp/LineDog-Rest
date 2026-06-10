## ADDED Requirements

### Requirement: 跑屏辅助窗口隐藏策略
系统 SHALL keep break-run rest helper windows visible with the desk pet instead of allowing them to hide like ordinary application panels.

#### Scenario: 跑屏倒计时不随应用隐藏
- **WHEN** break-run rest shows its fixed countdown panel
- **THEN** the countdown panel opts out of application hide behavior
- **AND** the countdown panel does not hide when MalDaze deactivates

#### Scenario: 跑屏遮罩不随应用隐藏
- **WHEN** break-run rest shows its delayed shield panel
- **THEN** the shield panel opts out of application hide behavior
- **AND** the shield panel does not hide when MalDaze deactivates

#### Scenario: 跑屏辅助窗口保持既有层级
- **WHEN** the break-run shield and fixed countdown panel are visible
- **THEN** the shield remains below the countdown panel
- **AND** the countdown panel remains below the desk pet window
