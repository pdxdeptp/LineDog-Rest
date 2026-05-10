## 1. 存储与迁移

- [x] 1.1 在 `MalDazeDefaults` 定义 **0…1** 强度键（如 `idlePetAnimationIntensity`）及 `resolved…()`；启动时若缺失则读取旧键 `idlePetIconAnimationEnabled` 迁移（`false→0`、`true→1`），并写入新键
- [x] 1.2 新增或更新广播通知名（如 `idlePetAnimationIntensityChanged`），并在 `AppViewModel` / `WindowManager` / `PetStageView` 链路替换旧布尔通知语义

## 2. PetRenderer

- [x] 2.1 将布尔 `setGIFAnimationEnabled` 演进为 **`setAnimationIntensity(_: Double)`**（或并存 deprecate），实现 **s=0 / s=1 / 中间档** 三套路径（design：中间档可用逐帧 Timer 或已验证方案）
- [x] 2.2 保证 **单调性** 与 **`PetDisplayMode`** 切换时状态一致；避免轮换 Timer 与手动帧循环冲突
- [x] 2.3 更新或新增 `MalDazeTests` 中单测（映射、端点、`0<s<1` 行为的最小断言）

## 3. MenuBarContentView

- [x] 3.1 移除「桌宠图标动态效果」**Toggle**，改为 **`Slider`**（范围 0…1）及两端辅助文案；`@AppStorage` 绑定新键
- [x] 3.2 使用 **`onEditingChanged`** 或仅在拖动结束时投递通知，满足 spec「拖动不刷屏」
- [x] 3.3 按需调整 **`controlPanelPreferredContentSize`**（高度若与 Toggle 相近可不改）

## 4. 验证

- [x] 4.1 全量 `MalDazeTests` + `ControlPanelPresentationTests`
- [x] 4.2 手动：菜单栏与桌宠两处滑杆位置一致；左/中/右行为符合预期；旧用户迁移后无回归
