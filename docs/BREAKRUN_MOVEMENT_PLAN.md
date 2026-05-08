# 跑屏休息模式 — 实施计划

> 参考来源：[PawPal/src/main/main.ts](https://github.com/zebangeth/PawPal/blob/main/src/main/main.ts)（`startBreakRun` / `movePetForBreakRun` / `chooseBreakRunVelocity`）
> 编写时间：2026-05-06

---

## 一、目标

在休息倒计时期间，桌宠小窗在整个屏幕工作区内随机弹跳漫游（替代现有的「全屏霸屏 + 暗幕」模式），视觉效果轻盈，不遮挡用户正在进行的工作。

**保留现有的鼠标穿透屏蔽逻辑**（`idleCursorTrackTimer` + `NSWindow.ignoresMouseEvents`），使透明区域继续穿透，只有桌宠图标中心 50×50 区域截获点击。

---

## 二、现有机制梳理

| 组件 | 现有角色 |
|---|---|
| `WindowManager.presentRest(duration:onDismissed:)` | 触发霸屏：窗口扩至全屏，级别改为 `.screenSaver` |
| `PetStageView.beginRestCycle(total:onComplete:)` | 在全屏视图内驱动"渐近+倒计时+渐出"动画 |
| `idleCursorTrackTimer`（10 Hz 轮询）| 持续检测鼠标是否在 50×50 区域内，动态切换 `ignoresMouseEvents` |
| `petHitRect`（`PetStageView`）| 当前可点击矩形，空闲时为 50×50，休息全屏时扩至宠物实际尺寸 |

---

## 三、PawPal breakRun 算法（待移植）

```
来源：src/main/main.ts + src/main/config.ts

常量：
  PET_WINDOW: 220×340 px（PawPal 窗口尺寸，MalDaze 中对应 ~120×120）
  BREAK_RUN_DURATION_MS: 60 000 ms（每次跑屏持续 60 秒；MalDaze 用整个休息 duration）
  BREAK_RUN_TICK_MS: 16 ms（≈60 Hz）

速度初始化 chooseBreakRunVelocity()：
  speed = random(3.5, 6.4) px/tick
  angle = random(0, 2π)
  velocity = (cos(angle)*speed, sin(angle)*speed)

每帧 movePetForBreakRun()：
  nextX = bounds.x + velocity.x
  nextY = bounds.y + velocity.y
  if nextX ≤ minX: nextX=minX, velocity.x=|velocity.x|   // 左边反弹
  if nextX ≥ maxX: nextX=maxX, velocity.x=-|velocity.x|  // 右边反弹
  if nextY ≤ minY: nextY=minY, velocity.y=|velocity.y|   // 上边反弹（macOS Y 轴向上）
  if nextY ≥ maxY: nextY=maxY, velocity.y=-|velocity.y|  // 下边反弹
  if now ≥ nextTurnAt && random() < 0.45:
    velocity = chooseBreakRunVelocity()        // 随机改变方向
    nextTurnAt = now + random(350, 1200) ms    // 下次允许转向的时刻

  setPetFacing(velocity.x ≥ 0 ? "right" : "left")  // 朝向跟速度同向
  window.setFrameOrigin(nextX, nextY)
```

PawPal 速度换算：3.5~6.4 px/tick × 60 tick/s ≈ **210~384 px/s**。  
MalDaze 推荐缩放至 **~150~260 px/s**（tick 仍用 16 ms，速度乘以 0.7），在视网膜屏上看起来更自然。

---

## 四、设计决策

### 4.1 模式选择：并列而非替代

新增「跑屏」作为**与现有霸屏并列的休息模式**，通过设置开关切换，默认保留霸屏：

```
设置 → 休息打断风格
  ◉ 强（默认）：全屏渐暗 + 桌宠居中
  ○ 轻（跑屏）：桌宠在桌面自由漫游
```

`AppViewModel` 持有 `breakInterruptStyle` 属性，调用 `presentRest` 时根据该属性路由到不同入口。

### 4.2 窗口策略

跑屏模式**不扩全屏**，直接使用当前常态小窗（约 120×120 pt）：

- 窗口级别保持 `.floating`（不升为 `.screenSaver`）
- `WindowManager` 的 `BreakRunController`（新类）用 16ms 定时器调用 `NSWindow.setFrameOrigin` 驱动位置
- 结束后不需要"缩回"动画——窗口本就是小窗

### 4.3 鼠标屏蔽保留方式

`idleCursorTrackTimer` 逻辑**完整保留**，无需改动：

- 跑屏过程中窗口一直是小窗，`idleCursorTrackTimer` 继续按 10 Hz 检测光标是否在 50×50 区域
- 区域外 → `ignoresMouseEvents = true`（透传到桌面）
- 区域内 → `ignoresMouseEvents = false`（点击可被桌宠截获用于"提前结束"）

### 4.4 提前结束交互

- **单击桌宠**：立即结束休息，回调 `onDismissed`
- 菜单里"立即结束休息"按钮照常工作（调用 `dismissRestImmediately`）

### 4.5 倒计时显示

在 `PetStageView` 中新增一个小型倒计时标签（`breakRunCountdownLabel`），跑屏模式下显示在桌宠上方：

- 字体：SF Mono 16pt Bold，颜色白色+阴影
- 位置：视图中心偏上 12pt
- 内容：`M:SS` 格式（与现有 `countdownLabel` 复用同一格式函数）

---

## 五、新增 / 修改文件清单

### 5.1 新建：`MalDaze/WindowManager/BreakRunController.swift`

封装跑屏逻辑，从 `WindowManager` 分离，保持单一职责。

```swift
// 主要接口
@MainActor
final class BreakRunController {
    private(set) var isRunning = false

    /// 启动跑屏动画。window 为当前桌宠小窗。
    func start(window: NSWindow, duration: TimeInterval, onComplete: @escaping () -> Void)

    /// 强制停止（用户提前结束 / 应用退出）。
    func stop()
}
```

内部状态：
- `velocity: CGPoint`（当前速度矢量，从 PawPal `chooseBreakRunVelocity` 移植）
- `nextTurnAt: Date`
- `movementTimer: Timer?`（16 ms）
- `countdownTimer: Timer?`（1 s 更新倒计时）
- `endDate: Date`

### 5.2 修改：`MalDaze/WindowManager/WindowManager.swift`

新增方法 `presentBreakRun(duration:onDismissed:)`：

```swift
func presentBreakRun(duration: TimeInterval, onDismissed: @escaping () -> Void) {
    deskMenuPopover?.close()
    installPetWindowIfNeeded()
    dismissRestImmediately()          // 先清除可能残留的霸屏状态
    pendingDismiss = onDismissed
    // 通知 PetStageView 进入跑屏显示状态（小倒计时 + 跑步外观）
    stageView?.beginBreakRunDisplay(total: duration)
    // 不改变窗口大小，不改变级别，直接启动 BreakRunController
    breakRunController.start(window: window!, duration: duration) { [weak self] in
        self?.finishBreakRun()
    }
    applyMousePolicy()
}

private func finishBreakRun() {
    stageView?.cancelToIdle()
    let cb = pendingDismiss
    pendingDismiss = nil
    cb?()
}
```

修改 `dismissRestImmediately`：同时调用 `breakRunController.stop()` 确保跑屏也能被中断。

修改 `applyMousePolicy`：跑屏模式期间 `isInRestPhase` 保持参考 `stageView?.isInBreakRunPhase`。

### 5.3 修改：`MalDaze/WindowManager/PetStageView.swift`

新增状态标志与方法：

```swift
var isInBreakRunPhase: Bool { breakRunBeganAt != nil }

func beginBreakRunDisplay(total: TimeInterval)   // 启动小倒计时标签，切换为跑步外观
func cancelToIdle()                              // 已有，兼容跑屏模式清理
```

新增 `breakRunCountdownLabel: NSTextField`（16pt，位置在视图中部偏上）。  
`hitTest` 逻辑：跑屏期间与空闲期间相同——只有 50×50 区域截获点击，其余透传。

> 注意：`isInRestPhase`（现有霸屏判断）与 `isInBreakRunPhase`（跑屏判断）相互独立，不冲突。

### 5.4 修改：`MalDaze/PetDisplayMode.swift`

```swift
enum PetDisplayMode: Equatable {
    case restingRed        // 现有霸屏红狗
    case runningBlack      // 现有常态黑狗
    case pausedWhiteOutline
    case thinking
    case breakRunning      // 新增：跑屏模式（用 runningBlack 外观 + 小倒计时）
}
```

### 5.5 修改：`MalDaze/AppViewModel.swift`

```swift
enum BreakInterruptStyle: String {
    case fullscreen = "fullscreen"   // 现有霸屏
    case breakRun   = "breakRun"     // 跑屏（PawPal 风格）
}

@AppStorage(MalDazeDefaults.breakInterruptStyle)
private(set) var breakInterruptStyle: BreakInterruptStyle = .fullscreen
```

在触发休息处（`handleTimeState` / `startTestRestNow`）路由：

```swift
switch breakInterruptStyle {
case .fullscreen: windowManager.presentRest(duration: 5 * 60) { … }
case .breakRun:   windowManager.presentBreakRun(duration: 5 * 60) { … }
}
```

新增 `setBreakInterruptStyle(_ style: BreakInterruptStyle)`（供 UI 调用）。

### 5.6 修改：`MalDaze/MalDazeDefaults.swift`

```swift
static let breakInterruptStyle = "MalDaze.breakInterruptStyle"
```

### 5.7 修改：`MalDaze/MenuBarContentView.swift`

在「计时」卡片（`countdownSection`）内增加"休息风格"控件：

```swift
Picker("休息风格", selection: $vm.breakInterruptStyle) {
    Text("霸屏（强）").tag(AppViewModel.BreakInterruptStyle.fullscreen)
    Text("跑屏（轻）").tag(AppViewModel.BreakInterruptStyle.breakRun)
}
.pickerStyle(.segmented)
```

---

## 六、核心移植代码（Swift 伪码）

```swift
// BreakRunController.swift —— 直接移植自 PawPal movePetForBreakRun + chooseBreakRunVelocity

private func chooseVelocity() -> CGPoint {
    let speed = Double.random(in: 2.45...4.48) // PawPal 3.5~6.4 * 0.7 缩放
    let angle = Double.random(in: 0 ..< 2 * .pi)
    return CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
}

private func tick() {
    guard let win = window, !win.isDestroyed else { stop(); return }
    let bounds = win.frame
    let workArea = (NSScreen.screens.first { $0.frame.contains(bounds.origin) }
                    ?? NSScreen.main!).visibleFrame
    let winW = bounds.width, winH = bounds.height
    let minX = workArea.minX + 8
    let maxX = workArea.maxX - winW - 8
    let minY = workArea.minY + 8
    let maxY = workArea.maxY - winH - 8

    if Date() >= nextTurnAt, Double.random(in: 0...1) < 0.45 {
        velocity = chooseVelocity()
    }

    var nextX = bounds.minX + velocity.x
    var nextY = bounds.minY + velocity.y
    if nextX <= minX { nextX = minX; velocity.x =  abs(velocity.x) }
    if nextX >= maxX { nextX = maxX; velocity.x = -abs(velocity.x) }
    if nextY <= minY { nextY = minY; velocity.y =  abs(velocity.y) }
    if nextY >= maxY { nextY = maxY; velocity.y = -abs(velocity.y) }

    if Date() >= nextTurnAt {
        nextTurnAt = Date().addingTimeInterval(Double.random(in: 0.35...1.2))
    }

    win.setFrameOrigin(NSPoint(x: nextX, y: nextY))
    // 同步 applyMousePolicy（窗口位置变了，idleCursorTrackTimer 会在下一个 100ms 周期自动更新）
}
```

---

## 七、鼠标屏蔽逻辑不变说明

| 行为 | 霸屏模式（现有） | 跑屏模式（新增） |
|---|---|---|
| 窗口级别 | `.screenSaver` | `.floating`（不变） |
| `idleCursorTrackTimer` | 继续运行（检测 `petHitRectInWindowBaseCoordinates`） | **完全相同**，无需修改 |
| `ignoresMouseEvents` | 根据光标是否在 petHitRect 内动态切换 | **完全相同** |
| petHitRect | 休息全屏时扩大到宠物实际尺寸 | 跑屏时与空闲相同（50×50） |
| 点击桌宠 | 单击菜单 / 多次点击提前结束 | 单击直接结束跑屏休息 |
| 点击桌宠外 | 穿透到桌面 | 穿透到桌面（**完全相同**） |

---

## 八、实现顺序

1. `MalDazeDefaults.swift` — 添加 key（1 行）
2. `BreakRunController.swift` — 新建文件，实现移动算法
3. `PetStageView.swift` — 添加 `isInBreakRunPhase` + `beginBreakRunDisplay` + 小倒计时标签
4. `WindowManager.swift` — 接入 `BreakRunController`，实现 `presentBreakRun` / `dismissRestImmediately` 联动
5. `AppViewModel.swift` — 添加 `breakInterruptStyle` + 路由逻辑
6. `PetDisplayMode.swift` — 添加 `breakRunning` case
7. `MenuBarContentView.swift` — 添加风格选择 Picker
8. 构建验证，手动测试两种模式

---

## 九、测试要点

- [ ] 跑屏模式：点击设置切换后，触发休息，桌宠小窗在屏幕内随机弹跳，不扩全屏
- [ ] 速度与弹跳方向：碰到边缘后正确反弹，方向自然
- [ ] 倒计时标签：每秒更新，格式 `M:SS`，清晰可读
- [ ] 单击桌宠提前结束：跑屏中单击 50×50 区域，休息立即结束
- [ ] 鼠标穿透：在桌宠小窗透明区域点击，不拦截后面的窗口（`ignoresMouseEvents` 正常工作）
- [ ] 霸屏模式不受影响：切换回"强"模式后，现有全屏逻辑正常运行
- [ ] 多显示器：跑屏限制在当前显示器 `visibleFrame` 内，不跑出屏幕
- [ ] 应用退出 / 提前结束：`BreakRunController.stop()` 正确清理定时器，无内存泄漏
