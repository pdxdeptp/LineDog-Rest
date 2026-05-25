## MODIFIED Requirements

### Requirement: 鼠标穿透
系统 SHALL 避免常态透明窗口区域吞掉桌面点击，并 SHALL 避免在常态静止时持续高频轮询光标。

#### Scenario: 未绑定 ViewModel
- **WHEN** 桌宠菜单 ViewModel 未绑定
- **THEN** 桌宠窗口忽略鼠标事件

#### Scenario: 常态命中区外
- **WHEN** 桌宠在常态且鼠标不在宠物屏幕命中区内
- **THEN** 桌宠窗口设置 `ignoresMouseEvents=true`

#### Scenario: 常态命中区内
- **WHEN** 桌宠在常态且鼠标位于宠物屏幕命中区内
- **THEN** 桌宠窗口接收鼠标事件

#### Scenario: 命中区计算
- **WHEN** `PetStageView` 布局常态宠物
- **THEN** 命中区使用图像布局边长的 60%

#### Scenario: 常态低唤醒跟踪
- **WHEN** 桌宠在常态且鼠标远离桌宠窗口或应用处于空闲显示
- **THEN** 系统 MUST NOT 以 10 Hz 或更高频率持续轮询鼠标位置
- **AND** 系统仍 SHALL 在鼠标进入宠物命中区时恢复窗口接收鼠标事件
