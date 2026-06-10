# 个人助理栈重构总目录

> **用途**：把 Hermes ↔ MalDaze ↔ 飞书 的分工收敛成可逐项推进的清单。  
> **维护处（canonical）**：本文件；Hermes 侧只维护 manifest 索引行，不复制正文。  
> **状态图例**：`⬜ 未开始` · `🟡 进行中` · `✅ 已完成` · `⏸ 暂缓` · `❌ 不做`

**最后更新**：2026-06-08

**同步关系**：本文件 = 总进度看板；实现细节见 `docs/integrations/features/*.md` 与 `openspec/specs/`。**每完成一项任务或变更范围，应回改本文件对应行的状态。**

---

## 进度总览

| Phase | 名称 | 状态 | 说明 |
|-------|------|------|------|
| 0 | 文档 + OpenSpec + scope-decision | ✅ | `unify-personal-assistant` 已归档 |
| 1 | 域 B · 到时强提醒 | ✅ | cron + bell；`integration_smoke` 绿 |
| 2 | 域 A · 日待办 | ✅ | Hermes-only；remindctl |
| 3 | 域 C · 学习语义（JSON SSOT） | ✅ | `projects.json` + 对话完成 |
| 4 | 域 D · 晨报聚合 | ✅ | F1–F5 |
| 5 | MalDaze 文案 / Smart Input 收敛 | ✅ | D3：不改 Smart Input |
| **6a** | **学习面板 v1** | **✅** | L1+L2+H-L2 · `add-learning-desk-panel` · MANUAL_QA 通过 |
| **6b** | **学习面板 L3** | ✅ QA 通过 · 未归档 | `add-learning-desk-panel-l3` |
| **6c** | **移除飞书日历投影** | ✅ 已归档 2026-06-09 | `remove-feishu-learning-calendar` |
| 7 | 可选增强 | ⏸ | X1–X4、文档债 |

**已归档 change**：`add-sleep-schedule` · `unify-personal-assistant` · `complete-integration-feishu-qa`（2026-06-08）

**自动验收**：`integration_smoke.py` 全绿 · `integration_feishu_qa.py`（日待办 / 完成1 / 烹饪 bell）

---

## 0. 已定稿原则（改实现前先对齐）

| # | 原则 |
|---|------|
| P1 | **Hermes** = 对话入口、算法、写数据、晨报 |
| P2 | **MalDaze** = 到点**强干预**（铃铛、倒计时条、霸屏）；学习域 **展示 + 轻交互**，不做第二个聊天 Agent |
| P3 | **日待办**（银行、超市）→ 苹果「提醒事项」；**Hermes 端到端**，不经桌宠协作 |
| P4 | **到时强提醒**（煮红薯等）→ cron 等待 + 到点写 `bell` 契约 → MalDaze 中央铃铛 |
| P5 | **学习任务** SSOT = `projects.json`；**桌宠面板读 JSON（经 CLI），不读外部日历** |
| P6 | 跨应用耦合继续用 **本机 JSON 契约**（与睡眠集成同模式）；强干预 + 学习快操走 Hermes CLI |
| P7 | 飞书输出遵守既有规则：**不用 markdown 表格**（见 Hermes `MEMORY.md`） |
| P8 | **强提醒前置**：桌宠未运行 → Hermes 拒绝写 intervention 并飞书报错（D7） |
| P9 | **日待办列表**：Hermes 与桌宠 Dashboard 同列表（读 `com.maldaze.MalDaze` UserDefaults，D5） |
| P10 | **学习算法唯一**：`schedule.py`；MalDaze **禁止** Swift 复刻 move 级联 / 复习链 / rollover |

### 用户拍板（scope-decision）

| ID | 结论 |
|----|------|
| D1 | 无 intervention 消费回执 |
| D2 | 新 countdown 覆盖进行中倒计时（仅契约 `countdown`；飞书路径不用） |
| D3 | **不**改 Smart Input（无隐藏设置） |
| D4 | 单条日待办直接写；批量/重复须确认 |
| D5 | 提醒列表 = 桌宠所选列表 |
| D6 | complete 只写 JSON；`projects.json` + `daily_log.json` 保留历史（**不**删飞书日历格） |
| D7 | 桌宠未开 → Hermes fail-loud |

### 三域 + 节律模型

```
域 A · 日待办          Hermes skill → 苹果提醒事项（桌宠侧栏只读）
域 B · 到时强提醒      cron 等待 → 到点 intervention `bell` → MalDaze 中央铃铛
域 C · 学习任务        Hermes schedule.py → projects.json（桌宠中栏展示 + CLI 快操）
域 D · 睡眠节律        sleep_schedule.json → MalDaze SleepReminder（✅）
域 E · 护眼休息        MalDaze 原生 TimerEngine（与 Hermes 无关）
域 F · 晨报聚合        morning-briefing.py（A + C + D 摘要）
```

---

## 1. Phase 0 · 文档与登记表

| ID | 任务 | 仓库 | 产出 | 状态 |
|----|------|------|------|------|
| D0-1 | 本总目录 `ROADMAP.md` | MalDaze | 本文件 | ✅ |
| D0-2 | 域 B `features/desk-intervention.md` | MalDaze | schema、D7、D2 | ✅ |
| D0-3 | 域 A `features/day-reminders.md` | MalDaze | Hermes-only 边界 | ✅ |
| D0-4 | 域 C `features/learning-calendar.md` | MalDaze | JSON SSOT；日历投影已移除 | ✅ |
| D0-5 | `hermes.md` 集成登记表 | MalDaze | 随功能递增 | ✅ |
| D0-6 | `~/.hermes/docs/integrations/README.md` | Hermes | 索引行 only | ✅ |
| D0-7 | OpenSpec `unify-personal-assistant` | MalDaze | proposal/design/specs/tasks | ✅ |
| D0-8 | 学习桌宠面板设计 `features/learning-desk-panel.md` | MalDaze | 展示层 + CLI 分工 | ✅ |

**完成标准**：各域边界文档齐全；登记表能指到每个 feature 的 canonical。

---

## 2. Phase 1 · 域 A · 日待办（Hermes 端到端）

> 桌宠不参与写链路；Dashboard 左栏与 Hermes 同提醒列表（D5）。

| ID | 任务 | 仓库 | 依赖 | 产出 / 验收 | 状态 |
|----|------|------|------|-------------|------|
| A1 | `remindctl` + 列表对齐桌宠 | Hermes | D0-3 | `day_reminders.py` | ✅ |
| A1-D4 | 单条直写 / 批量确认 | Hermes | A1 | `SKILL.md` + `dialogue-examples.md` | ✅ |
| A2 | skill `skills/day-reminders/` | Hermes | A1 | `SKILL.md` + scripts | ✅ |
| A3 | 自然语言 → 结构化字段 | Hermes | A2 | `dialogue-examples.md` | ✅ |
| A4 | complete / postpone / delete | Hermes | A2 | CLI 子命令 | ✅ |
| A5 | 单测 / 冒烟 | Hermes | A2–A4 | `tests/day-reminders/` | ✅ |
| A6 | 晨报 📋 段 | Hermes | A2、F1 | `morning-briefing.py` | ✅ |

**不做**

| ID | 项 | 原因 |
|----|-----|------|
| A✗1 | Hermes → MalDaze → EventKit | 日待办不需要桌宠 |
| A✗2 | MalDaze SmartReminder 为主路径 | 入口统一到飞书 |

**文档债（非阻塞）**

| ID | 项 | 说明 | 状态 |
|----|-----|------|------|
| A-DOC1 | `day-reminders` 重复提醒 | remindctl ≥ 0.3.0 + `create --repeat`；D4 单条明确重复直接写 | ✅ |

---

## 3. Phase 2 · 域 B · 到时强提醒

> 飞书路径：**cron 等待 + 到点 bell**（非创建时 countdown）。

### 3.1 契约

| ID | 任务 | 仓库 | 依赖 | 产出 | 状态 |
|----|------|------|------|------|------|
| B0-1 | 契约路径 | 双方 | D0-2 | `intervention_request.json` → `consumed/` | ✅ |
| B0-2 | schemaVersion + 字段 | 双方 | B0-1 | kind/minutes/title/id/expiresAt | ✅ |
| B0-3 | `desk-intervention.md` | MalDaze | B0-2 | D7、D2 | ✅ |

### 3.2 Hermes 写端

| ID | 任务 | 仓库 | 依赖 | 产出 | 状态 |
|----|------|------|------|------|------|
| B1 | skill + cron + `intervention_request.py` | Hermes | B0-3 | 到点 `bell` | ✅ |
| B1-D7 | 写前检测 MalDaze | Hermes | B1 | fail-loud | ✅ |
| B2 | 时长 → cron schedule | Hermes | B1 | 用户分钟数 | ✅ |
| B3 | 写后校验 | Hermes | B1 | 非法字段报错 | ✅ |
| B4 | `kind: cancel` | Hermes | B1 | CLI | ✅ |

### 3.3 MalDaze 读端

| ID | 任务 | 仓库 | 依赖 | 产出 | 状态 |
|----|------|------|------|------|------|
| M-B1 | `InterventionRequest/` | MalDaze | B0-3 | 读契约、校验 | ✅ |
| M-B2 | FSEvents / 启动 / 唤醒 | MalDaze | M-B1 | FileWatcher | ✅ |
| M-B3 | countdown → SevenMinuteReminder | MalDaze | M-B1 | 动态 minutes | ✅ |
| M-B3b | D2 覆盖 + 迟到仅 bell | MalDaze | M-B3 | 契约纪律 | ✅ |
| M-B4 | bell → 中央铃铛 | MalDaze | M-B1 | `presentCenterBellReminder` | ✅ |
| M-B5 | ack → `consumed/{id}.json` | MalDaze | M-B1 | 幂等 | ✅ |
| M-B6 | 单元测试 | MalDaze | M-B1–M-B5 | ContractTests | ✅ |
| M-B7 | 控制面板状态卡 | MalDaze | M-B3 | — | ⏸ |

**完成标准**：飞书「N 分钟后…」→ cron → 到点桌宠中央铃铛（等待期无倒计时）。

---

## 4. Phase 3 · 域 C · 学习语义（JSON SSOT）

> SSOT = `projects.json`；飞书对话完成体验。**2026-06-08+** 已移除飞书日历投影（见 Phase 6c）。

### 4.1 策略（C0 · D6，历史）

| 决策 | 状态 |
|------|------|
| JSON 为唯一排期 SSOT | ✅ |
| 飞书对话 complete / move | ✅ |
| JSON 历史保留 | ✅ D6 |
| 飞书日历软投影 | ❌ 已移除（6c） |
| 迁到提醒事项 | ❌ C✗1 |

| ID | 任务 | 仓库 | 依赖 | 产出 | 状态 |
|----|------|------|------|------|------|
| C0 | 策略文档 + OpenSpec | 双方 | D0-4 | `learning-calendar.md` | ✅ |
| C1 | ~~全天软锚点 create~~ | Hermes | — | — | ❌ 已移除 |
| C2 | ~~complete 日历策略~~ | Hermes | — | — | ❌ 已移除 |
| C3 | `today` → `pending[]` | Hermes | — | index/task_id | ✅ |
| C4 | 飞书「完成 N」 | Hermes | C3 | learning skill §2–3 | ✅ |
| C5 | ~~孤儿日历清理（运维）~~ | Hermes | — | — | ❌ 已移除 |
| C6 | `today_learning.json` 快照 | Hermes | C3 | 供桌宠免子进程 | ⏸ |

**不做**

| ID | 项 | 原因 |
|----|-----|------|
| C✗1 | 学习任务迁入提醒事项 | 丢复习链、容量、move 语义 |
| C✗2 | 飞书日历 App 内完成按钮 | 平台不支持 |
| C✗3 | 桌宠读外部日历作 SSOT | 违背 P5 |

---

## 5. Phase 4 · 域 F · 晨报聚合

| ID | 任务 | 仓库 | 依赖 | 产出 | 状态 |
|----|------|------|------|------|------|
| F1 | 📋 今日提醒摘要 | Hermes | A2 | morning-briefing | ✅ |
| F2 | 📚 今日学习 pending | Hermes | C3 | `schedule.py today` | ✅ |
| F3 | 🌙 睡眠目标一行 | Hermes | — | sleep_tracker | ✅ |
| F4 | 飞书排版（无表格） | Hermes | F1–F3 | `·` 逐行 | ✅ |
| F5 | cron 08:00 | Hermes | F1–F4 | `jobs.json` | ✅ |

---

## 6. Phase 5 · MalDaze 收敛（Smart Input / 文案）

> D3：**本阶段不改 Smart Input**。

| ID | 任务 | 仓库 | 依赖 | 产出 | 状态 |
|----|------|------|------|------|------|
| M-SI1 | SmartReminder 标 legacy（文档） | MalDaze | — | README 注明飞书主路径 | ⏸ |
| M-SI2 | 隐藏右键 Smart Input | MalDaze | — | — | ❌ D3 |
| M-SI3 | 改绑 ⌘⇧< | MalDaze | — | — | ❌ D3 |
| M-SI4 | Dashboard 提醒侧栏保留 | MalDaze | — | 与 Hermes 同列表 D5 | ✅ |
| M-SI5 | 移除 Gemini 设置 | MalDaze | — | — | ⏸ 后续 change |
| M-SI6 | 倒计时 UI 文案统一 | MalDaze | M-B3 | title 作结束铃铛文案 | ✅ |

---

## 7. Phase 6 · 域 C · 桌宠学习面板

> **母本**：[features/learning-desk-panel.md](./features/learning-desk-panel.md)  
> **延后索引**：[features/learning-desk-panel-followup.md](./features/learning-desk-panel-followup.md)  
> **scope A**：v1 = L1+L2+H-L2 ✅；L3 含每日上限设置（默认 5h）；H-L1 rollover 日历仍独立 change

### 7.1 Phase 6a · v1（`add-learning-desk-panel`）✅ 已归档

| ID | 任务 | 仓库 | OpenSpec | 状态 |
|----|------|------|----------|------|
| M-L0 | propose + scope A 收窄 | MalDaze | `add-learning-desk-panel` | ✅ |
| M-L1 | 三栏 + Today 只读 | MalDaze | tasks-maldaze §1–3 | ✅ |
| M-L2 | complete + move 预览 | MalDaze | tasks-maldaze §4–5 | ✅ |
| H-L2 | `move --dry-run` | Hermes | tasks-hermes §1.1 | ✅ |
| M-L4 | CLI mock 单测 + MANUAL_QA M-L-1～6 | MalDaze | tasks-maldaze §6 | ✅ |

**v1 完成标准**：中栏 = `today`；complete/move 与飞书一致；左右栏无回归。

### 7.2 Phase 6b · L3 增强（`add-learning-desk-panel-l3`）✅ QA 通过 · 未归档

> **前置**：6a 归档或 M-L2 已上线。

| ID | 任务 | 仓库 | 状态 |
|----|------|------|------|
| M-L3 | insert / remove | MalDaze | ✅ |
| M-L3a | Week 负荷 Tab | MalDaze | ✅ |
| M-L3b | FSEvents 刷新 | MalDaze | ✅ |
| M-L3c | review passed/failed | MalDaze | ✅ |
| M-L3d | 每日上限（小时）+ 设置页 | MalDaze | ✅ |
| H-L3 | `pending[]` + `auto_roll_days` | Hermes | ✅ |
| H-L4 | `week-load` CLI（`budget` 分钟；面板按设置小时展示） | Hermes | ✅ |

OpenSpec：`openspec/changes/add-learning-desk-panel-l3/`（proposal/design/specs/tasks 齐全）

### 7.3 Phase 6c · 移除飞书日历 + 对话建项目 ✅ 已归档 2026-06-09

| ID | 任务 | 仓库 | 状态 |
|----|------|------|------|
| H-L1 | 删除 `schedule.py` 飞书日历集成 | Hermes | ✅ |
| H-L2 | `create-project` CLI + SKILL 单层确认 | Hermes | ✅ |
| M-L11 | 面板空状态 / 无建项目按钮 | MalDaze | ✅ |

OpenSpec 归档：`2026-06-09-remove-feishu-learning-calendar` · `2026-06-09-refresh-hermes-project-intake` · `2026-06-09-fix-learning-rollover-calendar`（作废）

### 7.4 明确不做

| 项 | 去向 |
|----|------|
| SQLite / FastAPI 嵌入 | ❌ |
| 学习域飞书日历投影 | ❌ 已移除 |
| plan / 智能模式 | 飞书 |

### 7.5 推荐顺序

```
6a: H-L2 → L1 → L2 → 验收 → 归档 v1
        │
        └─► 6b add-learning-desk-panel-l3（v1 后）
                │
                └─► 6c remove-feishu-learning-calendar（Hermes ✅ · 待 MANUAL_QA 归档）
```

---

## 8. Phase 7 · 可选增强

| ID | 任务 | 仓库 | 说明 | 状态 |
|----|------|------|------|------|
| X1 | 飞书触发 MalDaze 休息测试 | 双方 | 低价值 | ⏸ |
| X2 | 营养今日面板（`daily_log.panel` + 点击/数字键 log） | 双方 | `add-nutrition-today-panel` | 🟡 待 M-N1 |
| X3 | HTTP localhost 替代文件契约 | 双方 | JSON 够用 | ❌ |
| X4 | 桌宠读飞书日历 | MalDaze | 违背 P5 | ❌ |
| X5 | `today_learning.json` 快照（C6） | Hermes | 减子进程延迟 | ⏸ |
| X6 | 控制面板 intervention 状态卡（M-B7） | MalDaze | 域 B 可视化 | ⏸ |
| X7 | 学习项目 Tab + 改 deadline **重排未完成课**（US-10） | Hermes + MalDaze | `add-learning-project-status` | ✅ 已归档 2026-06-09 |
| X8 | 学习面板 **日程**（月历 + Agenda，`schedule-range`） | Hermes + MalDaze | `add-learning-calendar-view` | ✅ 已归档 2026-06-09 |
| X9 | 今日视图 **执行台核心**（双预算、进度、滚入区、实际时长、分组） | MalDaze + Hermes `today` | `extend-learning-today-core` | 🟡 已实现 · 待 M-L12-core |
| X10 | 今日视图 **导航增强**（行动卡、明日一瞥、链接、repack 预览） | MalDaze + Hermes `today` | `extend-learning-today-navigation` | 🟡 已实现 · 待 M-L12-nav |

---

## 9. 全局推荐实施顺序

```
Phase 0  文档 + OpenSpec ────────────────────────► ✅
Phase 1  域 B 强提醒 ────────────────────────────► ✅
Phase 2  域 A 日待办 ────────────────────────────► ✅
Phase 3  域 C 学习日历语义 ──────────────────────► ✅
Phase 4  晨报 ───────────────────────────────────► ✅
Phase 5  Smart Input 收敛 / 文案 ────────────────► ✅
Phase 6a 学习面板 v1（L1+L2+H-L2）─────────────► ✅
Phase 6b 面板 L3（QA 通过 · 未归档）──────────────► ✅
Phase 6c rollover 日历（QA 通过 · 未归档）────────► ✅
Phase 7  可选增强 ───────────────────────────────► ⏸
```

**并行规则**

- 域 A 与域 B 可并行（无文件重叠）。
- Phase 6 的 M-L1 与 H-L1/H-L3 可并行；**M-L2a 依赖 H-L2**（或接受弱预览）。
- Phase 6 与 `SleepReminder/` 避免同时大改 `AppViewModel` / `DashboardRootView` 无关区域。
- 完成任意 ID → 回改本文 + §10 登记表 +（大功能）`tasks-hermes.md` / `tasks-maldaze.md`。

---

## 10. 功能登记表

> 副本亦在 [hermes.md](./hermes.md)；上线后两边同步。

| 功能 | 域 | 契约 / SSOT | Hermes | MalDaze | Feature 文档 | 状态 |
|------|-----|-------------|--------|---------|--------------|------|
| 睡眠提醒 | D | `data/sleep/sleep_schedule.json` | sleep_tracker, briefing | `SleepReminder/` | [sleep.md](./features/sleep.md) | ✅ 已上线 |
| 日待办 | A | 苹果提醒事项 | day_reminders, skill | 侧栏只读 | [day-reminders.md](./features/day-reminders.md) | ✅ 已上线 |
| 到时强提醒 | B | `data/maldaze/intervention_request.json` | intervention_request | `InterventionRequest/` | [desk-intervention.md](./features/desk-intervention.md) | ✅ 已上线 |
| 学习 SSOT + 飞书完成 | C | `projects.json` | schedule.py, skill | — | [learning-calendar.md](./features/learning-calendar.md) | ✅ 已上线 |
| **学习桌宠面板 v1** | C | 同上（经 CLI） | schedule.py + dry-run | `LearningDeskPanel/` | [learning-desk-panel.md](./features/learning-desk-panel.md) | ✅ |
| 护眼休息 | E | MalDaze 内部 | — | TimerEngine | PRD.md | ✅ 已上线 |
| 晨报 | F | — | morning-briefing | — | §5 | ✅ 已上线 |

---

## 11. 单功能开工检查表

1. 读本文对应 Phase + **原则 P1–P10**
2. 读 `features/*.md`（Phase 6 必读 `learning-desk-panel.md`）
3. `git status`（MalDaze）；Hermes 确认无冲突脚本
4. 大功能：先 `opsx:propose` → `tasks.md` 存在再 `opsx:apply`
5. 实现 → 单测 / `integration_smoke` / MANUAL_QA → 更新 §10 状态
6. 更新 `hermes.md` + `~/.hermes/docs/integrations/README.md`
7. OpenSpec 归档后合并 delta 进 features

---

## 12. 验收与冒烟索引

| 类型 | 命令 / 文档 |
|------|-------------|
| 全自动 | `python3 ~/.hermes/scripts/integration_smoke.py` |
| 飞书代理 | `python3 ~/.hermes/scripts/integration_feishu_qa.py` |
| 手工清单 | [MANUAL_QA.md](./MANUAL_QA.md) |
| MalDaze 单测 | InterventionRequest / SleepSchedule 等（见 MANUAL_QA §0） |
| 学习面板 | MANUAL_QA §域 C 面板（Phase 6 完成后启用） |

---

## 13. 相关文档索引

| 文档 | 路径 |
|------|------|
| **本总目录** | [ROADMAP.md](./ROADMAP.md) |
| **联调手册** | [MANUAL_QA.md](./MANUAL_QA.md) |
| **集成 hub** | [hermes.md](./hermes.md) |
| 学习面板设计 | [features/learning-desk-panel.md](./features/learning-desk-panel.md) |
| 今日 X9/X10 功能与 QA 追溯 | [features/learning-today-x9-x10.md](./features/learning-today-x9-x10.md) |
| 学习主 spec | `openspec/specs/learning-desk-panel/` · `hermes-learning-calendar/` · `hermes-morning-briefing/` |
| ~~v2 母本~~（**已废弃**） | [learning-assistant-v2.md](../../openspec/learning-assistant-v2.md) — 仅考古，勿引用 |
| 已归档 change | [unify-personal-assistant](../../openspec/changes/archive/2026-06-08-unify-personal-assistant/) · [add-sleep-schedule](../../openspec/changes/archive/2026-06-08-add-sleep-schedule/) |
| 主 spec | `hermes-*` · `desk-intervention*` · `sleep-*` |
| Hermes manifest | `~/.hermes/docs/integrations/README.md` |
| 学习 skill | `~/.hermes/skills/learning-assistant/SKILL.md` |
| 学习脚本 | `~/.hermes/scripts/schedule.py` |

---

*维护约定：Phase 6 每完成 M-L* / H-L* 一行，同步 §10 登记表与 `learning-desk-panel.md` 分期勾选。*
