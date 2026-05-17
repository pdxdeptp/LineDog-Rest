## MODIFIED Requirements

### Requirement: 共享控制面板
系统 SHALL 将桌宠控制面板保留为桌宠入口专属的富控制面板，并 SHALL 将菜单栏入口拆分为独立的设置菜单。桌宠入口和桌宠菜单快捷键 SHALL 继续打开 `MenuBarContentView(viewModel:)`，菜单栏入口 SHALL NOT 直接显示 `MenuBarContentView`。

#### Scenario: 菜单栏入口
- **WHEN** 用户打开菜单栏 Extra
- **THEN** 系统显示独立的小菜单
- **AND** 小菜单只包含一个设置按钮
- **AND** 系统不在菜单栏 Extra 内容中构造 `MenuBarContentView(viewModel:)`

#### Scenario: 菜单栏设置按钮
- **WHEN** 用户在菜单栏小菜单中点击设置按钮
- **THEN** 系统调出桌宠的设置界面
- **AND** 设置界面复用 `MalDazeSettingsView`

#### Scenario: 桌宠入口
- **WHEN** 用户左键点击常态桌宠命中区
- **THEN** 系统在桌宠旁显示 `NSPopover`
- **AND** popover 的 root view 为 `MenuBarContentView(viewModel:)`

#### Scenario: 全局快捷键入口
- **WHEN** 系统收到 `presentDeskPetMenu` 通知
- **THEN** `WindowManager` 以桌宠命中区为 anchor 打开桌宠菜单
- **AND** 桌宠菜单的 root view 为 `MenuBarContentView(viewModel:)`
