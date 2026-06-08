# 学习助手桌宠面板（learning-desk-panel）

Hub：[../hermes.md](../hermes.md) · SSOT 边界：[learning-calendar.md](./learning-calendar.md) · v2 母本：[../../openspec/learning-assistant-v2.md](../../openspec/learning-assistant-v2.md) · 总目录：[../ROADMAP.md](../ROADMAP.md) §7 Phase 6

> **状态：** 设计定稿（2026-06-07）  
> **定位：** MalDaze **展示层 + 轻交互**；Hermes **`schedule.py` 执行引擎**；飞书 **重操作入口**（排课、对话、智能模式）  
> **取代：** 嵌入版 `assistant_backend` + 全功能 `AssistantPanelView`；ROADMAP 原 M-C1「只读卡」/ M-C2「不做」

### 交付分档（scope A）

| 档位 | OpenSpec | 范围 |
|------|----------|------|
| **v1 · 当前实施** | [`add-learning-desk-panel`](../../openspec/changes/add-learning-desk-panel/) | L1 Today + L2 complete/move + H-L2 dry-run |
| **v1.1 · 延后** | [`add-learning-desk-panel-l3`](../../openspec/changes/add-learning-desk-panel-l3/) | 增删、Week、FSEvents、review、H-L3/H-L4 |
| **日历 · 延后** | [`fix-learning-rollover-calendar`](../../openspec/changes/fix-learning-rollover-calendar/) | H-L1 rollover 日历 patch |

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
| 飞书日历 | 扫周视图 | 与 JSON 易不同步；无时长/超容量；不能勾选完成 |
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

### 1.3 为什么不用飞书日历做面板数据源

- 日历是 **软投影**，`rollover` 等路径可能未 patch 事件 → 格子与 JSON 不一致  
- 无 `duration_minutes`、日预算、复习链、`auto_roll_days`  
- 面板读 JSON（经 `today`）与飞书对话 **同一路径**，避免第三套真相

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
│  可选：飞书日历投影（complete delete / move patch）                  │
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
| **schedule.py** | SSOT、rollover、级联、复习链、日历 patch | UI |
| **飞书** | 自然语言、plan、复杂批量、无 Mac 时的兜底 | 替代面板成为唯一可视化 |

---

## 3. v2 用户故事映射

面板 **覆盖** 日常使用与轻调整；其余 **仍走飞书** 或 **不做**。

| US | 故事 | 面板 | Hermes 飞书 |
|----|------|:----:|:-----------:|
| US-1 | 每日学习上限 | 顶栏展示 `study.budget` | 改 `profile.json` |
| US-2~5 | URL 排课、审阅、确认 | — | ✅ plan + 对话 |
| **US-6** | 今日视图 | ✅ **主入口** | today 对话 |
| **US-7** | 勾选完成 | ✅ complete | complete |
| US-8 | 自动滚入次日 | 显示结果（rollover 后） | rollover |
| **US-9** | 改日期 + 级联 | ✅ move + 预览 | move |
| US-10 | 改项目截止日 | — | 对话 / 后续 CLI |
| **US-11** | 超额 / 落后标红 | ✅ 顶栏 + warnings | validate |
| US-12 | 项目总览 | v1.1 `status` 只读 | status |
| **US-13** | 周负荷 | v1.1 Week Tab | — |
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
│ 预算 148 / 90 min  ⚠ 超 58 min          │  ← study.total vs budget，红色
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

行内 [⋯]：推迟到明天 · 选日期 · 删除(L3)
```

**Week Tab（L3）**：未来 14–28 天每日已排分钟条形图；超 `daily_capacity` 标红。

### 4.3 中栏不做

- 嵌入飞书聊天、Smart mode 开关  
- URL 输入、guided clarification、审阅时间线  
- 拖拽 Gantt（可 backlog；v1 用日期 picker + move）

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
    "budget": 90
  },
  "review": { "total_minutes": 30, "budget": 60 },
  "warnings": [
    { "project_name": "lc_review", "days_behind": 3 }
  ]
}
```

**`auto_roll_days`：** `pending` 行未含该字段；从 `study.tasks[].task.auto_roll_days` / `review.tasks` 按 `task_id` 合并（或 Hermes 小改：并入 `pending`，见 §9 H-L2）。

### 5.3 不采用的路径（v1）

- `today_learning.json` 第二契约（ROADMAP C6 继续暂缓）  
- 直读飞书日历  
- MalDaze 内嵌 SQLite 缓存 SSOT

---

## 6. 写路径

所有写：**spawn `schedule.py`** → 解析 stdout JSON → `error` 则 fail-loud。

| 用户动作 | UI | CLI | 备注 |
|----------|-----|-----|------|
| 勾选完成 | Checkbox | `complete --task-id <id>` | 复习链、日历 delete 在 Hermes |
| 推迟到明天 | 菜单项 | `move --task-id <id> --new-date <tomorrow>` | 文案「推迟」，无 postpone 命令 |
| 改日期 | DatePicker | `move --new-date YYYY-MM-DD` | 同项目后置级联 |
| 删除 | 确认后 | `remove --task-id <id>` | 不级联 |
| 插入 | 轻表单 | `insert --project-id … --title … --duration N --date …` | 不级联 |
| 复习通过/失败 | L3 按钮 | `review --task-id … --result passed\|failed` | — |

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
  LearningDeskPanelView.swift      // 中栏容器 + Tab
  LearningTodayView.swift          // 列表 + 顶栏
  LearningTaskRow.swift            // 行 + 菜单
  LearningMovePreviewSheet.swift   // move 确认
  LearningDeskPanelViewModel.swift // @MainActor 状态
  HermesScheduleCLI.swift          // 协议 + Process 实现
  HermesScheduleModels.swift       // Codable：TodayResponse, MoveResponse…
```

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
| `calendar_errors` 非空 | 次要提示；以 JSON `ok` / 任务日期为准 |
| 写操作中 | 行级 disabled + 进度 |

---

## 9. Hermes 侧配合（非阻塞 / 可并行）

| ID | 项 | 阻塞面板？ |
|----|-----|------------|
| H-L1 | `rollover` 同步飞书日历 patch | 否（面板不读日历） |
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

- insert / remove；Week 负荷；FSEvents；review passed/failed  
- 可选 `status` 项目条只读

### OpenSpec（实施前）

- 新 capability：`learning-desk-panel`  
- 修订 `hermes-learning-calendar` / `desk-pet-controls`：允许 MalDaze CLI 写 complete/move  
- 撤销 learning-calendar 中「不在 Dashboard 完成回写」的 ⏸ 表述

---

## 11. 验收清单（L2 完成）

1. 打开 Dashboard 中栏可见今日列表，与 `schedule.py today` 一致  
2. 顶栏显示 `study.total_minutes / budget`，超额红色  
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
| OQ-4 | insert 多项目时如何选 project？ | 默认唯一 active；否则行内 Picker |
| OQ-5 | 是否做 `today_snapshot.json`？ | ❌ v1 子进程即可 |

---

## 14. 文档索引

| 文档 | 用途 |
|------|------|
| [learning-assistant-v2.md](../../openspec/learning-assistant-v2.md) | US、D 决策、定盘星 |
| [remove-learning-assistant/design.md](../../openspec/changes/remove-learning-assistant/design.md) | 为何删掉嵌入版 |
| [learning-calendar.md](./learning-calendar.md) | SSOT、日历策略 |
| [ROADMAP.md](../ROADMAP.md) §7 | M-L* / H-L* 全表 |
| `~/.hermes/skills/learning-assistant/SKILL.md` | 飞书编排 |
| `~/.hermes/scripts/schedule.py` | 执行引擎 |
