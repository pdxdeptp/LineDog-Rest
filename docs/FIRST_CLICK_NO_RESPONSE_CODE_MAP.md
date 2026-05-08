# 启动后首次点击桌宠无响应 — 代码地图

> **目的**：梳理与「刚启动时点第一下桌宠无反应」相关的所有代码路径，不做任何修改。

---

## 一、启动时序

### 1.1 `AppViewModel.init()` — `AppViewModel.swift:80–142`

```
windowManager = WindowManager()          // ← 构造 WindowManager，开始安装窗口
...
windowManager.bindDeskPetMenu(viewModel: self)   // ← 绑定点击弹出菜单
windowManager.setRestBlocksClicks(...)
```

关键：`bindDeskPetMenu` 在 `AppViewModel.init()` 末尾调用，此时 `window` 和 `stageView` **可能尚未创建**（`installPetWindowIfNeeded` 是异步的）。

---

### 1.2 `WindowManager.init()` — `WindowManager.swift:139–165`

```swift
// 两条通道，先到者负责，另一条被 window == nil 守卫挡掉
launchObserver = NotificationCenter.default.addObserver(
    forName: NSApplication.didFinishLaunchingNotification, ...
) { [weak self] _ in
    Task { @MainActor [weak self] in self?.installPetWindowIfNeeded() }
}
DispatchQueue.main.async { [weak self] in
    Task { @MainActor [weak self] in self?.installPetWindowIfNeeded() }
}
```

窗口的实际创建推迟到 `main` 队列的下一拍或 `didFinishLaunching` 通知，**早于此时的 `bindDeskPetMenu` 调用是在 `stageView == nil` 的情况下进行的**。

---

### 1.3 `WindowManager.installPetWindowIfNeeded()` — `WindowManager.swift:273–339`（Fix 1 已应用）

```swift
let view = PetStageView(frame: NSRect(origin: .zero, size: frame.size))
wireDeskPetCallbacks(into: view)      // 设置 deskMenuPresenter
win.contentView = view
window = win
stageView = view
win.orderFrontRegardless()
syncContentViewToWindowLayout()
view.applyNonRestPetDisplayMode(pendingIdlePetMode)
view.needsLayout = true
view.layoutSubtreeIfNeeded()          // ← 布局（含 petHitRect 计算）
// Fix 1：applyMousePolicy 已移至 layoutSubtreeIfNeeded 之后
applyMousePolicy()                    // ← 此时 petHitRect 已正确赋值
postIdlePetScreenFrameChanged(win.frame)
// ...
scheduleRepositionToPrimaryDisplay()  // ← 120ms 后再 reposition 一次
DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
    self?.repositionToPrimaryDisplay() // ← 250ms 后再 reposition 一次
}
```

Fix 1 修复了 `petHitRect==.zero` 的问题，但 **这不是"约 1 秒无响应"的主因**（见第十节）。

---

### 1.4 `WindowManager.bindDeskPetMenu()` — `WindowManager.swift:338–359`

```swift
func bindDeskPetMenu(viewModel: AppViewModel?) {
    deskMenuViewModel = viewModel
    ...
    if let v = stageView {
        wireDeskPetCallbacks(into: v)   // stageView 为 nil 时此句跳过
    }
    // Pre-warm the popover
    ...
    applyMousePolicy()                  // ← 再次设定 ignoresMouseEvents
}
```

若 `bindDeskPetMenu` 在 `installPetWindowIfNeeded` 之前运行，`stageView == nil`，`wireDeskPetCallbacks` 被跳过；但 `deskMenuViewModel` 已赋值，`applyMousePolicy()` 会执行到 `startIdleCursorTracking()` 分支（`window` 还是 nil，直接 return）。

之后 `installPetWindowIfNeeded` 运行时，`wireDeskPetCallbacks` 在 `stageView` 创建后被正确调用。

---

## 二、鼠标策略核心

### 2.1 `applyMousePolicy()` — `WindowManager.swift:746–763`

```swift
private func applyMousePolicy() {
    guard let win = window else { return }
    stageView?.restUserBlocksClicksOutsidePet = restBlocksClicks
    guard deskMenuViewModel != nil else {
        win.ignoresMouseEvents = true   // 无 ViewModel 时窗口完全穿透
        stopIdleCursorTracking()
        return
    }
    if stageView?.isInRestPhase == true {
        stopIdleCursorTracking()
        syncPetRestWindowMousePolicy()
        return
    }
    // 常态（含跑屏模式）：
    startIdleCursorTracking()
    syncIdleWindowMousePolicy()         // ← 立即执行一次，依赖 petHitRect
}
```

---

### 2.2 `syncIdleWindowMousePolicy()` — `WindowManager.swift:780–785`

```swift
private func syncIdleWindowMousePolicy() {
    guard let win = window, let stage = stageView else { return }
    guard !stage.isInRestPhase, deskMenuViewModel != nil else { return }
    let petScreen = win.convertToScreen(stage.petHitRectInWindowBaseCoordinates)
    win.ignoresMouseEvents = !petScreen.contains(NSEvent.mouseLocation)
}
```

**依赖** `petHitRectInWindowBaseCoordinates`，后者来自 `PetStageView.petHitRect`（在 `layoutIdlePet()` 中计算）。

---

### 2.3 `startIdleCursorTracking()` — `WindowManager.swift:765–772`

```swift
private func startIdleCursorTracking() {
    guard idleCursorTrackTimer == nil else { return }
    let t = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        Task { @MainActor [weak self] in self?.syncIdleWindowMousePolicy() }
    }
    RunLoop.main.add(t, forMode: .common)
    idleCursorTrackTimer = t
}
```

每 **100ms** 轮询一次光标位置并更新 `ignoresMouseEvents`。定时器启动后首次触发需等待 100ms。

---

## 三、`PetStageView` 中的点击命中与响应

### 3.1 `petHitRect` 初始化与布局 — `PetStageView.swift:46,487–513`

```swift
private var petHitRect: NSRect = .zero   // 初始为零

// layoutIdlePet() 在 layout() 中被调用（由 layoutSubtreeIfNeeded 触发）
private func layoutIdlePet() {
    let b = bounds
    guard b.width > 1, b.height > 1 else { return }
    ...
    if b.width < 400 {
        // 常态小窗：50×50 命中区，居中
        let hitSide: CGFloat = 50
        let half = hitSide / 2
        petHitRect = NSRect(x: center.x - half, y: center.y - half,
                            width: hitSide, height: hitSide)
    } else {
        petHitRect = Self.petHitRect(center: center, scale: scale, in: b, hitPadding: 16)
    }
    ...
}
```

`petHitRect` 只在 `layout()` 生命周期内被赋值。若 `layout()` 尚未运行，值为 `.zero`。

---

### 3.2 `petHitRectInWindowBaseCoordinates` — `PetStageView.swift:92–95`

```swift
var petHitRectInWindowBaseCoordinates: NSRect {
    convert(petHitRect, to: nil)   // nil 表示转换到窗口基坐标
}
```

若 `petHitRect == .zero`，此属性返回「窗口原点处的零尺寸矩形」。

---

### 3.3 `hitTest(_:)` — `PetStageView.swift:175–203`

```swift
override func hitTest(_ point: NSPoint) -> NSView? {
    guard deskMenuPresenter != nil else { return nil }
    ...
    // 常态：只有点在 petHitRect 范围内才拦截，透明边缘穿透到桌面
    guard petHitRect.contains(local) else { return nil }
    return self
}
```

`deskMenuPresenter` 为 nil 或光标不在 `petHitRect` 内时返回 nil，事件穿透。

---

### 3.4 `acceptsFirstMouse(for:)` — `PetStageView.swift:171–173`

```swift
override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
}
```

即便窗口未成为 Key Window，首次点击也应被传递到视图。但若 `win.ignoresMouseEvents == true`，此方法无效——事件根本不进入窗口。

---

### 3.5 `mouseDown(with:)` — `PetStageView.swift:205–230`

```swift
override func mouseDown(with event: NSEvent) {
    guard deskMenuPresenter != nil else { return }
    ...
    // 常态分支：记录下按位置，用于区分点击与拖动
    suppressDeskMenuOnNextIdleMouseUp = false
    idleMouseDownInWindow = event.locationInWindow
    idleLastScreenMouse = NSEvent.mouseLocation
    idleMaxDragFromDown = 0
}
```

---

### 3.6 `mouseUp(with:)` — `PetStageView.swift:262–323`

```swift
override func mouseUp(with event: NSEvent) {
    guard deskMenuPresenter != nil else { return }
    ...
    // 常态：拖动距离 < 4 点才触发菜单弹出
    if idleMaxDragFromDown < 4 {
        deskMenuPresenter?.presentDeskMenu(from: self, anchorRect: petHitRect)
    } else if let win = window {
        onIdlePetFramePersist?(win.frame)
    }
}
```

弹出菜单在 `mouseUp` 而非 `mouseDown` 触发，防止与拖动冲突。

---

## 四、`PetStageWindow` — `WindowManager.swift:6–9`

```swift
private final class PetStageWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

注释说明：默认 `NSWindow` 在 accessory 应用中 `canBecomeKey == false`，导致 `clickCount` 无法累加（双击问题）。此处覆写使其可成为 Key Window。

---

## 五、`wireDeskPetCallbacks()` — `WindowManager.swift:361–376`

```swift
private func wireDeskPetCallbacks(into v: PetStageView) {
    v.deskMenuPresenter = deskMenuViewModel != nil ? self : nil
    v.onIdlePetFramePersist = { [weak self] r in ... }
    v.onRestPhaseGeometryChanged = { [weak self] in
        self?.syncPetRestWindowMousePolicy()
    }
    if deskMenuViewModel != nil {
        v.onRestPetDoubleClickEndRest = { [weak self] in
            self?.deskMenuViewModel?.endRestEarlyFromDeskPet()
        }
    } else {
        v.onRestPetDoubleClickEndRest = nil
    }
}
```

`v.deskMenuPresenter` 在此赋值。若 `deskMenuViewModel == nil`，`deskMenuPresenter = nil`，`hitTest` 和所有 `mouseXxx` 回调均提前返回 nil 或 return。

---

## 六、完整启动链路（时序摘要）

```
[App 进程启动]
  └─ DeskRemindersModel.performPrepare（极早期）
       └─ activateEphemeralKeyWindowForSystemModal()
            ├─ NSApp.activate(ignoringOtherApps: true)  ← App 立即成为 frontmost
            └─ ephemeralKeyWindow.makeKeyAndOrderFront()
  └─ EventKit 权限回调（约 515ms 后）→ fetchDeskSidebarReminders

AppViewModel.init()
  └─ WindowManager()
       ├─ [channel A] DispatchQueue.main.async → installPetWindowIfNeeded()
       └─ [channel B] didFinishLaunching observer → installPetWindowIfNeeded()

AppViewModel.init() 继续同步执行：
  └─ windowManager.bindDeskPetMenu(viewModel: self)
       ├─ deskMenuViewModel = viewModel
       ├─ wireDeskPetCallbacks(into: stageView)   ← stageView 此时为 nil，跳过
       ├─ Pre-warm popover（创建 NSHostingController，但未 show，SwiftUI 渲染未完成）
       └─ applyMousePolicy()                      ← window 为 nil，直接 return

[下一个 RunLoop 拍]（Fix 1 已应用）
  └─ installPetWindowIfNeeded() 运行
       ├─ PetStageView(frame:)  → petHitRect = .zero
       ├─ wireDeskPetCallbacks(into: view)        ← deskMenuPresenter 正确赋值
       ├─ win.contentView = view
       ├─ win.orderFrontRegardless()
       ├─ view.layoutSubtreeIfNeeded()             ← layout() → petHitRect = (41,41,50,50) ✓
       ├─ applyMousePolicy()                       ← Fix 1 确保在 layout 后调用
       │    ├─ startIdleCursorTracking()           ← 100ms 定时器启动
       │    └─ syncIdleWindowMousePolicy()         ← petHitRect 正确，ignoresMouseEvents 按光标位置设置
       ├─ scheduleRepositionToPrimaryDisplay()     ← 120ms 后 reposition
       └─ asyncAfter(0.25s) repositionToPrimaryDisplay()  ← 250ms 后 reposition

[用户可交互状态]
  └─ ignoresMouseEvents 每 100ms 由定时器正确刷新
     bindDeskPetMenu 预热的 popover 存在但 SwiftUI 未完成真实 layout
```

---

---

## 七、Popover 弹出链路（已修复的 `ignoresMouseEvents` 之后仍有问题的根因）

### 7.1 `bindDeskPetMenu()` — 预热 Popover — `WindowManager.swift:341–362`

```swift
func bindDeskPetMenu(viewModel: AppViewModel?) {
    deskMenuViewModel = viewModel
    ...
    // Pre-warm the popover so SwiftUI renders on startup, not on first click.
    if let vm = viewModel {
        let pop = NSPopover()
        pop.behavior = .transient          // ← 关键：transient 会对 popover 外部任何点击关闭
        pop.animates = false               // ← 关掉内置动画，改用手动淡入
        let host = NSHostingController(rootView: MenuBarContentView(viewModel: vm))
        host.view.translatesAutoresizingMaskIntoConstraints = true
        pop.contentViewController = host
        pop.contentSize = NSSize(width: 668, height: 560)
        deskMenuPopover = pop
        deskMenuHosting = host
        // !! 注意：此处仅创建 NSHostingController，未调用 pop.show()
        // SwiftUI 不会在无 window/frame 时完成真正的 layout 渲染
    }
    applyMousePolicy()
}
```

**预热缺陷**：`NSHostingController` 创建后 `.view.frame == .zero`（没有 window），SwiftUI 的第一次 layout pass 实际上在 `pop.show()` 被调用、宿主 view 获得窗口和 frame 之后才真正运行。"预热"效果可能存疑。

---

### 7.2 `presentDeskMenu()` — 完整弹出逻辑 — `WindowManager.swift:981–1038`

```swift
func presentDeskMenu(from stage: PetStageView, anchorRect: NSRect) {
    guard let vm = deskMenuViewModel else { return }

    if deskMenuPopover == nil { ... }          // (A) 临时创建
    else if let host = deskMenuHosting {
        host.rootView = MenuBarContentView(viewModel: vm)   // (B) 同步 rootView（第一次）
    }

    guard let pop = deskMenuPopover else { return }
    if pop.isShown {
        // 淡出并关闭（toggle 行为）
        ...
        return
    }

    let capturedAnchor = anchorRect
    DispatchQueue.main.async { [weak self, weak pop, weak stage] in
        guard let pop, !pop.isShown, let stage else { return }
        NSApp.activate(ignoringOtherApps: true)   // ← Fix 2 加入（已确认无效，见下）
        pop.show(relativeTo: capturedAnchor, of: stage, preferredEdge: .minY)
        if let win = pop.contentViewController?.view.window {
            win.alphaValue = 0                    // ← 开场透明（掩盖 bug 症状）
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.14
                win.animator().alphaValue = 1     // 140ms 淡入
            }
        }
        if let host = self?.deskMenuHosting, let vm = self?.deskMenuViewModel {
            host.rootView = MenuBarContentView(viewModel: vm)   // (C) 异步再次同步 rootView（第二次）
        }
    }
}
```

---

### 7.3 关键新发现：`MalDazeModalKeyWindowAnchor.activateEphemeralKeyWindowForSystemModal()` 在启动时已调用 `NSApp.activate`

调试日志（`debug-b74a09.log` 首条记录）：

```
[t=1778081592139] DeskRemindersModel.swift:performPrepare → before_activateEphemeralKeyWindow
[t=1778081592157] MalDazePresentationAnchor.swift → before_makeKeyAndOrderFront
[t=1778081592164] MalDazePresentationAnchor.swift → after_makeKeyAndOrderFront
[t=1778081592654] EventKitRemindersBacking.swift:fetchDeskSidebarReminders → fetched_reminder × N
```

`activateEphemeralKeyWindowForSystemModal()` 第一行：

```swift
static func activateEphemeralKeyWindowForSystemModal() {
    NSApp.activate(ignoringOtherApps: true)   // ← 启动时已调用！
    ...
    window?.makeKeyAndOrderFront(nil)
}
```

**结论**：Fix 2 在 `pop.show()` 前加 `NSApp.activate(ignoringOtherApps: true)` 是**冗余操作**。启动时 App 已经是 frontmost，"App 非 frontmost → transient 立即关闭" 的假设不成立。这解释了为什么 Fix 2 没有任何改变。

---

### 7.4 几何分析：桌宠命中区 vs Popover 位置

桌宠（常态）配置：
- 窗口：132×132，贴近屏幕右下角，`y ≈ 10`（距底边 10pt）
- `petHitRect`（view 本地坐标）：`(41, 41, 50, 50)`，即 view 中心的 50×50 正方形
- 屏幕坐标：`petHitRect` → 约 `(screenRight-91, 51, 50, 50)`，Y 范围：`51..101`

`pop.show(relativeTo: petHitRect, of: stage, preferredEdge: .minY)` 行为：
- `.minY` = popover 应出现在锚点**下方**（screen Y 更小方向）
- `minY` 方向：`y = 51`，向下延伸 560pt → `y = 51-560 = -509` → **超出屏幕底边**
- AppKit 自动翻转为 `.maxY`（**上方**）：popover 从 `y ≈ 101` 往上延伸 560pt → `y ≈ 101..661`

**结论**：
```
屏幕坐标系（Y 向上）：
  661 ┌─────────────────────────────┐
      │        Popover (668×560)    │
  101 └─────────────────────────────┘   ← Popover 底边
  101 ···· petHitRect 顶边 ···
   51 ···· petHitRect 底边 ···
   10 ┌────────────────┐
      │  桌宠窗口 132×132 │
    0 └────────────────┘
```

**petHitRect（y:51..101）完全落在 Popover 外部（y:101..661）。** 用户在 petHitRect 上的每一次点击，都被 `.transient` 监视器视为"popover 外侧点击"，触发立即关闭。

---

### 7.5 NSPopover 内部冷却期（Internal Cooldown）

NSPopover 被 transient 关闭后，内部存在约 **500ms–1s** 的保护期，在此期间再次调用 `pop.show()` 会**静默失败**（直接 return，不报错，不显示）。

这解释了用户描述的 **"约 1 秒"** 等待时间：用户快速点击 → 每次 transient 触发关闭 → 冷却期内 `pop.show()` 失效 → 看起来完全无响应 → 等够 1s 后 `pop.show()` 才能再次成功。

---

### 7.6 `pop.animates = false` + `alphaValue = 0` 的掩盖效果

```
pop.show(...)           → popover 在屏幕上存在（但...）
win.alphaValue = 0      → 立即全透明，用户看不见
0..140ms 淡入进行中...
[用户第二次快速点击桌宠]
  → petHitRect 在 popover 外 → transient 监视器触发 → pop.close()
  → pop.isShown=true 的 toggle 关闭分支也触发 fade-out+close
→ popover 消失，仍在 alpha≈0（用户什么都没看到）
→ NSPopover 进入冷却期（~1s）
```

`alphaValue = 0` 将 "popover 瞬间弹出又瞬间关闭" 的行为**完全隐藏**，使现象看起来是"无响应"而非"闪出即关"。

---

## 八、完整故障时序（第三版 — 真实根因）

```
[App 启动]
  └─ DeskRemindersModel.performPrepare
       └─ activateEphemeralKeyWindowForSystemModal()
            ├─ NSApp.activate(ignoringOtherApps: true)   ← App 已是 frontmost
            └─ ephemeralWindow.makeKeyAndOrderFront()    ← 临时 Key Window 已建立

[用户第一次点击桌宠 petHitRect（screen y≈51..101）]
  ├─ ignoresMouseEvents==false（定时器已校正，petHitRect 已正确）
  ├─ acceptsFirstMouse → mouseDown/mouseUp 到达 PetStageView
  ├─ mouseUp → presentDeskMenu()
  │    ├─ host.rootView = MenuBarContentView(vm)（同步，第一次 SwiftUI 更新）
  │    └─ DispatchQueue.main.async { ... }
  │
  └─ [下一个 RunLoop]
       ├─ NSApp.activate(...)    ← 冗余（App 已 frontmost）
       ├─ pop.show(relativeTo: petHitRect, of: stage, .minY)
       │    └─ AppKit 翻转为 .maxY：popover 出现在 y≈101..661
       ├─ win.alphaValue = 0     ← popover 透明（用户不可见）
       ├─ 140ms 淡入开始...
       └─ host.rootView = MenuBarContentView(vm)（异步，第二次 SwiftUI 更新）

[用户快速第二次点击（在 ~140ms 内，或任意时间内点在 petHitRect）]
  ├─ petHitRect (y:51..101) 在 popover 外 (y:101..661)
  ├─ NSPopover.transient 全局监视器捕获到 popover 外点击 → pop.close()
  ├─ 同时：mouseUp → presentDeskMenu → pop.isShown==true → toggle 淡出关闭
  ├─ popover 关闭（用户全程看不见，因 alphaValue=0）
  └─ NSPopover 进入内部冷却期（约 500ms–1s）

[冷却期内任意点击]
  └─ pop.show() 静默失败 → 用户看不到任何响应

[约 1s 后用户再次点击]
  └─ 冷却期已过 → pop.show() 成功 → 用户未再快速二次点击
     → 140ms 后 alphaValue=1 → 菜单正常显示
     → App 保持 frontmost → 后续点击不再复现（且冷却期不被触发）
```

---

## 九、已尝试修复及失效原因

| 修复编号 | 改动 | 预期效果 | 实际结果 | 失效原因 |
|----------|------|----------|----------|----------|
| Fix 1 | `applyMousePolicy()` 移至 `layoutSubtreeIfNeeded()` 之后 | 修复 `petHitRect==.zero` → `ignoresMouseEvents=true` | 用户报告无变化 | 此 bug 确实存在且已修复，但不是主因；主因在 popover 层面 |
| Fix 2 | `pop.show()` 前加 `NSApp.activate(ignoringOtherApps: true)` | 确保 App frontmost 防止 transient 关闭 | 用户报告无变化 | 启动时 `activateEphemeralKeyWindowForSystemModal()` 已调用 `NSApp.activate`；Fix 2 完全冗余 |

---

## 十、根本原因与推荐修复方案

### 根本原因

`NSPopover.behavior = .transient` 的全局点击监视器**把用户在 petHitRect 上的每次点击都视为"popover 外部点击"**，导致 popover 在用户看不见（`alphaValue=0`）时被立即关闭，随后 NSPopover 进入约 1s 冷却期，期间 `pop.show()` 静默失败。

### 推荐修复方案

**方案 A（推荐）：改为 `.applicationDefined` 行为，自定义关闭逻辑**

```swift
// bindDeskPetMenu 中：
pop.behavior = .applicationDefined   // ← 关键改动

// presentDeskMenu async 块末尾，安装自定义关闭监视器：
let petWindowRef = stage.window
let popoverRef = pop
let closeMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
    guard let popoverWindow = popoverRef.contentViewController?.view.window else { return }
    let clickInScreen = NSEvent.mouseLocation
    // 在 popover 窗口内：不关闭
    if popoverWindow.frame.contains(clickInScreen) { return }
    // 在桌宠 petHitRect 内：不关闭（mouseUp 里有 toggle 逻辑处理）
    if let petWin = petWindowRef,
       let stage = petWin.contentView as? PetStageView {
        let petScreen = petWin.convertToScreen(stage.petHitRectInWindowBaseCoordinates)
        if petScreen.contains(clickInScreen) { return }
    }
    // 其他区域：关闭
    DispatchQueue.main.async { popoverRef.close() }
}
// 在 popover 关闭时移除监视器
```

**方案 B（快速验证）：去掉 `alphaValue = 0`，暴露真实行为**

仅删除 `win.alphaValue = 0` 那一行（但保留淡入动画改为从 alpha=0.3 开始）。这样用户能看到 popover "闪出即关"的现象，从而验证根因，同时减少 "完全无响应" 的用户体验。

**方案 C（备选）：在 `mouseUp` 中增加 debounce 防止 toggle 误关**

即便 transient 已关闭，在 150ms 内的下一次 `mouseUp` 触发 `presentDeskMenu` 时，若 `pop.isShown == false` 且距上次 show 不足 150ms，忽略此次点击（不重新 show）。这解决了"刚 show 就被 toggle 关"的竞争，但解决不了 transient 的根本问题。

### 各方案对比

| 方案 | 改动量 | 修复彻底性 | 风险 |
|------|--------|-----------|------|
| A（`.applicationDefined`） | 中（需自定义监视器） | 彻底 | 需要仔细处理监视器生命周期 |
| B（去 alphaValue=0） | 极小 | 仅暴露问题，不修复 | 无，可用于验证 |
| C（debounce） | 小 | 部分（仍有 transient 冷却问题） | 可能掩盖新 bug |
| D（mouseDown 提前激活） | 极小 | 可能彻底（取决于系统事件时序） | 几乎无 |

---

## 十一、第三轮分析：新发现（基于调试日志）

### 11.1 调试日志时序分析

从 `debug-b74a09.log` 提取关键时间点（单位 ms，相对于进程启动 t=1778081592139）：

```
t=0ms    performPrepare 开始 → activateEphemeralKeyWindowForSystemModal → NSApp.activate + ephemeral window makeKeyAndOrderFront
t=18ms   ephemeral window 成为 isKeyWindow (confirmed)
t=515ms  EventKit 权限回调完成 → 提醒列表拉取
t=~517ms performPrepare 返回 → defer: removeEphemeralKeyWindow() → ephemeral window orderOut
         [App 此后可能处于无 key window 状态 → 可能已 deactivated]
t=13542ms breakrun 动画开始 (restore from previous session)
t=14533ms breakrun 动画完成 → 宠物回到右下角 → 用户首次可见宠物
t=~15000ms+ 用户第一次点击宠物
```

**关键结论**：用户首次点击宠物时，`removeEphemeralKeyWindow()` 已调用了约 **14 秒**。在这期间 App 极大概率已经 deactivated。

---

### 11.2 App Deactivation 路径

`removeEphemeralKeyWindow()` 调用 `window?.orderOut(nil)`：
- 这是 App 进程里唯一处于 `.normal` level 的 "可见" 窗口
- PetStageWindow 处于 `.floating` level，`collectionBehavior = [.canJoinAllSpaces, .stationary]`
- 对于 `activationPolicy == .accessory` 的应用，macOS 在隐藏所有 `.normal` level 可见窗口后，**会自动 deactivate 应用**（因为浮动 floating-level 窗口不参与正常的 App 激活模型）

验证方式：在 `syncIdleWindowMousePolicy()` 中加一行 `NSApp.isActive` 日志，观察 `removeEphemeralKeyWindow()` 后约 100ms 的值。

---

### 11.3 "App 激活事件触发 transient 关闭" 的完整机制

代码注释本身已经描述了此机制（`WindowManager.swift:1014-1018`）：

```swift
// acceptsFirstMouse 让浮动窗口在 App 非 frontmost 时就能收到点击，
// 但 .transient popover 一旦检测到"App 激活"事件（随后到来）就会认为用户点了外面而立即关闭。
// NSApp.activate 确保 App 先成为 frontmost，transient 监听器不会把激活事件误判为外部点击。
```

但 Fix 2 仍无效，原因是 **`NSApp.activate` 在 `DispatchQueue.main.async` 内被调用 → 时机已晚**：

```
[RunLoop Tick 1 - 用户点击事件]
  mouseDown → mouseUp → presentDeskMenu
  └─ DispatchQueue.main.async { ... } 加入队列（尚未执行）
  └─ 系统发现 non-frontmost App 被点击 → 生成 App Activation Event（进入系统事件队列）

[RunLoop Tick 2 - main.async 执行]
  NSApp.activate(ignoringOtherApps: true)  ← 将 App 设为 frontmost
  pop.show(...)                            ← transient 监听器安装
  win.alphaValue = 0

[RunLoop Tick 3 - 系统事件队列处理]
  App Activation Event 到达
  └─ transient 监听器处理此事件 → 认为 "外部交互" → pop.close()
  └─ NSPopover 进入冷却期（~1s）
```

`NSApp.activate` 在 RunLoop Tick 2 调用，使 App 成为 frontmost。但系统在 Tick 1 已将 Activation Event 压入队列。此 event 在 Tick 3 才被处理，此时 `transient` 监听器已安装 → **关闭**。

**为什么 Fix 2 完全无效**：`NSApp.activate` 在 main.async 里与 `pop.show()` 是同一 tick 执行，Activation Event 仍在更晚的 tick 到达。"确保 App 先成为 frontmost" 不能阻止已经入队的 Activation Event。

---

### 11.4 "仅在启动时出现" 的解释

| 场景 | App 是否 frontmost | 用户点击时激活事件 | popover 是否被关闭 |
|------|-------------------|--------------------|-------------------|
| 启动后首次（App 已 deactivated） | ✗ | 系统发送 Activation Event → Tick N+1 处理 | ✓（被 transient 关闭） |
| 首次成功开启面板之后 | ✓（面板开过，App 已 frontmost） | 无 Activation Event | ✗（面板正常显示） |

首次成功开启面板后，App 永久 frontmost（用户后续操作都在 App 内进行）→ 不再有 Activation Event → transient 不再误关闭。

---

### 11.5 修复方案 D（mouseDown 提前激活）

Fix 2 的失败原因：`NSApp.activate` 与 `pop.show()` 在同一 RunLoop tick 调用，Activation Event 在下一 tick 才到。

**Fix D 的逻辑**：把激活移到 `mouseDown`（即 RunLoop Tick 1），让 Activation Event 在 Tick 1-2 之间处理完毕，到 pop.show() 所在的 Tick 2 时队列已清空：

```swift
// PetStageView.mouseDown(with:) 头部加：
override func mouseDown(with event: NSEvent) {
    // 若 App 非 frontmost，提前激活，确保 Activation Event 在
    // pop.show() 之前就已经被系统处理完毕。
    if !NSApp.isActive {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    guard deskMenuPresenter != nil else { return }
    // ... 现有逻辑 ...
}
```

也可以去掉 `presentDeskMenu` 里 main.async 块内的 `NSApp.activate(ignoringOtherApps: true)`（或保留，作为第二道保险）。

**Fix D 的局限**：如果系统 Activation Event 的处理晚于 RunLoop Tick 2（例如因为系统调度延迟），Fix D 也可能失效。因此 Fix D 是一个"高概率成功"但不保证 100% 的轻量修复，而 Fix A（`.applicationDefined`）才是根本解决方案。

---

### 11.6 几何问题的确认（原 7.4 节补充）

代码注释没有提到几何问题，表明原开发者未意识到 `petHitRect (y:51..101)` 落在 `Popover (y:101..661)` 之外。这是 transient 行为的**第二个触发源**（第一个是 Activation Event）：

- 即使 Activation Event 不触发关闭（例如 App 本来就是 frontmost）
- 用户在面板开着期间点击桌宠（petHitRect 外）→ transient 仍然关闭
- 这会在 "面板已开着" 时导致 toggle 操作失效（每次点击都被 transient 关掉而不是走 isShown=true 的淡出分支）

两个触发源叠加，使"修一个还有另一个"，让 Fix A（`.applicationDefined`）成为唯一彻底修复方案。

---

## 十二、所有修复方案对比（更新版）

| 方案 | 触及根因 | 改动量 | 修复成功率 | 风险 |
|------|---------|--------|-----------|------|
| **A**（`.applicationDefined` + 自定义监视器） | 两个触发源都消除 | 中 | 100% | 监视器需精心管理生命周期 |
| **B**（去 `alphaValue=0`） | 无（仅暴露问题） | 极小 | 0%（验证用） | 无 |
| **C**（debounce 防 toggle） | 仅第二源的部分 | 小 | <50% | 可能掩盖新 bug |
| **D**（`mouseDown` 提前 `NSApp.activate`） | 第一触发源（Activation Event） | 极小 | ~80% | mouseDown 激活可能有其他副作用 |
| **A+D**（组合） | 两个触发源 | 中 | 100% | — |

**推荐顺序**：
1. 快速验证：先做 Fix D，测试启动后第一次点击是否好转
2. 根本修复：做 Fix A，彻底消除 transient 带来的几何 + 激活双重问题
