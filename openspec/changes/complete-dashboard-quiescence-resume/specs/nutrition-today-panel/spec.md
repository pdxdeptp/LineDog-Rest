## MODIFIED Requirements

### Requirement: FSEvents 刷新

MalDaze SHALL 通过 FSEvents 监听 `~/.hermes/data/nutrition/daily_log.json` 与 `~/.hermes/data/nutrition/recommendation.json` 所在目录（文件级事件），在 debounce 约 1 秒后重新加载契约。

MalDaze SHALL start and stop nutrition Hermes file watchers exclusively through the Dashboard quiescence coordinator registered pause and resume handlers. The nutrition today panel SHALL NOT subscribe to `deskPetDashboardDidClose` or use SwiftUI `onAppear` / `onDisappear` as the authority for starting or stopping file watchers.

#### Scenario: Hermes 更新后刷新

- **WHEN** Hermes 更新 `daily_log.json` 或 `recommendation.json` 且 Dashboard presentation phase 为 `visible`
- **THEN** MalDaze 在约 1 秒内刷新展示

#### Scenario: Dashboard 不可见时停止监听

- **WHEN** Dashboard presentation phase 变为 `hidden`
- **THEN** MalDaze 停止饮食相关 FSEvents 监听以降低开销
- **AND** the stop is performed by the coordinator pause handler registered at app composition root

#### Scenario: Dashboard 再次可见时恢复监听

- **WHEN** Dashboard presentation phase 从 `hidden` 变为 `visible`
- **THEN** MalDaze 重新启动饮食相关 FSEvents 监听，且不要求 SwiftUI `onAppear` 再次触发
- **AND** MalDaze 立即执行一次非阻塞 catch-up 读取（`loadToday(showLoading: false)` 或等价行为）以同步 hide 期间 Hermes 已写入的磁盘变更

## REMOVED Requirements

### Requirement: 轮询兜底

**Reason**: Removed in `df25d44`; superseded by reliable FSEvents plus coordinator resume catch-up on Dashboard show.

**Migration**: No 45-second polling; Hermes disk changes while hidden are picked up on show via catch-up read.
