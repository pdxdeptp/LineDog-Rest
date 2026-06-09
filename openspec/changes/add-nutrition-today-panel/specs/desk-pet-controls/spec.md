## ADDED Requirements

### Requirement: Dashboard 左栏计划与饮食垂直分栏

桌宠 Dashboard 左侧固定宽度栏 SHALL 垂直分为两段：上段承载现有「计划」提醒侧栏（EventKit）；下段承载 Hermes 营养今日饮食面板。

默认高度比例为 **计划 60% / 饮食 40%**。比例 SHALL 由设置持久化（见「左栏高度比例设置」）。两段 SHALL 各自拥有独立垂直滚动区域，中间以分隔线区分。左栏总宽度 SHALL 保持与现有 `remindersColumnWidth` 一致。

#### Scenario: 打开 Dashboard 左栏布局

- **WHEN** 用户打开桌宠 Dashboard Panel且未改过比例
- **THEN** 左侧栏上部约 60% 显示「计划」提醒列表
- **AND** 左侧栏下部约 40% 显示饮食面板
- **AND** 两段的滚动互不影响

#### Scenario: 计划侧栏行为不变

- **WHEN** 用户在计划区完成、推迟或编辑提醒
- **THEN** 行为与分栏前一致
- **AND** 饮食面板不因计划区写操作而关闭或重置

#### Scenario: 左栏固定宽度

- **WHEN** Dashboard Panel 计算三栏布局
- **THEN** 左侧组合栏（计划+饮食）保持与分栏前相同的固定像素宽度
- **AND** 中间学习栏与右侧控制栏宽度规则不变

### Requirement: 左栏高度比例设置

MalDaze 设置 SHALL 提供「学习/生活」或等价分类下的 **Dashboard 左栏高度比例** 控件，允许用户调节计划区与饮食区的垂直占比。

默认值 SHALL 为计划 **60%**、饮食 **40%**。合法范围 SHALL clamp 为计划 **40%–75%**（饮食为剩余部分）。变更后 SHALL 持久化并在下次打开 Dashboard 时生效。

#### Scenario: 调整比例

- **WHEN** 用户在设置中将计划区设为 50%
- **THEN** 下次打开 Dashboard 左栏上部约 50%、下部约 50%
- **AND** 重启 app 后比例保持

#### Scenario: 默认值

- **WHEN** 用户从未修改该设置
- **THEN** 计划区高度占比为 60%
