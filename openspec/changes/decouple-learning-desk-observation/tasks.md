## 1. Inventory

- [x] 1.1 列出 `LearningDeskPanelView` 及子 view 对 `appViewModel` 的所有引用
- [x] 1.2 分类：read / action / timeline-only

## 2. Narrow surface

- [x] 2.1 定义 `LearningDeskPanelEnvironment`（或等价 protocol）
- [x] 2.2 `DashboardRootView` 注入 environment + `focusTimelinePresenter`
- [x] 2.3 迁移 `LearningDeskPanelView`  off `@ObservedObject AppViewModel` 根观察
- [x] 2.4 保留 deprecated shim 若有外部调用（单点）

## 3. Tests

- [x] 3.1 更新 `ControlPanelPresentationTests`：learning panel 不 require 全量 appViewModel 观察
- [ ] 3.2 （可选）snapshot / source test：statusLine 不在 learning panel body 依赖链

## 4. Validation

- [ ] 4.1 QA：learning panel 全功能（today/schedule/projects/todo/timeline edit）
- [ ] 4.2 Instruments（可选）：manual work visible 时 overlay publish，Today Todo stack 对比
- [x] 4.3 `openspec validate decouple-learning-desk-observation`
