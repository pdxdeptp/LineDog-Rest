## ADDED Requirements

### Requirement: 应用拥有的后端进程随应用退出收束
系统 SHALL 在 MalDaze 应用退出时终止由当前 MalDaze 进程显式 spawn 的学习助手后端子进程，并 SHALL NOT 通过端口监听进程扫描来推断后端所有权。

#### Scenario: 当前会话拥有后端子进程
- **WHEN** MalDaze 本次启动时 spawn 了学习助手后端
- **AND** 用户通过 Cmd+Q 或应用退出流程终止 MalDaze
- **THEN** 系统终止该后端子进程
- **AND** `127.0.0.1:8765` 不再由该子进程监听

#### Scenario: 后端检测到父进程消失
- **WHEN** 学习助手后端由 MalDaze spawn 并收到预期父进程身份
- **AND** 后端运行期间发现当前父进程不再是该 MalDaze 进程
- **THEN** 后端 SHALL 主动优雅退出

#### Scenario: 端口由外部服务占用
- **WHEN** MalDaze 启动时发现 `127.0.0.1:8765` 已被占用
- **THEN** 系统 SHALL 将该端口仅视为可连接的外部后端服务
- **AND** MalDaze 退出时 SHALL NOT 终止该监听进程

#### Scenario: 端口探测不授予终止权限
- **WHEN** MalDaze 退出时存在监听 `127.0.0.1:8765` 的进程
- **AND** 该进程不是当前 MalDaze 进程显式 spawn 的后端子进程
- **THEN** 系统 SHALL NOT 因端口号、命令行或工作目录匹配而终止该进程
