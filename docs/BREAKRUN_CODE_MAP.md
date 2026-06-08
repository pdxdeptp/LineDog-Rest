# BreakRun 功能全代码地图

> 本文档梳理「跑屏休息」（breakRun）功能所涉及的所有代码位置、调用链与数据流，
> 用于精准定位 Bug 和制定修复方案。

---

## 1. 涉及文件总览

| 文件 | 作用 |
|---|---|
| `AppViewModel.swift` | 应用状态协调；决定何时/如何触发休息；处理提前结束回调 |
| `WindowManager.swift` | 窗口生命周期；跑屏入口 `presentBreakRun()`；结束流程 `finishBreakRun()` / `dismissRestImmediately()` |
| `BreakRunController.swift` | 纯运动引擎：60 Hz 定时移动小窗，边界弹跳 |
| `PetStageView.swift` | 桌宠视觉与点击逻辑；含跑屏倒计时标签、多击退出逻辑 |

---

## 2. 完整调用链

### 2a. 启动跑屏

```
AppViewModel.startTestRestNow()
  └── presentRestWithCurrentStyle(duration: 5*60) 
        └── windowManager.presentBreakRun(duration:onDismissed:)
              ├── 清理残留状态（stop/cancelToIdle/setWindowLevel）
              ├── idleFrameBeforeRest = win.frame          ← 记录起始位置
              ├── stage.beginBreakRunDisplay(total:)       ← PetStageView 切换显示态
              ├── breakRunController.start(window:duration:onComplete:) ← 启动 60Hz 移动
              └── startBreakRunCountdownTimer(duration:)  ← 1Hz 倒计时 + 60s 后遮罩
```

`AppViewModel` 真实引擎触发（非测试）：
```
handleTimeState(.resting) 
  └── presentRestWithCurrentStyle(duration: 5*60, onDismissed: {})
        └── windowManager.presentBreakRun(...)
```

### 2b. 结束跑屏——路径 A：定时自然到期

```
BreakRunController.tick()
  └── Date() >= endDate → cb?()
        └── WindowManager.finishBreakRun()      ← 有回位动画
              ├── hideBreakRunShield()
              ├── stopBreakRunCountdownTimer()
              ├── breakRunController.stop()
              ├── cb?()  ← pendingDismiss 回调
              │     └── AppViewModel.startTestRestNow 的闭包：
              │           ├── testRestActive = false
              │           ├── resumeEngineRestOverlayIfNeeded()  ⚠️ 可能立即重启
              │           └── syncPetDisplayMode()
              └── NSAnimationContext.runAnimationGroup  ← 1s 缓动回位
                    completionHandler:
                      ├── stageView?.cancelBreakRunToIdle()
                      ├── window?.level = .floating
                      └── applyMousePolicy()
```

> ⚠️ **已知问题**：`cb?()` 里的 `resumeEngineRestOverlayIfNeeded()` 若引擎仍处于休息段，
> 会立即再次调用 `presentBreakRun()`，该调用内部执行 `breakRunController.stop()` +
> `stageView?.cancelToIdle()`，直接覆盖/取消了下面的 `NSAnimationContext` 动画。

### 2c. 结束跑屏——路径 B：用户提前结束（3 次点宠物 / 10 次点倒计时）

```
PetStageView.mouseUp
  └── breakRunBeganAt != nil
        └── inPet → breakRunPetClickCount >= 3 → onRestPetDoubleClickEndRest?()
              └── AppViewModel.endRestEarlyFromDeskPet()
                    └── windowManager.dismissRestImmediately()  ← 无回位动画！
                          ├── hideBreakRunShield()
                          ├── stopBreakRunCountdownTimer()
                          ├── breakRunController.stop()
                          ├── stageView?.cancelToIdle()
                          ├── setWindowLevel(resting: false)
                          ├── callback?()
                          └── if isApproximatelyIdleSized: applyMousePolicy (直接停在原地)
```

> ⚠️ **已知问题**：`dismissRestImmediately()` 完全没有回位动画，宠物停在最后弹跳到的位置。

---

## 3. 状态变量汇总

### WindowManager 跑屏相关状态

| 变量 | 类型 | 用途 | 生命周期 |
|---|---|---|---|
| `breakRunController` | `BreakRunController` | 60Hz 移动引擎 | 单例，start/stop 复用 |
| `breakRunCountdownTimer` | `Timer?` | 1Hz 更新倒计时 | presentBreakRun 创建，stop/dismiss 时销毁 |
| `breakRunShieldWorkItem` | `DispatchWorkItem?` | 60s 后展示遮罩的延迟任务 | presentBreakRun 创建，stop/dismiss 时取消 |
| `breakRunShieldWindow` | `NSPanel?` | 半透明全屏遮罩 | 60s 后创建，dismiss 时销毁 |
| `idleFrameBeforeRest` | `NSRect?` | 跑屏前的起始窗框，用于回位 | presentBreakRun 记录，finishBreakRun 读取 |
| `pendingDismiss` | `(() -> Void)?` | 结束时通知 AppViewModel 的回调 | presentBreakRun 存储，finish/dismiss 时调用 |

### PetStageView 跑屏相关状态

| 变量 | 类型 | 用途 |
|---|---|---|
| `breakRunBeganAt` | `Date?` | 非 nil = 正在跑屏模式中 |
| `breakRunTotal` | `TimeInterval` | 总时长（仅 `cancelBreakRunToIdle` 时清零）|
| `breakRunPetClickCount` | `Int` | 3 次点宠物退出：当前计数 |
| `breakRunPetLastClickAt` | `TimeInterval` | 上次点宠物的时间戳 |
| `breakRunCountdownClickCount` | `Int` | 10 次点倒计时标签退出：当前计数 |
| `breakRunCountdownLastClickAt` | `TimeInterval` | 上次点倒计时的时间戳 |
| `breakRunCountdownLabel` | `NSTextField` | 跑屏倒计时标签（含约束） |

### PetStageView 倒计时标签约束（当前代码）

```swift
// 初始化时（init frame:）设置，创建后不再动态更新
NSLayoutConstraint.activate([
    breakRunCountdownLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
    breakRunCountdownLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: +38)
])
// 字体大小：14pt（霸屏 countdownLabel 是 96pt）
```

---

## 4. 两个现存 Bug 的根因

### Bug 1：倒计时不在屏幕左下角，而是随宠物移动，且字体太小

**根因**：`breakRunCountdownLabel` 存在于 `PetStageView` 内部，而 `PetStageView` 是 132×132 的小窗，
该窗口由 `BreakRunController` 在屏幕上弹跳。标签的约束相对于小窗居中，所以随小窗一起移动。

要固定在屏幕左下角，有两条路：

- **方案 A（推荐）**：在 `WindowManager` 里创建一个独立的全屏透明 `NSPanel`（类似 `breakRunShieldWindow`），
  专门承载左下角倒计时标签，更新由现有 1Hz 定时器驱动。
  
- **方案 B**：沿用现有标签，但在每次 `BreakRunController.tick()` 中根据屏幕坐标反算标签的位置。
  实现复杂且误差大，不推荐。

字体大小：改为 `ofSize: 48, weight: .semibold`（或与霸屏 96pt 一致），加背景色便于阅读。

### Bug 2：跑屏结束后宠物不回到出发前位置

**根因有两条，二选一都会触发**：

**2-A（提前结束路径）**：用户点击 3 次宠物 → `endRestEarlyFromDeskPet()` → `dismissRestImmediately()`。
该函数没有回位动画，宠物停留在弹跳结束时的位置。`idleFrameBeforeRest` 存储的起始位置被遗弃。

**2-B（定时到期路径）**：`finishBreakRun()` 里先执行 `cb?()` 通知 AppViewModel，
AppViewModel 的回调触发 `resumeEngineRestOverlayIfNeeded()`，若引擎仍在休息段，
立即再次调用 `presentBreakRun()`，该调用执行 `breakRunController.stop()` + `stageView?.cancelToIdle()`，
在 `NSAnimationContext` 还未执行时就把窗口状态重置，动画被跳过。

---

## 5. 修复方案（精准最小改动）

### Fix 1：倒计时改为独立固定窗口

在 `WindowManager` 新增：
```swift
private var breakRunCountdownPanel: NSPanel?
private var breakRunCountdownTextField: NSTextField?
```

- `presentBreakRun()` 时创建全屏透明 panel，放 `NSTextField` 在左下角（leading 32, bottom 32）。
- `startBreakRunCountdownTimer` 的 1Hz 回调同时更新 `breakRunCountdownTextField`。
- `PetStageView.breakRunCountdownLabel` 恢复隐藏（或彻底移除）。
- 面板加入 `hitTest` 逻辑（或在 `WindowManager.hitTest` 里处理点击计数到 10 次退出）。
- `hideBreakRunShield()` / `finishBreakRun()` / `dismissRestImmediately()` 中同步销毁该 panel。

字体：`NSFont.monospacedDigitSystemFont(ofSize: 48, weight: .semibold)`，加深色背景/圆角。

### Fix 2：两条路径都加回位动画

**2-A**：在 `dismissRestImmediately()` 中，若当前是跑屏模式且 `idleFrameBeforeRest` 不为 nil，
加与 `finishBreakRun()` 相同的 `NSAnimationContext` 回位动画。

**2-B**：在 `finishBreakRun()` 中，把 `cb?()` 移到 `NSAnimationContext` 的 `completionHandler` 内部，
保证动画完成后再通知 AppViewModel，避免 `resumeEngineRestOverlayIfNeeded()` 提前打断动画。

```swift
// 修改后的 finishBreakRun()
private func finishBreakRun() {
    hideBreakRunShield()
    stopBreakRunCountdownTimer()
    breakRunController.stop()
    // ⚠️ 不在这里调 cb?()，移到动画完成后
    
    let target = resolveReturnTarget()
    NSAnimationContext.runAnimationGroup({ ctx in
        ctx.duration = 1.0
        ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        window?.animator().setFrame(target, display: true)
    }, completionHandler: { [weak self] in
        guard let self else { return }
        stageView?.cancelBreakRunToIdle()
        window?.level = .floating
        syncContentViewToWindowLayout()
        applyMousePolicy()
        window?.orderFrontRegardless()
        persistIdlePetFrame(target)
        // 动画完成后再通知 AppViewModel
        let cb = self.pendingDismiss
        self.pendingDismiss = nil
        cb?()
    })
}
```

---

## 6. 注意事项

- `dismissRestImmediately()` 同时处理霸屏和跑屏，加回位动画时需用 `isApproximatelyIdleSized` 判断是否处于跑屏（窗口本就是小窗），避免对霸屏模式造成干扰。
- 倒计时独立 panel 的点击计数（10 次退出）需要在 `WindowManager` 层处理，不再依赖 `PetStageView.hitTest`；`PetStageView` 中对应的 `breakRunCountdownLabel.frame.contains(local)` 逻辑可同步移除。
- 遮罩 `breakRunShieldWindow` 与倒计时 panel 应保持层级一致（或倒计时 panel 在遮罩之上）。
