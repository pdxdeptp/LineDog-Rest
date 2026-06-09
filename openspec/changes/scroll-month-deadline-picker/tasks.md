## 1. ScrollMonthDatePicker 组件

- [x] 1.1 新增 `ScrollMonthDatePicker.swift`：`@Binding selection: Date`，固定可视高度 ~220pt，LazyVStack 月块 + scroll snap
- [x] 1.2 实现月内 7 列网格（周日始、`zh_CN` 缩写、today/selected/邻月样式）与 `Calendar.startOfDay` 点选
- [x] 1.3 以 `selection` 为中心生成 ±12 月范围；`onAppear` scroll 定位到选中月
- [x] 1.4 将新文件加入 `MalDaze.xcodeproj`

## 2. 接入截止日 Sheet

- [x] 2.1 在 `LearningDeadlineEditSheet` 用 `ScrollMonthDatePicker` 替换 `.graphical` `DatePicker`
- [x] 2.2 确认 `onChange` → `onDateChange(iso)`、preview 文案、`canConfirm`、确认/取消行为与改前一致

## 3. 测试与验证

- [x] 3.1 单元测试：月网格天数、ISO 边界、选中日落库为 startOfDay（新测试文件或扩展现有 Learning 测试）
- [x] 3.2 `xcodebuild test` 相关 target 通过
- [ ] 3.3 手动 QA：桌宠 → 学习 → 项目 →「修改」截止日 Sheet，触控板纵向滑月、点选日期、preview、确认/取消
