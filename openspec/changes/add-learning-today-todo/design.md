# Design · add-learning-today-todo

## Context

- **Dashboard 中栏** `LearningDeskPanelView` 今日 Tab 已展示 Hermes `schedule.py today` 任务（正课/复习、预算、完成/推迟等）。
- **左栏「计划」** 读 EventKit 提醒事项；**Hermes `+` insert** 需选项目、时长、日期——均不适合「打开备忘录手敲一条」的轻量备忘。
- **用户定稿（2026-06-18）**：
  - 区块名：**今日 todo**
  - 未完成 **顺延** + **历史可查**
  - 已完成：**保留 + 删除线**，默认折叠
  - 输入框：**随 ScrollView 滚动**（非 sticky）

## Goals / Non-Goals

**Goals:**

- MalDaze 本地 JSON 为今日 todo 唯一 SSOT；打开今日 Tab 即可增删改勾。
- 未完成项跨日自动滚到今天；历史 Sheet 按日查看过去已完成项。
- 与 Hermes 任务列表视觉相邻但数据/刷新/预算完全隔离。
- Hermes 不可用或休息日时今日 todo 仍可用。

**Non-Goals:**

- 同步 EventKit / 备忘录 / Hermes insert。
- 计入正课/复习预算；拖拽排序；提醒时间；升级为 Hermes 任务。
- 跨设备 iCloud 同步；设置页开关（v1）。
- Hermes CLI 或 `projects.json` 变更。

## Decisions

### D1 · 存储：Application Support JSON

| 选项 | 结论 |
|------|------|
| A：`~/Library/Application Support/MalDaze/today-todo.json` | **选用** — 列表可增长、易备份调试，与读 JSON 先例一致 |
| B：UserDefaults | 否决 — 不适合可变长列表 |
| C：Hermes 新文件 | 否决 — 非学习域，违反用户「不和 Hermes 混」意图 |

```json
{
  "version": 1,
  "entries": [{
    "id": "UUID",
    "title": "string",
    "dateISO": "YYYY-MM-DD",
    "rolledFromDateISO": "YYYY-MM-DD|null",
    "isCompleted": false,
    "createdAt": "ISO8601",
    "completedAt": "ISO8601|null",
    "sortIndex": 0
  }]
}
```

每次 mutating 操作 **原子写**（write temp + replace），与项目内其它 JSON 写盘模式对齐。

### D2 · 顺延语义（lazy roll on load）

| 触发 | 动作 |
|------|------|
| 今日 Tab `onAppear` / `.task` | `rollForwardIfNeeded()` |
| 本地 `Calendar` 检测到 today 变化（可选：Store 持 `lastSeenTodayISO`） | 同上 |

规则：`!isCompleted && dateISO < today` → 设 `rolledFromDateISO = rolledFromDateISO ?? dateISO`，`dateISO = today`，写盘。

**不在 midnight 后台定时器里 roll** — 仅用户可见路径触发，减少 App 后台复杂度。

### D3 · 历史

- **入口**：区块标题行右侧「历史」→ `TodayTodoHistorySheet`。
- **内容**：`dateISO < today && isCompleted`，按 `dateISO` 分组倒序。
- **不含**：未完成的历史日条目（已顺延到今天主列表）。
- **操作**：只读浏览 + 单条删除（v1）；无批量清空（可 follow-up）。

### D4 · UI 嵌入点

在 `LearningDeskPanelView.loadedBody` 的 `ScrollView` 内：

```
todayTaskList
→ TodayTodoSection          ← 新增
→ tomorrowPreview (若有)
```

输入框在 Section 底部，**inside ScrollView**（用户定稿）。

**已完成区**：Section 内 `DisclosureGroup`「已完成 N」，项用 `.strikethrough` + 次要色。

**顺延提示**：未完成行 subtitle `自 M/d 顺延`（来自 `rolledFromDateISO`）。

### D5 · 架构：独立 Store，不并入 LearningDeskPanelViewModel

| 组件 | 职责 |
|------|------|
| `TodayTodoStore` | 读写 JSON、roll、CRUD、history 查询 |
| `TodayTodoSection` | 列表 + 输入 + 折叠已完成 |
| `TodayTodoHistorySheet` | 历史 Sheet |
| `TodayTodoRow` | 单行 checkbox / 菜单 |

`LearningDeskPanelView` 持 `@StateObject private var todayTodoStore`。

**理由**：ViewModel 已 tightly coupled Hermes CLI；今日 todo 纯本地，分离可避免 refresh/rollover 误触 Hermes 路径，也满足 spec「Panel does not reimplement learning scheduling」的边界——今日 todo **不是** learning scheduling。

### D6 · 与 Hermes 刷新解耦

- 学习面板 ↻ 仅 `viewModel.refreshCurrentTab`；**不**调用 `todayTodoStore.reload()`（除非未来显式需求）。
- `TodayTodoStore.loadAndRollForward()` 在 Section `.task` / `onAppear` 独立调用。
- FSEvents `projects.json` watcher **不**刷新今日 todo。

### D7 · 错误降级

- JSON 损坏 / 不可读：Section 内 caption 错误 + 输入 disabled；**不**阻塞 Hermes 任务区。
- 写盘失败：caption 橙色提示，内存态保留待重试（v1 可简化为仅提示）。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 与 Hermes 任务视觉混淆 | 独立 section 标题「今日 todo」+ 无项目/时长元数据 |
| 顺延在多日未开 App 后一次滚到今天 | 符合预期；`rolledFromDateISO` 保留来源 |
| JSON 与 App 版本不兼容 | `version` 字段；未知 version 读失败显式错误 |
| ScrollView 内输入框需滚到底才见 | 用户显式选择；hint 文案说明回车添加 |

## Migration Plan

- **新装**：首次写盘创建空 `{ "version": 1, "entries": [] }`。
- **升级**：无旧数据；无 Hermes 迁移。
- **回滚**：删除新 Swift 文件并 revert 嵌入点；`today-todo.json` 可保留无害。

## Open Questions

（无 — 用户已确认命名、顺延、历史、已完成、输入框行为。）
