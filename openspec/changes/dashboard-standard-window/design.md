## Context

当前架构（单进程 MalDaze，`.regular` activation policy）：

| 窗口 | 类型 | 行为 |
|------|------|------|
| 桌宠小窗 | `PetStageWindow` | 常态 floating；休息 `screenSaver` |
| Dashboard | `DeskPetDashboardPanel` (`NSPanel`) | floating、borderless、点外/失活关闭 |
| 设置窗 | `MalDazeSettingsWindowPresenter` | 标准 `NSWindow`（可参考） |

`presentRest` / `presentBreakRun` 当前会 `closeDeskMenuImmediate()`。用户要求霸屏时 Dashboard **不关**，仅被盖住。

已确认产品决策：

1. 不要点外面关；不要失活关。
2. Cmd+Tab 仍是单个 MalDaze App。
3. Dock 打开恢复上次窗口位置。
4. 休息霸屏不主动关 Dashboard。
5. 桌宠点击 **策略 A**：开/聚焦/toggle，不挪到桌宠旁。
6. 同一 App，不拆 bundle。

## Goals / Non-Goals

**Goals:**

- Dashboard 作为 MalDaze 内第二个标准 `NSWindow`，Mission Control 与 Cmd+` 可见。
- 桌宠左键、全局快捷键、`applicationShouldHandleReopen` 共用 `showDashboardWindow()` / `toggleDashboardWindow()`。
- Frame 持久化（类似 `idlePetOriginX/Y`）。
- 删除 global/local 外部点击 dismiss 监视器及 `NSApplication.didResignActive` dismiss。
- 进入全屏休息不再关闭 Dashboard。

**Non-Goals:**

- 第二个 `.app`、XPC、双 Dock 图标。
- 桌宠入口重新锚定（`DeskPetDashboardPanelLayout` 锚点逻辑废弃或仅用于无持久化时的首次默认 placement）。
- 改变 Dashboard 三栏布局、学习面板、Hermes 只读 UI 规则。
- 跑屏模式强制盖住 Dashboard（默认：跑屏桌宠仍为 floating，Dashboard 可能仍可操作；若后续要统一再开 change）。

## Decisions

### 1. 窗口类型：`NSWindow` 子类，非 `NSPanel`

**决定**：新增 `DeskPetDashboardWindow: NSWindow`（或复用命名 `DeskPetDashboardPanel` 改名），`styleMask: [.titled, .closable, .miniaturizable, .resizable]` 或 `.borderless` + 自绘 chrome（优先 **titled + unified** 以符合「像正常 App 窗口」；若视觉需保持圆角材质，可用 borderless + `canBecomeMain = true` + 正常 `collectionBehavior`）。

**理由**：`NSPanel` + `.floating` 在 Mission Control 中存在感弱；标准 window 的 `collectionBehavior` 含默认 managed 行为。

**备选**：保留 borderless + SwiftUI 圆角表面（现 `DeskPetDashboardView`）——采用 borderless 但 `level = .normal`、`collectionBehavior = [.managed, .fullScreenNone]`，`canBecomeMain = true`。

### 2. 统一入口 API

**决定**：`WindowManager` 暴露：

- `presentDashboardFromDeskPet()` — 策略 A，不传入 anchor
- `presentDashboardFromDockReopen()` — 同逻辑，语义别名或同一方法
- `presentDeskMenuFromGlobalShortcut()` — 改为调用统一 show/toggle

内部：`toggleDashboardWindow()`：不可见 → `makeKeyAndOrderFront` + 恢复持久化 frame；可见 → `orderOut`（保留 host）。

**理由**：避免三套分叉；桌宠 `presentDeskMenu(from:anchorRect:)` 签名可保留但忽略 anchor。

### 3. Frame 持久化

**决定**：`MalDazeDefaults` 增加 `dashboardWindowOriginX/Y`、`dashboardWindowWidth/Height`（或 origin + 仅持久化 size 由 `preferredContentSize` 推导）。加载时 clamp 到可见屏；无记录时首次居中于主屏 `visibleFrame`（非桌宠旁）。

**理由**：Dock 与桌宠入口一致；与用户对「记住上次位置」的期望对齐。

保存时机：窗口拖动结束、`windowDidResize`、隐藏前、应用终止（若已有桌宠 terminate 钩子可复用模式）。

### 4. 关闭与 Esc

**决定**：

- 移除：`addGlobalMonitor` / `addLocalMonitor` 外部点击 dismiss、`didResignActive` dismiss。
- 保留：`DeskPetDashboardEscapeRouter` + Esc 本地监视器（先 dismiss overlay，再关窗）。
- 增加：窗口关闭钮 / `windowShouldClose` → `orderOut` 而非 destroy；Cmd+W 经 `NSWindow` 标准路径。

### 5. 休息霸屏叠层

**决定**：删除 `presentRest`、`presentBreakRun`、`dismissRestImmediately` 中对 `closeDeskMenuImmediate()` 的**进入休息**调用（`dismissRestImmediately` 内若仅为清理休息态，可保留关面板与否需审视——用户要求休息时不关，故进入休息路径删除；用户主动结束休息时也不应关 Dashboard）。

**理由**：桌宠 `screenSaver` > Dashboard `.normal`，自然盖住。

### 6. Dock 再点

**决定**：`applicationShouldHandleReopen` 调用 `WindowManager.presentDashboardFromDockReopen()`（或经 `AppViewModel` 转发），`NSApp.activate`；**不再**仅 `orderFront` 桌宠窗。

桌宠小窗仍可通过点击桌宠区域单独前置（现有行为保留）。

### 7. 测试策略

**决定**：更新 `ControlPanelPresentationTests` 中所有 `NSPanel` / `closeDeskMenuPanelWithFade` / 外部点击 / 锚点 frame 断言；新增：

- 持久化键存在性
- `presentRest` 源文本不再含 `closeDeskMenuImmediate`（或仅非休息路径）
- `applicationShouldHandleReopen` 指向 dashboard 入口

## Risks / Trade-offs

- **[Risk] 与进行中的 `WindowManager` 本地改动冲突** → apply 前 `git status`，与用户确认合并 `rollout-scroll-month-date-picker` 等顺序。
- **[Risk] borderless 窗口在 Mission Control 缩略图不清晰** → 验收 MC；必要时加 titled 标题栏或 `titlebarAppearsTransparent`。
- **[Risk] 双窗口（桌宠 + Dashboard）在 Cmd+` 间切换困惑** → 可接受；与用户需求一致。
- **[Trade-off] 放弃桌宠旁弹出** → 策略 A 明确选择；减少 `DeskPetDashboardPanelLayout` 维护。
- **[Trade-off] 跑屏时 Dashboard 仍可能可操作** → 非本 change 范围。

## Migration Plan

1. 实现新 window 类型与持久化；切换 presentation 路径。
2. 删除 dismiss 监视器；调整休息入口。
3. 更新 AppDelegate Dock 行为。
4. 跑测试 + 手动 QA（MC、Dock、桌宠、Esc、休息霸屏、frame 记忆）。
5. Archive change 后合并 `desk-pet-controls` main spec。

## Open Questions

- 无阻塞项。窗口 chrome（系统标题栏 vs 纯 SwiftUI 圆角）可在实现时以 borderless + managed 先落地，MC 不满意再加透明标题栏。
