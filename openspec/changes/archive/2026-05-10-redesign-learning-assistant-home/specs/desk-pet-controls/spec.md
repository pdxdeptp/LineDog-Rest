## ADDED Requirements

### Requirement: 宽屏桌宠菜单 popover
桌宠控制面板 popover SHALL 使用接近当前屏幕可见宽度的横向布局，并将中间学习助手栏设为自适应主区域。

#### Scenario: 桌宠入口打开宽屏 popover
- **WHEN** 用户左键点击常态桌宠命中区打开桌宠菜单
- **THEN** 系统显示 `MenuBarContentView(viewModel:)`
- **AND** popover 横向宽度接近当前屏幕可见宽度并保留安全边距
- **AND** popover 不超过当前屏幕可见区域

#### Scenario: 左右栏固定宽度
- **WHEN** popover 计算三栏布局
- **THEN** 左侧提醒栏保持固定宽度
- **AND** 右侧控制栏保持固定宽度
- **AND** 分隔线和外边距保持固定宽度

#### Scenario: 学习助手栏自适应
- **WHEN** 当前屏幕可见宽度大于三栏最小宽度
- **THEN** 中间学习助手栏获得左右栏之外的剩余宽度
- **AND** 学习助手栏宽度随屏幕宽度增加而增加

#### Scenario: 窄屏降级
- **WHEN** 当前屏幕可见宽度不足以展示目标宽屏宽度
- **THEN** popover 宽度被 clamp 到当前屏幕可见区域内
- **AND** 学习助手栏保持最小可读宽度

#### Scenario: 关闭行为保持
- **WHEN** 宽屏 popover 打开后用户再次点击桌宠、点击外部、按 Esc 或应用失活
- **THEN** 系统保持现有 popover dismiss 行为
