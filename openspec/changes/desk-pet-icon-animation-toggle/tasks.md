## 1. 默认值与广播

- [x] 1.1 在 `MalDaze/MalDazeDefaults.swift` 增加布尔持久化键（建议 `idlePetIconAnimationEnabled` 或等价命名），文档注释标明默认 `true`
- [x] 1.2 在 `MalDaze/MalDazeBroadcastNotifications.swift` 增加对应 `Notification.Name`（建议 `idlePetIconAnimationChanged`），命名风格对齐现有 `idlePetIconSidePointsChanged`

## 2. PetRenderer — 动画与轮换

- [x] 2.1 为 `PetRenderer` 增加内部状态或通过 API 表达「是否允许动态」（读默认值或由调用方注入初始值）
- [x] 2.2 在加载 GIF 与 `setDisplayMode` 路径中根据开关设置 `NSImageView.animates`
- [x] 2.3 关闭动态时 `invalidate` 素材轮换 `Timer`；开启动态时按现有 `continuous` 逻辑恢复轮换（与 `PetDisplayMode` 规则一致）
- [x] 2.4 确保 `loadGIF` / 降级 SF Symbol 路径在开关切换后状态一致

## 3. 共享面板 UI（修订：与菜单栏 / 桌宠同步）

- [x] 3.1 **迁移 UI**：从 `WindowManager` 桌宠专用顶栏/外壳中 **移除** `DeskPetIdlePetAnimationToolbar`（及仅为桌宠增加的 `contentSize` 增量）；在 **`MenuBarContentView`** 内与其它 Toggle 同区增加「桌宠图标动态效果」`@AppStorage` + `onChange` 发 `idlePetIconAnimationChanged`（或等价集中投递）。
- [x] 3.2 **尺寸**：若需要，仅调整 **`MenuBarContentView.controlPanelPreferredContentSize`**（或其它**单一**首选尺寸源），使菜单栏 Popover 与桌宠 Popover **共用**同一高度逻辑、避免一侧裁切。
- [x] 3.3 **约束**：不向 `MenuBarContentView` 注入桌宠专用 presentation **environment**；运行 `ControlPanelPresentationTests` 确认仍通过。

## 4. AppViewModel — 运行时同步

- [x] 4.1 在 `AppViewModel` 注册 `idlePetIconAnimationChanged` 观察者（模式对齐 `idlePetIconSidePointsChanged`）
- [x] 4.2 在回调中调用 `WindowManager` 已有暴露方法，将动画偏好刷新到 `PetStageView` / `PetRenderer`
- [x] 4.3 Toggle 变更时投递通知（可在 SwiftUI 侧 `onChange` 或集中于一处），避免与边长逻辑冲突

## 5. 测试与验证

- [x] 5.1 为 `PetRenderer` 编写单元测试：动态关时 `animates` 为 false；动态开时为 true；静态模式下不触发轮换（可测 Timer 不存在或通过可控依赖）
- [x] 5.2 迁移 UI 后重新跑 `MalDazeTests`（含 `ControlPanelPresentationTests`）
- [ ] 5.3 手动验证：**菜单栏与桌宠** 打开的面板中 **同一位置** 可见 Toggle；切换立即作用于桌宠；重启后偏好保持
