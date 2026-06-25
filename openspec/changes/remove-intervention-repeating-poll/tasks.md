## 1. Audit

- [x] 1.1 确认 `wakeObserver` / `becomeActiveObserver` 已调用 `processPendingIfNeeded`
- [x] 1.2 记录移除 poll 前的 integration 测试覆盖

## 2. Implementation

- [x] 2.1 删除 `startPollTimerIfNeeded` / `stopPollTimer` / `pollTimer` 生产路径
- [x] 2.2 保留 FSEvents watcher + lifecycle reconcile
- [ ] 2.3 （可选）`#if DEBUG` diagnostic poll 文档化

## 3. Tests

- [ ] 3.1 FSEvents / file change 仍触发 process
- [ ] 3.2 Wake/becomeActive reconcile 测试或 harness
- [x] 3.3 源码测试：无 `timeInterval: 3.0, repeats: true` in InterventionRequestController

## 4. Validation

- [ ] 4.1 Manual QA：Hermes 写入 intervention → bell 触发
- [x] 4.2 `openspec validate remove-intervention-repeating-poll`
