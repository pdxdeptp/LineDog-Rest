# MenuBarContentView 布局审计

> 最后更新：2026-04-16

## 一、宿主上下文（两种，行为不同）

| | MenuBarExtra（菜单栏图标点击） | NSPopover（桌宠点击） |
|---|---|---|
| 定义位置 | `LineDogApp.swift:9` `.menuBarExtraStyle(.window)` | `WindowManager.swift:648–651` |
| 窗口尺寸控制 | SwiftUI 根据 `.frame(minHeight:)` 自适应 | **固定** `pop.contentSize = NSSize(width:668, height:560)` |
| 顶部 safe area | 有（`.regular` 激活策略下约 28–52 pt，macOS 版本间有差异） | **没有**（popover 箭头在底部） |
| 激活策略 | `.regular`（有 Dock 图标） | 继承宿主窗口 |

**关键差异**：两个上下文的顶部 safe area 高度不同，但共用同一套 `MenuBarContentView` 布局代码，这是所有顶部留白问题的根源。

---

## 二、历史积累的高度控制层（发现时共 4 层）

下面是曾经同时存在、互相干扰的机制：

### 层 1：`topPadding`（`MainPanelChrome.topPadding`）
- 位置：`body` 里的 HStack `.padding(.top, N)`
- 作用：所有内容整体向下偏移 N pt
- 历史值：最初 52，后改 36

### 层 2：两个 `ScrollView` 上的 `.ignoresSafeArea(edges: .top)`
- 位置：左栏提醒列表 ScrollView 和右栏 ScrollView
- 原意：防止 macOS 在 ScrollView 内容顶部自动添加 safe area inset
- **副作用**：ScrollView 会向上"扩展"到 safe area 区域，等效抵消 topPadding 的减少
- **这是导致「改 topPadding 没效果」的直接原因**：ScrollView 向上吸的距离正好等于被减少的 topPadding

### 层 3：`reminderListPanelHeight` 动态高度系统
- 位置：`ReminderListHeightKey`（PreferenceKey）+ `GeometryReader` + `@State reminderListContentHeight` + computed `reminderListPanelHeight`
- 作用：通过 GeometryReader 量出左栏列表内容高度，动态设置 ScrollView 的 `maxHeight`
- **初始状态**：`reminderListContentHeight == 0` → `reminderListPanelHeight == 520`（硬编码上限）
- **副作用**：产生「Bound preference tried to update multiple times per frame」console warning

### 层 4：`minHeight: 556` 与 `contentSize: 560` 双重约束
- `body.frame(minHeight: 556)`：SwiftUI 层面的最小高度
- `pop.contentSize = (668, 560)`：AppKit 层面的固定尺寸（仅 NSPopover 上下文）
- 两者数值接近但语义不同，会导致布局在两个上下文里行为不一致

---

## 三、清理后的单层架构（当前代码状态）

清理后只保留一个机制控制顶部间距：

```
OuterVStack
  └─ HStack
       ├─ remindersSidebar
       │    └─ VStack (spacing:8)
       │         ├─ 「计划」标题、说明、Picker（固定高度约 130pt）
       │         └─ ScrollView [maxHeight: .infinity]  ← 填满剩余高度
       └─ mainControlsColumn
            └─ ScrollView [maxHeight: .infinity]       ← 填满剩余高度
```

**单一顶部间距控制**：`MainPanelChrome.topPadding`（当前 16 pt），**不再有** ignoresSafeArea 抵消它。

### 布局属性一览（清理后）

| 属性 | 值 | 位置 |
|---|---|---|
| 顶部留白 | `topPadding = 16` | `MainPanelChrome` |
| 底部留白 | `bottomPadding = 12` | `MainPanelChrome` |
| 左右内边距 | `horizontalPadding = 12` | `MainPanelChrome` |
| 提醒列表 ScrollView 高度 | `.infinity`（填满） | `remindersSidebar` |
| 右栏 ScrollView 高度 | `.infinity`（填满） | `mainControlsColumn` |
| 外层最小高度 | `minHeight: 556` | `body` |
| ignoresSafeArea | 无（已全部移除） | — |

---

## 四、已知遗留问题

### NSPopover 固定尺寸（`WindowManager.swift:651`）
```swift
pop.contentSize = NSSize(width: 668, height: 560)
```
这个固定尺寸会覆盖 SwiftUI 的自适应布局。如果内容高度不足 560pt，底部会出现空白；如果超出，内容会被截断。

**建议**：改为在 popover 首次显示后根据 SwiftUI 视图的 intrinsic size 动态设置，或保持与 `minHeight: 556` 数值对齐。

### MenuBarExtra 与 NSPopover 的 safe area 不一致
MenuBarExtra 可能有顶部 safe area（约 28–44 pt，取决于 `.regular` 激活策略和 macOS 版本）；NSPopover 没有。当前 `topPadding = 16` 在 NSPopover 上下文效果正常，在 MenuBarExtra 上下文可能偏紧。

**建议**：用 `safeAreaInsets.top > 0 ? topPaddingCompact : topPaddingRegular` 区分两种场景，或接受视觉上的细微差异。

---

## 五、修改指引

如需调整顶部留白，**只需改一处**：

```swift
// LineDog/MenuBarContentView.swift
private enum MainPanelChrome {
    static let topPadding: CGFloat = 16  // ← 只改这里
}
```

不要再往 ScrollView 上加 `.ignoresSafeArea`、不要引入新的 PreferenceKey 高度测量系统。这些机制会互相抵消，导致改了没有效果。
