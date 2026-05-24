## MODIFIED Requirements

### Requirement: 计时控制
控制面板 SHALL 提供手动番茄和整点/半点模式控制。系统 SHALL preserve a user-stopped timer session across app restarts until the user resumes, starts a new manual focus session, or switches timer mode.

#### Scenario: 模式切换
- **WHEN** 用户切换模式
- **THEN** 系统停止当前引擎
- **AND** 关闭休息窗口
- **AND** 清除已持久化的用户停止计时状态
- **AND** 按新模式更新状态行和宠物状态

#### Scenario: 手动专注
- **WHEN** 用户在手动模式点击“开始专注”
- **THEN** 系统启动 manual timer
- **AND** 设置计时会话 active
- **AND** 清除已持久化的用户停止计时状态

#### Scenario: 停止计时
- **WHEN** 用户点击“停止计时”
- **THEN** 系统停止当前计时引擎
- **AND** 显示“恢复计时”入口
- **AND** 持久化当前计时模式作为用户停止计时状态

#### Scenario: 启动时恢复停止计时状态
- **WHEN** app 启动且存在有效的用户停止计时状态
- **THEN** 系统恢复停止时的计时模式
- **AND** 不启动计时引擎
- **AND** 显示“恢复计时”入口
- **AND** 宠物显示暂停状态

#### Scenario: 恢复计时
- **WHEN** 用户点击“恢复计时”
- **THEN** 系统按当前模式重新启动对应计时引擎
- **AND** 清除已持久化的用户停止计时状态

#### Scenario: 忽略无效停止计时状态
- **WHEN** app 启动且持久化的用户停止计时状态不是有效计时模式
- **THEN** 系统清除该无效状态
- **AND** 使用无停止状态时的默认启动行为
