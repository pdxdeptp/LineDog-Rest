## MODIFIED Requirements

### Requirement: 智能提醒入口
桌宠 SHALL 支持从右键或全局快捷键打开智能提醒输入，并 SHALL 通过 `MalDazeTransientOverlayPresenter` 使用可承载长自然语言文本的紧凑多行输入面板。

#### Scenario: 桌宠右键
- **WHEN** 用户右键点击桌宠命中区
- **THEN** 系统以该命中区为 anchor 经展示器打开智能提醒输入面板
- **AND** 输入面板默认聚焦文本输入区

#### Scenario: 全局智能提醒快捷键
- **WHEN** 系统收到 `openSmartReminderInput` 通知
- **THEN** 系统以桌宠窗口或默认底部 anchor 经展示器打开智能提醒输入面板
- **AND** 输入面板默认聚焦文本输入区

#### Scenario: 长文本可见
- **WHEN** 用户输入超过单行宽度的自然语言计划文本
- **THEN** 输入文本在面板内换行显示
- **AND** 面板提供多行可读高度，而不是只显示单行横向截断内容

#### Scenario: 输入面板尺寸受控
- **WHEN** 用户继续输入很长的文本
- **THEN** 输入面板保持在预设最大高度内
- **AND** 文本输入区保持可继续编辑，不扩大成全屏或遮挡式窗口

#### Scenario: 输入面板保持在可见屏幕区域内
- **WHEN** 用户在靠近屏幕右下角或右侧 Dock 的桌宠上打开智能提醒输入
- **THEN** 展示器将输入面板 frame clamp 到 anchor 所在屏幕的 `visibleFrame` 内
- **AND** 输入面板不超出屏幕右边界
- **AND** 输入面板不被右侧 Dock 覆盖

#### Scenario: 输入草稿保留
- **WHEN** 用户点外部、Esc 或取消关闭智能提醒输入
- **THEN** 系统保留草稿文本

#### Scenario: 提交成功清空
- **WHEN** 智能提醒成功写入且草稿仍等于本次提交文本
- **THEN** 系统清空草稿

#### Scenario: 显式提交
- **WHEN** 用户通过输入面板的提交动作添加提醒
- **THEN** 系统将完整草稿文本提交给智能提醒编排流程

## ADDED Requirements

### Requirement: Smart reminder toast uses shared presenter

MalDaze SHALL present smart reminder result toasts through `MalDazeTransientOverlayPresenter` using the interactive anchored policy.

#### Scenario: Toast presentation

- **WHEN** smart reminder orchestration requests a result toast
- **THEN** `WindowManager` delegates toast creation, positioning, ordering, and dismissal to the transient overlay presenter
- **AND** existing undo and auto-dismiss behavior remains unchanged
