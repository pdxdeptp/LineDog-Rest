# Design · fix-today-todo-scroll-pin-threshold

## Context

`LearningDeskPanelView` 已通过 `DashboardVerticalFractionSplit` 为 Hermes 任务区和本地 todo 区分配实时高度。当前未提交实现又在 `TodayTodoSection` 内保存 `contentAreaHeight`、`measuredListHeight`、`measuredDraftRowHeight` 与 `isDraftPinned`，并从 Preference、条目数量、完成组展开、`sectionHeight`、draft 高度和 Geometry 等多个回调调用 `reevaluatePinMode()`。

这些回调不是同一轮布局的原子快照。已确认的失败序列包括：

1. 提交时以 `oldListHeight + estimatedRowHeight` 乐观进入 pinned。
2. 条目数量回调使用旧列表高度退回 compact。
3. Preference 返回新高度后才再次进入 pinned。

分隔线拖动存在同类序列：`sectionHeight` 已更新时，`contentAreaHeight` 仍可能是上一帧值。当前布局还把 `draftFieldRow` 在 ScrollView 内外两个父节点间迁移，并在 overlay 中隐藏复制整棵 `todoEntries`；相同 `.id` 不能保证跨父节点保留同一个 `NSViewRepresentable` 实例。

约束：目标平台为 macOS 13；不改变 todo JSON、Hermes/EventKit 契约、Dashboard 分隔线组件或已有 `sectionHeight` 接口。Dashboard 允许缩到 480×360，因此必须定义 todo 内容区小于输入行时的退化行为，而不能承诺物理上不可能的完整可见性。

## Goals / Non-Goals

**Goals:**

- 新内容首次放不下时，在下一份完整内容测量返回后自动进入 pinned，不需要再增加条目或继续拖动。
- 拖动分隔线和纵向 resize 直接使用当前 todo 内容区 Geometry；横向 resize 导致换行时先进入安全 measuring 状态，再使用新宽度下的测量。
- compact/pinned 切换不迁移、销毁或重建 draft 输入框。
- 所有模式、viewport 和滚动开关只由纯 policy 派生；事件回调不得写 remembered pin mode。
- 支持换行 todo、rollover hint、行内编辑、完成组展开和 24–120pt 多行 draft。
- 明确初次测量、无效测量、滚动 offset、极小空间和焦点行为，使 apply 不需要临场决定。

**Non-Goals:**

- 修改 todo 持久化、日期滚动、软删除、历史、完成排序或输入框 120pt 内部滚动上限。
- 修改 Hermes 任务、预算、刷新、上下分隔比例或 `DashboardVerticalFractionSplit`。
- 新增 todo lower pane 的绝对最小高度；物理空间不足时使用本设计的退化规则。
- 通过 drag freeze、延时器、固定 todo 行高、更大 tolerance 或隐藏列表副本掩盖错误测量。
- 为模式切换增加动画；布局更新保持无隐式动画。
- 顺手处理 Dashboard 其它布局或全局 Swift concurrency warnings。

## Decisions

### D1 · 文件与职责边界固定

实现使用三个明确边界，不留“实现时再决定”的文件拆分：

- `TodayTodoLayoutPolicy.swift`
  - `TodayTodoLayoutMode`：`.measuring / .compact / .pinned`
  - `TodayTodoLayoutResolution`：`mode`、`listViewportHeight`、`listScrollEnabled`
  - `TodayTodoLayoutPolicy.resolve(...)`：唯一布局解析入口
- `TodayTodoContentLayout.swift`
  - 固定 ScrollView / draft / Spacer 结构
  - 真实内容测量与聚合 Preference
  - ScrollView offset 归位
- `TodayTodoSection.swift`
  - store、header/error、todo 行、draft 内容、编辑与聚焦业务
  - 只把 `todoEntries` 和 `draftFieldRow` 提供给布局壳，不再持有布局 mode 或内容区高度

`TodayTodoContentLayout.swift` 必须加入 MalDaze target；不把新布局重新塞回 300+ 行的 section 文件。

### D2 · draft 使用单一稳定挂载点

布局树固定为：

```text
GeometryReader (live width / height)
└─ ScrollViewReader
   └─ VStack(spacing: 2)
      ├─ ScrollView(showsIndicators: false)
      │  └─ topAnchor + todoEntries + bottomAnchor
      ├─ draftFieldRow
      └─ Spacer(minLength: 0)
```

硬性约束：

- ScrollView 永远只包含 top anchor、`todoEntries` 和 bottom anchor，不包含 draft。
- `draftFieldRow` 在源代码和运行时结构中都只有一个挂载点，不使用条件分支或 `.id` 搬家。
- ScrollView 使用明确的 `.frame(height: resolution.listViewportHeight)`，不用 `maxHeight` 让 VStack 二次决定高度。
- draft 的垂直 layout priority 高于 ScrollView，保证测量过渡和极小空间先压缩列表 viewport。
- 外层 VStack 明确占满当前 Geometry 高度，Spacer 只吸收 compact 的剩余空间。
- mode/viewport 变化不包裹 `withAnimation`，也不添加隐式 `.animation`。

### D3 · 精确 policy 合约

常量：

```text
layoutTolerance = 0.5pt
draftRowFallbackHeight = 28pt
listRowSpacing = 2pt
```

`resolve` 输入：

- `listHeight: CGFloat?`
- `draftRowHeight: CGFloat?`
- `draftMinimumHeight: CGFloat`（由现有同步 `draftFieldHeight` 传入）
- `measuredListWidth: CGFloat?`
- `liveWidth: CGFloat`
- `availableHeight: CGFloat`
- spacing 与 tolerance

所有有限数值先 clamp 到非负；NaN/Infinity 视为缺失测量。定义：

```text
safeAvailable = max(availableHeight, 0)
safeDraft = max(valid(draftRowHeight) ?? 0, valid(draftMinimumHeight) ?? 0, 28)
capacity = max(safeAvailable - safeDraft - spacing, 0)
fitCapacity = max(capacity - 0.5, 0)
widthMatches = abs(measuredListWidth - liveWidth) <= 0.5
```

解析表：

| 条件 | mode | listViewportHeight | listScrollEnabled |
|---|---|---:|---|
| list/draft 测量缺失、无效，或测量宽度与 live width 不匹配 | measuring | capacity | false |
| `listHeight <= fitCapacity` | compact | `min(listHeight, capacity)` | false |
| `listHeight > fitCapacity` | pinned | capacity | `capacity > 0 && listHeight > 0` |

0.5pt tolerance 只允许最多提前 0.5pt pinned；pinned viewport 始终使用完整 capacity，因此 draft 位于底部。`draftMinimumHeight` 不是 todo 行高估算，只是 AppKit draft 已同步报告的编辑器高度下界；整行 Preference 仍是稳定状态的最终测量。没有 hysteresis 或 `currentlyPinned` 输入，也不保存 `isDraftPinned`。

### D4 · 完整测量 snapshot 的格式与提交规则

`TodayTodoContentLayout` 定义一个 `Equatable` 聚合值：

```text
TodayTodoMeasuredGeometry
  listSize: CGSize?
  draftRowHeight: CGFloat?
```

同一个 PreferenceKey 由两个真实子视图贡献：

- 实际 ScrollView 中的 `todoEntries.background(GeometryReader)` 贡献 `listSize`。
- 唯一 `draftFieldRow.background(GeometryReader)` 贡献 `draftRowHeight`。

`reduce` 只合并非 nil 字段，所以 list/draft 发射顺序不影响结果。外层只保留一个 `.onPreferenceChange`：

- 只有 listSize 和 draftRowHeight 都存在、有限且非负（draft 必须 `> 0`）时才提交为最新 snapshot。
- 不完整或无效 snapshot 不覆盖上一份完整 snapshot；首次尚无完整 snapshot 时 policy 为 `.measuring`。
- `PreferenceKey.defaultValue` 使用不可变 `static let`，避免为新代码增加 concurrency warning。

列表必须在实际可见宽度下 `.frame(maxWidth: .infinity, alignment: .leading)` 后测量。禁止 overlay/hidden/fixed-size 副本。直接测量 ScrollView 内容是本 change 的确定方案；若强制的 macOS 13 hosting test 证明无法获得完整内容高度，apply 必须停止并更新 OpenSpec，不得由实现者自行切换到隐藏副本或自定义 `Layout`。

### D5 · 更新时序与“立即”的定义

Preference 天生在一次布局测量之后回传，因此规范中的“立即”定义为：

- 内容或宽度变化后，下一份完整 snapshot 到达即自动应用正确 mode。
- 不需要第二次添加、继续拖动、点击、延时器或其它用户事件。
- 允许一个内部 measuring/旧 snapshot 布局周期，但 draft 必须保持单一挂载点且可见范围优先；不得出现持续到下一次用户操作的错误模式。

具体路径：

- **纵向 divider/window resize**：list/draft 固有高度仍有效，当前 Geometry height 直接重新 resolve，不等待 Preference。
- **横向 resize**：若 snapshot list width 与 live width 相差超过 0.5pt，进入 measuring；新宽度 snapshot 返回后 resolve。
- **条目增删、完成组、行内编辑换行**：旧 snapshot 最多用于一个测量周期；真实 list 自动发出新完整 snapshot。
- **draft 增高**：现有 `draftFieldHeight` 同步作为 safeDraft 下界，立即缩小 capacity；新整行 snapshot 返回后校正最终高度。draft 高 layout priority 是第二层保护。达到 120pt 后由 draft 内部 ScrollView 继续滚动，外层高度不再增长。

### D6 · ScrollView offset 规则

由于 ScrollView 永久存在，必须明确旧 offset：

- 任何 mode 转入 `.compact` 时，通过固定 top anchor 无动画滚到顶部，确保 compact 内容从首行开始且 draft 紧跟真实列表末尾。
- 任何 mode 转入 `.pinned` 时，通过固定 bottom anchor 无动画滚到底部，使最新末行与 draft 邻接区域可见。
- 锚定规则只看目标 mode，不读取触发来源；新增、编辑、完成组、分隔线和窗口 resize 一律相同，不建立 submit/divider 特判。
- mode 保持 `.pinned` 而仅 viewport 尺寸变化时保留系统当前 offset；只有 mode 实际发生转换才执行锚定。
- mode change 的 scroll action 监听纯 `resolution.mode`，但不得反向写布局 mode。

### D7 · Focus 与 draft 值语义

- mode/viewport 变化不得递增 `draftFocusRequestToken`，也不得调用新的 focus retry。
- 若 draft 在变化前是 window first responder，同一个 `DraftTextView` 对象在变化后仍应是 first responder；用户主动点别处、切换窗口或 window 失去 key 不属于布局需要抢回焦点的场景。
- 普通 resize、删除、完成或展开变化保持当前 draft 文本。
- Return 提交导致布局变化时，保持的是提交后的值：成功提交按现有行为清空 draft，并保留输入焦点；不得为了“保留文本”恢复刚提交的内容。
- 提交失败或空白提交不改变文本、布局数据或焦点。

### D8 · 极小内容区退化规则

完整可见保证适用于 `availableHeight >= measuredDraftRowHeight + spacing`。小于该值时物理空间不足，规则为：

- list viewport clamp 为 0，scroll disabled。
- draft 保持唯一挂载点和高 layout priority，位于剩余内容区顶部；外层 lower pane 仍可能按物理边界裁切它。
- 不产生负 frame、不把 draft 移入列表、不修改分隔比例。
- 空间恢复到可容纳 draft 后，使用同一 snapshot 自动恢复 compact/pinned。

若产品希望任何 Dashboard 尺寸下都完整显示 draft，需要另行批准“为 learning lower pane 增加绝对最小高度”的 P1 scope；本 change 不隐式修改共享 split 组件。

### D9 · 测试与验收矩阵

**Policy 精确样例（spacing=2、draft=28、available=200，capacity=170、fitCapacity=169.5）：**

- list=nil → measuring / viewport 170 / scroll false
- list=169.5 → compact / viewport 169.5 / scroll false
- list=169.51 → pinned / viewport 170 / scroll true
- list=220 → pinned / viewport 170 / scroll true
- available=20 → pinned / viewport 0 / scroll false

**自动测试：**

1. policy 表格、非法数值、宽度 match/mismatch、draft minimum 高于/低于实测值、draft 120pt 上限输入。
2. Preference reduce 的 list-first/draft-first、完整/不完整/无效 snapshot。
3. `NSHostingView` 固定尺寸测试：真实 ScrollView 内容为 100pt 和 220pt 时分别得到完整内容高度；viewport 限制不得改变报告的 intrinsic list height。
4. presentation：一个 draft 挂载点、一个 todoEntries、固定 top/bottom anchor、明确 `.frame(height:)`、无旧 mode 状态/估算/隐藏副本/drag state。
5. 回归序列：add、删除回 compact、分隔线触发 pinned、纵横 resize、多行 draft、完成组展开和 inline edit 换行；所有进入 pinned 的来源得到相同 bottom anchor。

**手动 QA：**

- 默认窗口和 480×360 最小窗口。
- 默认、最小、最大分隔比例。
- 短条目、换行条目、rollover hint、collapsed/expanded completed group。
- 连续添加到边界，观察无需第二次用户事件即完成切换。
- 分别通过新增和分隔线缩小进入 pinned，确认二者都无动画滚到底部；pinned 内继续 resize 不重复强制锚定。
- pinned 滚动后删除到 compact，确认 offset 无动画归顶。
- resize/切换时持续输入，验证 first responder 与提交后清空语义。
- 检查控制台无新增 “Preference tried to update multiple times per frame” 警告。

## Risks / Trade-offs

- **Preference 有一个测量周期延迟** → 规范明确 measuring 过渡；draft 单挂载且优先，错误模式不得持续到下一用户事件。
- **真实 ScrollView 内容测量在 macOS 13 不符合预期** → mandatory hosting test 是实现门禁；失败即回到 OpenSpec，不允许静默选替代架构。
- **0.5pt 边界提前 pinned** → 明确 policy 样例；最多一个 Retina 物理像素，避免底部亚像素裁切。
- **永久 ScrollView 保留旧 offset** → mode 转 compact 强制无动画归顶，mode 转 pinned 强制无动画到底；mode 不变时不干预用户 offset。
- **极小窗口无法物理容纳 draft** → 明确 viewport=0 的退化行为；绝对 lower minimum 不在本 scope。
- **现有 tasks 曾被勾选但手动 QA 失败** → 所有被推翻任务保持未完成，QA 通过前不得重新勾选。

## Migration Plan

1. 先写失败 policy、snapshot、hosting 与 presentation 回归测试。
2. 实现确定的 policy 类型与聚合 snapshot。
3. 新建并接入 `TodayTodoContentLayout.swift`。
4. 删除旧 pin state、事件重算器、隐藏副本、条件 draft 与估算。
5. 完成 offset/focus/极小空间行为并运行 review、build、manual QA。

回滚仅涉及 `TodayTodoSection.swift`、`TodayTodoContentLayout.swift`、`TodayTodoLayoutPolicy.swift`、project source membership 与相关测试；不涉及 JSON 或 defaults 迁移。

## Open Questions

无。
