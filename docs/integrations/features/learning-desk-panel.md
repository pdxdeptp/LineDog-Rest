# 学习助手桌宠面板（learning-desk-panel）

Hub：[../hermes.md](../hermes.md) · SSOT 边界：[learning-calendar.md](./learning-calendar.md) · 主 spec：`openspec/specs/learning-desk-panel/` · 总目录：[../ROADMAP.md](../ROADMAP.md) §7 Phase 6

> **状态：** v1 已归档 · L3 **MANUAL_QA 通过**（2026-06-08）· **未归档**  
> **定位：** MalDaze **展示层 + 轻交互**；Hermes **`schedule.py` 执行引擎**；飞书 **重操作入口**（排课、对话、智能模式）  
> **取代：** 嵌入版 `assistant_backend` + 全功能 `AssistantPanelView`；ROADMAP 原 M-C1「只读卡」/ M-C2「不做」

### 交付分档（scope A）

| 档位 | OpenSpec | 范围 |
|------|----------|------|
| **v1** | [`archive/2026-06-08-add-learning-desk-panel`](../../openspec/changes/archive/2026-06-08-add-learning-desk-panel/) | L1 Today + L2 complete/move + H-L2 dry-run |
| **v1.1 · L3** | [`add-learning-desk-panel-l3`](../../openspec/changes/add-learning-desk-panel-l3/) | 增删、Week、FSEvents、review、每日上限设置、H-L3/H-L4 |
| **X7 · 项目** | [`add-learning-project-status`](../../openspec/changes/add-learning-project-status/) | 项目 Tab、`status`、`set-deadline`（US-10）、跨 Tab 刷新、标色、跳转今日 |
| **X8 · 日程** | [`add-learning-calendar-view`](../../openspec/changes/add-learning-calendar-view/) | 日程 Tab（月历 + Agenda）、`schedule-range`、取代周负荷 |
| **X9 · 今日核心** | [`extend-learning-today-core`](../../openspec/changes/extend-learning-today-core/) | 双预算、完成进度、`progress`、滚入置顶、实际时长、按项目分组 |
| **X10 · 今日导航** | [`extend-learning-today-navigation`](../../openspec/changes/extend-learning-today-navigation/) | 行动卡、明天预告、warning 点击、源链接、repack 预览 |
| **X11 · 今日 todo** | [`add-learning-today-todo`](../../openspec/changes/add-learning-today-todo/) | MalDaze 本地随手记、顺延、历史；不同步提醒/Hermes |
| **X11.1 · todo 贴底** | [`fix-today-todo-scroll-pin-threshold`](../../openspec/changes/fix-today-todo-scroll-pin-threshold/) | compact/pinned 双模式；溢出即贴底 |

延后索引：[learning-desk-panel-followup.md](./learning-desk-panel-followup.md)

---

## 0. 一句话

打开桌宠 Dashboard **中栏**，一眼看到「今天要做什么、还剩几条、是否超预算」，并能 **勾选完成 / 推迟 / 改日期**；所有写操作只调 `schedule.py`，不在 Swift 复刻级联或第二份 SSOT。

---

## 1. 问题与选型

### 1.1 为什么现有入口不够

| 入口 | 优点 | 缺口 |
|------|------|------|
| 飞书对话 | 排课、完成、move、晨报 | 无一屏纵览；要问才有列表 |
| ~~飞书日历~~ | ~~扫周视图~~ | **已废弃**（2026-06-08）；学习域不再投影；旧 App 内格子需手动清理 |
| 晨报 cron | 推送摘要 | 非实时；不能点完成 |

你要的是 **Mac 前常驻可视化**，不是再建一套独立学习系统，也不是把日历当 SSOT。

### 1.2 与 v2 嵌入版的分工

| 维度 | v2 嵌入（已移除） | 本设计 |
|------|-------------------|--------|
| SSOT | SQLite + `assistant_backend` | `~/.hermes/data/learning-assistant/projects.json` |
| 算法 | App 内 REST + Python 后端 | **`schedule.py` 唯一** |
| UI 范围 | 6 Tab 全功能（排课、对话、智能模式） | **Today 为主** + 可选 Week 负荷 |
| LLM | App 内 URL 拆解、对话调整 | **仍在飞书 Hermes** |
| 通信 | HTTP localhost | **子进程 CLI**（无 FastAPI） |

继承 v2 的 **体验纪律**（定盘星 D13、今日为主 D8、勾选 D7、滚入角标 D28、超额标红 D11、move 预览 D25），放弃 **数据与算法自治**。

### 1.3 为什么不用外部日历做面板数据源

- 学习域 **已移除** 飞书日历投影（`remove-feishu-learning-calendar`）；SSOT 仅为 `projects.json`
- 外部日历无 `duration_minutes`、日预算、复习链、`auto_roll_days`
- 面板读 JSON（经 `today` / `schedule-range`）与飞书对话 **同一路径**，避免第二套真相

---

## 2. 架构

```
┌──────────────────────────────────────────────────────────────────┐
│  MalDaze Dashboard                                                │
│  左 · EventKit 日待办 │ 中 · LearningDeskPanel │ 右 · 桌宠控制      │
└───────────────────────────────┬──────────────────────────────────┘
                                │ Process: python3 schedule.py <cmd>
                                │ env: HERMES_HOME=~/.hermes
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│  Hermes 执行引擎                                                  │
│  schedule.py · projects.json · profile.json · daily_log.json      │
└───────────────────────────────┬──────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│  飞书 Hermes（保留）                                              │
│  plan · 对话 move · validate · 智能模式 · 晨报                    │
└──────────────────────────────────────────────────────────────────┘
```

### 2.1 三层职责

| 层 | 做 | 不做 |
|----|-----|------|
| **MalDaze 面板** | 读 today、渲染、发起已存在子命令、错误展示 | 写 JSON、算级联、URL 拆解、LLM |
| **schedule.py** | SSOT、rollover、级联、复习链 | UI、外部日历投影 |
| **飞书** | 自然语言、plan、复杂批量、无 Mac 时的兜底 | 替代面板成为唯一可视化 |

---

## 3. v2 用户故事映射

面板 **覆盖** 日常使用与轻调整；其余 **仍走飞书** 或 **不做**。

| US | 故事 | 面板 | Hermes 飞书 |
|----|------|:----:|:-----------:|
| US-1 | 每日学习上限 | 顶栏 + 日程（**小时**）；**MalDaze 设置 → 学习面板** 可调 | 同步写 `profile.json` `daily_capacity_minutes` |
| US-2~5 | URL 排课、审阅、确认 | — | ✅ plan + 对话 |
| **US-6** | 今日视图 | ✅ **主入口** | today 对话 |
| **US-7** | 勾选完成 | ✅ complete | complete |
| US-8 | 自动滚入次日 | 显示结果（rollover 后） | rollover |
| **US-9** | 改日期 + 级联 | ✅ move + 预览 | move |
| US-10 | 改项目截止日 | ✅ 项目 Tab（active only，`set-deadline`） | `set-deadline` / 飞书对话 |
| **US-11** | 超额 / 落后标红 | ✅ 顶栏 + warnings | validate |
| US-12 | 项目总览 | 🟡 项目 Tab + US-10 deadline（待 MANUAL_QA） | `status` / `set-deadline` |
| **US-13** | 日程 / 负荷 | ✅ **日程** Tab（月历 + Agenda；小时 + 可配置上限） | `schedule-range`（`week-load` 保留兼容） |
| US-14 | 项目归档 | 只读展示 | 自动 |
| **US-15** | 增删单任务 | L3 insert/remove | insert/remove |
| US-16 | 对话调整 | — | ✅ |
| US-17~19 | 智能模式 | — | ✅ |
| US-20 | 放空日 | 显示 `is_rest_day` | add-rest-day |
| **US-21** | 已滚 N 天角标 | ✅ `auto_roll_days` | 晨报 |

---

## 4. Dashboard 布局

### 4.1 恢复三栏

当前为 **两栏**（`DashboardLayout` 仅 `remindersColumnWidth` + `controlsColumnWidth`）。本设计 **加回中栏**：

```
┌─────────────┬─────────────────────────────┬─────────────┐
│ 计划 300pt   │ 学习面板 flex min 360pt      │ 控制 300pt   │
│ EventKit    │ LearningDeskPanelView       │ 计时/休息…   │
└─────────────┴─────────────────────────────┴─────────────┘
```

- `minimumContentWidth` 增加中栏最小宽度  
- 窗体宽度逻辑不变：仍按屏幕可见区域 clamp

### 4.2 中栏线框（Today · L1/L2）

```
┌─ 学习 · 6月7日 周六 ─────────────── [↻] ─┐
│ 预算 2.5 小时 / 5 小时  ⚠ 超额            │  ← study.total vs 设置上限（小时），红色
│ 休息日中栏显示「今日休息」时可弱化列表      │  ← is_rest_day
├─────────────────────────────────────────┤
│ ⚠ lc_review 落后 3 天                    │  ← warnings[]
├─────────────────────────────────────────┤
│ 正课                                     │
│ ☐ 1  LC Review · Ch3        45m  [⋯]    │
│     已滚 2 天                             │  ← auto_roll_days ≥ 1
│ ☐ 2  LC Review · Ch4        60m  [⋯]    │
├─────────────────────────────────────────┤
│ 复习                                     │
│ ☐ 3  🔁 Ch2 复习            30m  [⋯]    │
├─────────────────────────────────────────┤
│ 今日无任务 → 「去飞书 Hermes 排课」提示    │
└─────────────────────────────────────────┘

行内 [⋯]：记录时长并完成 · 推迟到明天 · 选日期 · 删除(L3)

**X9/X10 今日增强**：功能清单、手工 QA、造数、JSON 对照、排障 → [learning-today-x9-x10.md](./learning-today-x9-x10.md)。简表勾选见 [MANUAL_QA.md](../MANUAL_QA.md) M-L12-core / M-L12-nav。
```

**Week Tab（L3）**：未来 28 天每日已排负荷条形图，文案为 **小时**（如 `2.5 小时 / 5 小时`）；超 MalDaze 设置的每日上限标红。上限默认 **5 小时**，在 **MalDaze 设置 → 学习面板** 调节（1–12 小时，步进 0.5），保存后写入 Hermes `profile.json` 的 `daily_capacity_minutes`。

**项目 Tab（X7）**：

```
┌─ 今日 | 日程 | 项目 ──────────────── [↻] ─┐
│ LC Review          active                  │
│ 截止 [📅 6/30  修改] · 1/27 · 4%           │  ← 按钮打开 sheet；过期红 / 7 天内橙
│ 待办 Ch4 · 6/8 · 45m                       │  ← Hermes next_task（队列首条 pending）
├────────────────────────────────────────────┤
│ Old Course         paused   （弱化）        │
│ 无待办任务                                  │
└────────────────────────────────────────────┘
```

- 展示 `status` 返回的 **全部** 项目；non-active 弱化，active 置顶。
- `next_task` **不等于**「今日下一项」或「最近日期」—— 仅为 JSON 任务列表中第一条 `pending`。
- 点行（非截止日控件）→ 切 **今日** Tab 并高亮同 `project_id` 首条 pending（若有）。
- **active** 项目：点 **「📅 日期  修改」** → sheet 先 `set-deadline --dry-run` 预览 → 确认后正式 apply。Hermes **默认全局协调**所有活跃项目未完成课程（共享 `daily_capacity_minutes`、动态均衡 cadence）；面板展示受影响项目数、各项目 cadence 摘要与移动节数；`feasible: false` 时禁用确认（US-10）。
- 今日 / 项目写操作成功后后台刷新 status，避免切 Tab 仍见旧进度。

### 4.3 中栏不做

- 嵌入飞书聊天、Smart mode 开关  
- URL 输入、guided clarification、审阅时间线  
- 拖拽 Gantt（可 backlog；v1 用日期 picker + move）

### 4.4 今日 todo（MalDaze 本地 · X11）

Hermes 任务列表下方独立区块 **「今日 todo」**，替代「打开备忘录手敲」：

| 维度 | 行为 |
|------|------|
| SSOT | `~/Library/Application Support/MalDaze/today-todo.json` |
| 添加 | 区块内输入框 + 回车；无 Sheet |
| 完成 | 勾选后保留 + 删除线，折叠在「已完成 N」 |
| 顺延 | 未完成项跨日打开面板时滚到今天；可显示「自 M/d 顺延」 |
| 历史 | 「历史」Sheet：过去日期的已完成项，按日分组 |
| 隔离 | 不计入正课/复习预算；↻ 只刷 Hermes；不同步左栏计划 / 提醒事项 |
| 布局 | Hermes 任务与 todo 区可拖动分隔。输入框在视图树中只有一个固定挂载点；由 `TodayTodoLayoutPolicy` 根据列表实测高度、输入行实测高度与当前 Geometry 一次性解析 **measuring / compact / pinned**。`capacity = max(contentAreaHeight - safeDraftHeight - spacing, 0)`，`safeDraftHeight = max(实测整行, 同步 draft 编辑器高度, 28pt)`。边界 tolerance 固定 **0.5pt**：`listHeight <= capacity - 0.5` → compact（viewport = 实高）；超出 → pinned（viewport = capacity，列表可滚动，输入贴底）。缺少完整测量或列表宽度与 live width 相差 > 0.5pt 时进入 measuring（安全 capacity viewport、禁用滚动）。任意来源转入 pinned 无动画滚到底部锚点，转入 compact 无动画归顶部；同 mode 下 resize 保留当前 scroll offset；pinned 下继续添加导致列表变长时自动滚到底部。**未完成条目 ≥ 2 时，长按文字区（350ms）后拖动排序**：三阶段动画（抓起 scale/shadow → 拖动 overlay 1:1 跟手 + 邻行 spring 让位 2pt → 松手 spring 落定后写 `sortIndex`），无 ≡ 手柄；拖动中用 `previewOrder`，不写 JSON；pointer 与行 frame 共用 list top-left 坐标系。内容区小于 draft 行高 + spacing 时 list viewport = 0；mode/viewport 变化不触发新的 focus token。 |

OpenSpec：[`add-learning-today-todo`](../../openspec/changes/add-learning-today-todo/) · [`fix-today-todo-scroll-pin-threshold`](../../openspec/changes/fix-today-todo-scroll-pin-threshold/)

**手动 QA（X11.1）**

1. 默认窗口：添加短条目、换行条目、rollover hint，应在**第一份完整测量**后刚溢出即 pinned，无需再添加或拖动。
2. 分别通过成功添加、分隔线缩小、横向换行、完成组展开进入 pinned：均应无动画滚到底部锚点。
3. pinned 内拖动分隔线或缩放窗口（纵横）：保留当前 scroll offset，输入焦点与文本稳定。
4. pinned 内滚动后删除/完成/折叠至 compact：无动画归顶部，draft 紧跟列表。
5. 多行 draft 增至 120pt、超过 120pt 内部滚动、空提交/失败提交、480×360 最小窗口与极端分隔比例：无负 frame、无输入框重建。
6. 控制台无新增 “Preference tried to update multiple times per frame” 警告。

---

## 5. 读路径

### 5.1 标准序列（与 SKILL / 晨报一致）

```bash
export HERMES_HOME="$HOME/.hermes"
python3 "$HERMES_HOME/scripts/schedule.py" rollover
python3 "$HERMES_HOME/scripts/schedule.py" today
```

| 时机 | 行为 |
|------|------|
| Dashboard 打开 | rollover → today |
| 用户点 ↻ | 同上 |
| 写操作成功 | 再跑 today（rollover 可选，至少 today） |
| 后台 | **不轮询**；回面板或手动刷新 |

可选 L3：`FSEvents` 监听 `projects.json`（debounce 1s）触发 today。

### 5.2 `today` 响应（面板解析子集）

```json
{
  "date": "2026-06-07",
  "is_rest_day": false,
  "pending_count": 2,
  "pending": [
    {
      "index": 1,
      "task_id": "lc_review_task_3",
      "title": "Ch3",
      "project_id": "lc_review",
      "project_name": "LC Review",
      "duration_minutes": 45,
      "task_type": "study",
      "scheduled_date": "2026-06-07"
    }
  ],
  "study": {
    "total_minutes": 148,
    "budget": 300
  },
  "review": { "total_minutes": 30, "budget": 60 },
  "warnings": [
    { "project_name": "lc_review", "days_behind": 3 }
  ]
}
```

**`auto_roll_days`：** L3 起 `pending[]` 可含 `auto_roll_days`；否则从 `study.tasks[].task` / `review.tasks` 按 `task_id` 合并。

**每日上限：** CLI 仍输出 `study.budget` / `week-load` 的 `budget`（分钟）。MalDaze 面板以 **设置中的小时上限** 为准展示与标红，并与 `profile.json` 同步（默认 300 分钟 = 5 小时）。

### 5.3 不采用的路径（v1）

- `today_learning.json` 第二契约（ROADMAP C6 继续暂缓）  
- 直读飞书日历  
- MalDaze 内嵌 SQLite 缓存 SSOT

---

## 6. 写路径

所有写：**spawn `schedule.py`** → 解析 stdout JSON → `error` 则 fail-loud。

| 用户动作 | UI | CLI | 备注 |
|----------|-----|-----|------|
| 勾选完成 | Checkbox | `complete --task-id <id>` | 复习链在 Hermes |
| 推迟到明天 | 菜单项 | `move --task-id <id> --new-date <tomorrow>` | 文案「推迟」，无 postpone 命令 |
| 改日期 | DatePicker | `move --new-date YYYY-MM-DD` | 同项目后置级联 |
| 删除 | 确认后 | `remove --task-id <id>` | 不级联 |
| 插入 | 轻表单 | `insert --project-id … --title … --duration N --date …` | 不级联 |
| 复习通过/失败 | L3 按钮 | `review --task-id … --result passed\|failed` | — |
| 改项目截止日 | 项目 Tab · active | `set-deadline --dry-run` → `set-deadline` | **默认全局重排**所有活跃项目；响应含 `repack_scope`、`feasible`、`affected_project_ids[]`、`project_cadences[]`、`changes[].project_id`；不可行时非 dry-run 不落盘 |

环境：`HERMES_HOME=~/.hermes`；`python3` 路径与 Smart Reminder 子进程策略一致。

### 6.1 move 预览（v2 D25 纪律）

`move` 当前 **无 `--dry-run`**，执行即落盘。L2 需要二选一：

| 方案 | 说明 |
|------|------|
| **A（推荐）** | Hermes 增 `move --dry-run`：只输出 `changes[]`，不写盘 |
| B | L2 仅确认「目标日期」单行文案；级联列表执行后在 toast 展示（弱于 v2） |

预览 UI 示例（方案 A）：

```
将移动「Ch3」→ 6月8日
同项目还将移动 4 项：
  · Ch4  6/7 → 6/8
  · Ch5  6/8 → 6/9
  …
[取消]  [应用]
```

### 6.2 仍走飞书

`plan`、`validate` 全量、`add-rest-day`、跨项目批量、对话「整体推迟一周」、智能模式提议。

---

## 7. Swift 模块（建议）

```
MalDaze/LearningDeskPanel/
  LearningDeskPanelView.swift       // 中栏容器 + Today/Week/项目 Tab
  LearningProjectStatusView.swift   // X7 项目 Tab（status + set-deadline）
  LearningTaskRow.swift             // 行 + 菜单 + review 按钮
  LearningScheduleView.swift        // 日程（月历 + Agenda）
  LearningWeekLoadView.swift        // （遗留，Tab 已移除）
  LearningInsertTaskSheet.swift     // 添加任务
  LearningMovePreviewSheet.swift    // move 确认
  LearningProjectsFileWatcher.swift // FSEvents
  LearningCapacityFormatting.swift  // 分钟 ↔ 小时展示
  HermesLearningProfileStore.swift  // 读写 profile daily_capacity_minutes
  LearningDeskPanelViewModel.swift  // @MainActor 状态
  HermesScheduleCLI.swift           // 协议 + Process 实现
  HermesScheduleModels.swift        // Codable：TodayResponse, MoveResponse…
```

**设置：** `MalDaze 设置 → 学习面板` · `MalDazeDefaults.learningDailyCapacityHours`（默认 5.0）→ 同步 `~/.hermes/data/learning-assistant/profile.json`。

- `HermesScheduleCLI` 可注入 mock，供单元测试  
- ViewModel **不** 持有 `projects.json` 写权限  
- 错误态：脚本缺失、非零退出、`error` 字段 → 中栏错误卡 + `HERMES_HOME` 提示

---

## 8. 错误与空态

| 情况 | UI |
|------|-----|
| `schedule.py` 不存在 | 错误卡 + 安装 Hermes 指引 |
| `pending_count == 0` 且非休息日 | 「今日无学习任务」 |
| `is_rest_day` | 「今日休息」+ 可选隐藏列表 |
| move 拒绝（进过去 / 级联进过去） | 展示 `error` 原文 |
| 无学习项目 | 空状态指引「Hermes 对话发链接 / 帮我安排学习」（面板不提供建项目） |
| 写操作中 | 行级 disabled + 进度 |

---

## 9. Hermes 侧配合（非阻塞 / 可并行）

| ID | 项 | 阻塞面板？ |
|----|-----|------------|
| H-L1 | `rollover` JSON 滚入 | 否 · **已实现**（无日历投影） |
| H-L2 | `move --dry-run` | **阻塞 L2 完整预览** |
| H-L3 | `pending[]` 带 `auto_roll_days` | 否（可从 study.tasks 合并） |
| H-L4 | `week-load --days 28` JSON | 仅阻塞 Week Tab |

---

## 10. 实施分期

### L1 · Today 只读（M-L1）

- 三栏布局 + `LearningDeskPanelView`  
- rollover + today 展示；无写操作  
- 验收：与终端 `schedule.py today` 一致

### L2 · 快操（M-L2）

- complete；move（含 H-L2 预览）；↻ 刷新  
- 验收：勾选后 JSON `completed`；move 与飞书同命令结果一致

### L3 · 增强（M-L3）

- insert / remove；Week 负荷（小时 + 可配置上限）；FSEvents；review passed/failed  
- 每日学习上限：**MalDaze 设置**（默认 5h）→ `profile.json`  
- insert 项目列表：`schedule.py status` 全部 `active` 项目（非仅今日任务）

### OpenSpec（实施前）

- 新 capability：`learning-desk-panel`  
- 修订 `hermes-learning-calendar` / `desk-pet-controls`：允许 MalDaze CLI 写 complete/move  
- 撤销 learning-calendar 中「不在 Dashboard 完成回写」的 ⏸ 表述

---

## 11. 验收清单（L2 完成）

1. 打开 Dashboard 中栏可见今日列表，与 `schedule.py today` 一致  
2. 顶栏显示当日负荷 **小时 / 设置上限小时**，超额红色  
3. `auto_roll_days ≥ 1` 显示「已滚 N 天」  
4. `warnings` 展示落后项目  
5. 勾选完成 → task `status: completed` → 刷新后消失  
6. 推迟到明天 → `move` 级联与飞书一致；有预览确认  
7. 左栏提醒、右栏桌宠 **无回归**

---

## 12. 非目标

- 恢复 `assistant_backend`、SQLite、App 内 LLM 排课  
- 飞书日历作 SSOT  
- Swift 复刻 move 级联 / 复习生成 / D24 初始排布  
- 学习任务迁入苹果提醒事项  
- 面板替代飞书成为唯一操作入口  

---

## 13. 待拍板

| ID | 问题 | 建议 |
|----|------|------|
| OQ-1 | 恢复三栏是否接受更宽 Dashboard？ | ✅ 是 |
| OQ-2 | move 预览是否等 H-L2 `--dry-run`？ | ✅ 是 |
| OQ-3 | Week Tab 是否进 L1？ | ❌ 放 L3 |
| OQ-4 | insert 多项目时如何选 project？ | `status` 拉全部 active；菜单 Picker |
| OQ-6 | 每日上限改哪里？ | MalDaze 设置 → 学习面板；同步 Hermes profile |
| OQ-5 | 是否做 `today_snapshot.json`？ | ❌ v1 子进程即可 |

---

## 14. 文档索引

| 文档 | 用途 |
|------|------|
| `openspec/specs/learning-desk-panel/spec.md` | 验收需求（canonical） |
| [learning-assistant-v2.md](../../openspec/learning-assistant-v2.md) | **已废弃** — 历史 explore 草稿，勿引用 |
| [remove-learning-assistant/design.md](../../openspec/changes/remove-learning-assistant/design.md) | 为何删掉嵌入版 |
| [learning-calendar.md](./learning-calendar.md) | JSON SSOT；飞书日历投影已移除 |
| [ROADMAP.md](../ROADMAP.md) §7 | M-L* / H-L* 全表 |
| `~/.hermes/skills/learning-assistant/SKILL.md` | 飞书编排 |
| `~/.hermes/scripts/schedule.py` | 执行引擎 |
