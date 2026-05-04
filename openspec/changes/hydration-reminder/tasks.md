## 1. MalDazeDefaults — 新增 UserDefaults 键

- [x] 1.1 在 `MalDaze/MalDazeDefaults.swift` 末尾添加两个静态常量：`hydrationReminderEnabled = "MalDaze.hydrationReminder.enabled"` 和 `hydrationReminderIntervalMinutes = "MalDaze.hydrationReminder.intervalMinutes"`

## 2. HydrationReminderController — 核心控制器

- [x] 2.1 新建目录 `MalDaze/HydrationReminder/`，新建文件 `HydrationReminderController.swift`，声明 `@MainActor final class HydrationReminderController`，照抄 `SevenMinuteReminderController` 的头部结构：`var onStateChanged: ((Bool) -> Void)?`、`private var reminderWindow: NSWindow?`、`private var pendingTimer: Timer?`、`private var screenObserver`
- [x] 2.2 实现 `static func configuredIntervalMinutes() -> Int`：读 `UserDefaults.standard.integer(forKey: MalDazeDefaults.hydrationReminderIntervalMinutes)`，无值时返回 90，clamp 到 15…240
- [x] 2.3 实现 `func start()`：调用 `cancel()`，读 `MalDazeDefaults.hydrationReminderEnabled`，若为 false 直接返回；否则调用 `schedulePendingTimer(after: configuredIntervalMinutes() * 60)`，调用 `onStateChanged?(true)`
- [x] 2.4 实现 `func cancel()`：invalidate `pendingTimer`，置 nil；调用 `tearDownReminderWindow()`；移除 screenObserver；调用 `onStateChanged?(false)`
- [x] 2.5 实现私有 `schedulePendingTimer(after seconds: TimeInterval)`：用 `Timer.scheduledTimer(withTimeInterval: seconds, repeats: false)` 创建单次 Timer，RunLoop.main `.common` 模式，回调 `Task { @MainActor in self?.fireReminder() }`；保存引用到 `pendingTimer`
- [x] 2.6 实现 `fireReminder()`：调用 `tearDownReminderWindow()`，从 PawPal `pick(labels.bubble.hydrationReminder)` 对应的中文数组（见下）随机选一条文案，调用 `showReminderWindow(message:)`。文案数组照抄 PawPal i18n：`["我是一个小渴鬼🤔，你也应该喝点水？", "*舔舔嘴唇* 🤍 时间喝水～", "喝水喝水喝水！💧", "主人，喝水啦～"]`
- [x] 2.7 实现 `showReminderWindow(message:)`：仿照 `SevenMinuteReminderController.showReminderWindow`，但把铃铛图标换成 `drop.fill`（SF Symbol，蓝色调色），把 `ReminderDismissPanelView` 替换为两个 `NSButton`：主按钮标题「已喝水 💧」调用 `handleDone()`，次按钮标题「稍后提醒」调用 `handleSnooze()`；两个按钮竖排，间距 10pt，置于 textField 下方；内容卡片高度相应增大（参考 SevenMinuteReminder 计算逻辑，增加 `buttonsHeight = 2 * 32 + 10`）
- [x] 2.8 实现 `handleDone()`：调用 `tearDownReminderWindow()`；调用 `schedulePendingTimer(after: configuredIntervalMinutes() * 60)` 重新调度完整间隔
- [x] 2.9 实现 `handleSnooze()`：调用 `tearDownReminderWindow()`；调用 `schedulePendingTimer(after: 15 * 60)` 调度 15 分钟后
- [x] 2.10 实现 `tearDownReminderWindow()`：`reminderWindow?.orderOut(nil); reminderWindow = nil`
- [x] 2.11 照抄 `SevenMinuteReminderController` 的 `observeScreensIfNeeded()` / `removeScreenObserver()` / `repositionReminderWindow()` 逻辑；在 `fireReminder()` 内调用 `observeScreensIfNeeded()`，在 `cancel()` 内调用 `removeScreenObserver()`

## 3. Xcode 工程 — 新增源文件引用

- [x] 3.1 在 `MalDaze.xcodeproj/project.pbxproj` 中为 `HydrationReminderController.swift` 添加 PBXBuildFile + PBXFileReference 条目，并加入 MalDaze target 的 Sources Build Phase（照抄相邻 `FiveMinuteCatCompanionController.swift` 的格式）

## 4. AppViewModel — 集成控制器

- [x] 4.1 在 `AppViewModel` 中添加 `@Published private(set) var isHydrationReminderEnabled: Bool`，初始值从 `UserDefaults.standard.bool(forKey: MalDazeDefaults.hydrationReminderEnabled)` 读取
- [x] 4.2 添加 `private let hydrationReminder: HydrationReminderController` 属性，在 `init` 中初始化为 `HydrationReminderController()`（同 `sevenMinuteReminder` 写法，支持测试注入）
- [x] 4.3 在 `init` 中调用 `self.hydrationReminder.onStateChanged = { [weak self] active in self?.isHydrationReminderEnabled = active }`，并在初始化末尾调用 `if isHydrationReminderEnabled { hydrationReminder.start() }`
- [x] 4.4 实现 `func setHydrationReminderEnabled(_ enabled: Bool)`：持久化到 UserDefaults，更新 `isHydrationReminderEnabled`，调用 `hydrationReminder.start()` 或 `hydrationReminder.cancel()`
- [x] 4.5 实现 `func setHydrationReminderInterval(_ minutes: Int)`：clamp 到 15…240，持久化到 UserDefaults；若 `isHydrationReminderEnabled` 为 true 则调用 `hydrationReminder.cancel()` + `hydrationReminder.start()` 令新间隔立即生效
- [x] 4.6 在 `deinit` 中补充 `hydrationReminder.cancel()`（防止 Timer 在 ViewModel 销毁后继续跑）

## 5. MenuBarContentView — 喝水提醒 UI 区块

- [x] 5.1 在 `MenuBarContentView` 顶部添加 `@AppStorage(MalDazeDefaults.hydrationReminderIntervalMinutes) private var hydrationIntervalStored = 90`
- [x] 5.2 在 `mainControlsColumn` 的独立倒计时区块下方（即 `// 独立 5 分钟小猫` Divider 之前）插入新区块：
  ```
  Divider()
  Text("喝水提醒")
      .font(.subheadline).foregroundStyle(.secondary)
  Text("按设定间隔弹出提醒，点「已喝水」重新计时，点「稍后提醒」15 分钟后再提醒。")
      .font(.caption).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
  Toggle(isOn: Binding(
      get: { viewModel.isHydrationReminderEnabled },
      set: { viewModel.setHydrationReminderEnabled($0) }
  )) { Text("开启喝水提醒") }
  Stepper(value: $hydrationIntervalStored, in: 15...240, step: 15,
      onEditingChanged: { editing in
          if !editing { viewModel.setHydrationReminderInterval(hydrationIntervalStored) }
      }
  ) { Text("间隔：\(hydrationIntervalResolved) 分钟") }
  .disabled(!viewModel.isHydrationReminderEnabled)
  ```
- [x] 5.3 在 `MenuBarContentView` 中添加私有计算属性 `hydrationIntervalResolved: Int`：同 `sevenMinuteMinutesResolved` 写法，clamp `hydrationIntervalStored` 到 15…240

## 6. 验证

- [x] 6.1 构建 MalDaze target，确认零编译错误、零警告（新增文件）
- [ ] 6.2 手动测试：开启喝水提醒，将间隔改为 1 分钟（最小 15 分钟不符，可临时改代码下限为 1），等待浮层弹出，验证「已喝水」与「稍后提醒」各自行为正确
- [ ] 6.3 手动测试：关闭喝水提醒开关，确认不再弹出浮层；重启应用，确认开关状态保留
- [ ] 6.4 手动测试：间隔 Stepper 步进，确认值在 15–240 之间变化；重启应用确认间隔持久化
- [ ] 6.5 手动测试：SevenMinuteReminder 铃铛与喝水浮层同时显示（时机调好），确认两个窗口互不干扰
