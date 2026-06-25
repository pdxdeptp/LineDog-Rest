## 1. Spike (default scope)

- [x] 1.1 对比文档：AppViewModel presenter vs host-scoped（含 quiescence 已够否）
- [ ] 1.2 M2 后采集：hide/reopen 10 次 latency + idle CPU（若仍有问题）
- [x] 1.3 决策：Archive as not needed **or** 展开 implementation tasks

## 2. Implementation (gated — only if 1.3 approve)

- [ ] 2.1 Presenter 迁至 Dashboard host / factory
- [ ] 2.2 hide snapshot / show restore
- [ ] 2.3 移除 AppViewModel 上 presenter 字段
- [ ] 2.4 全量 regression tests

## 3. Validation

- [x] 3.1 `openspec validate migrate-focus-timeline-dashboard-scope`
- [x] 3.2 若仅 spike：tasks 1.x done 即可 archive
