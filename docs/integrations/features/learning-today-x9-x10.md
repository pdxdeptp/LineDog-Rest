# 学习面板今日 Tab · X9 / X10 功能与手工 QA

Hub：[learning-desk-panel.md](./learning-desk-panel.md) · 联调清单：[MANUAL_QA.md](../MANUAL_QA.md) · 总目录：[ROADMAP.md](../ROADMAP.md) §7 X9/X10

> **状态**：代码已实现（2026-06-09）· **待用户 MANUAL_QA** · 两个 OpenSpec change **未归档**
>
> **OpenSpec**：[`extend-learning-today-core`](../../openspec/changes/extend-learning-today-core/) · [`extend-learning-today-navigation`](../../openspec/changes/extend-learning-today-navigation/)

---

## 0. 范围总览

| Change | ROADMAP | 一句话 |
|--------|---------|--------|
| **X9 · core** | X9 | 今日 **执行台**：双预算、完成进度、滚入置顶、实际时长、项目分组 |
| **X10 · navigation** | X10 | 今日 **导航**：行动卡、warning 点击、明天预告、源链接、repack 预览 |

**依赖**：先 ship X9，再 X10（同分支已一并实现）。

**刻意不做（两个 change 共有）**

- 面板建项目 / plan / 飞书对话改计划
- 智能模式方案卡、静默自动 repack
- 顶栏「编号快完成」输入（用户 2026-06-09 要求删除；飞书/晨报「完成 N」仍在对话侧）

---

## 1. X9 · `extend-learning-today-core`

### 1.1 Hermes · `schedule.py today`

| 字段 | 含义 |
|------|------|
| `progress.study` / `progress.review` | 各 `{ done, total }`：`total` = 当日 scheduled 且非 `failed` 全量；`done` = 其中 `completed` |

**实现**：`build_today_progress()` · 单测 `~/.hermes/tests/learning-assistant/test_schedule_today_progress.py`

**MalDaze 解码**：`HermesTodayProgress` · `HermesScheduleModels.swift`

---

### 1.2 双预算顶栏

| 项 | 说明 |
|----|------|
| **位置** | 今日 Tab 顶栏，日期下方 |
| **正课** | `study.total_minutes` / MalDaze 设置同步的日上限（小时展示） |
| **复习** | `review.total_minutes` / `profile.review_budget_minutes`（分钟展示，默认 60） |
| **超额** | 任一桶超预算 → 该行红色 + 文案「超额」 |

**代码**：`LearningDeskPanelView.todayHeader` · `budgetLine`

---

### 1.3 今日完成进度

| 项 | 说明 |
|----|------|
| **位置** | 双预算下方 |
| **展示** | 正课/复习各一行 `done/total` + `ProgressView` |
| **更新时机** | 完成/复习操作成功后 `loadToday()` 刷新 |

---

### 1.4 滚入置顶区（`auto_roll_days >= 3`）

| 项 | 说明 |
|----|------|
| **位置** | 顶栏与主列表之间橙色块「已滚 3+ 天（N）」 |
| **内容** | 项目名、标题、已滚天数（紧凑行） |
| **点击** | `ScrollViewReader` 滚到主列表对应 `task_id` 并高亮 ~2s |
| **S1 定稿** | 置顶区 **无** 完成/推迟；完整操作仅在主列表 |
| **并存** | 主列表行内仍显示 `auto_roll_days >= 1` 的 badge |

**代码**：`LearningTodayRolloverStrip.swift`

---

### 1.5 完成 + 可选实际时长

| 路径 | 行为 |
|------|------|
| **快** | 行首圆圈 → `complete --task-id`（计划时长） |
| **慢** | ⋯ 菜单「记录时长并完成」→ `LearningCompleteDurationSheet` → `complete --actual-minutes N` |

**代码**：`LearningDeskPanelViewModel.complete(taskId:actualMinutes:)` · `HermesScheduleCLI.complete`

复习行仍为「过/挂」，无记录时长菜单。

---

### 1.6 按项目分组

| 模式 | 行为 |
|------|------|
| **扁平** | 正课段 + 复习段（原样） |
| **按项目** | 按 `project_name` 分段；段内顺序 = `pending.index` 相对顺序 |
| **持久** | `MalDazeDefaults.learningTodayGrouping`（`AppStorage`） |

**代码**：顶栏 segmented「扁平 | 按项目」· `LearningTodaySnapshot.projectSections`

---

### 1.7 X9 手工 QA（M-L12-core）

| # | 步骤 | 预期 |
|---|------|------|
| M-L12-core-1 | 打开今日 Tab | 正课+复习负荷与预算；任一桶超额标红 |
| M-L12-core-2 | 圆圈完成 1 节正课 | `done/total` 与进度条增加；任务从列表消失 |
| M-L12-core-3 | 存在 `auto_roll_days >= 3` | 置顶区显示；点击滚到主列表对应行 |
| M-L12-core-4 | ⋯「记录时长并完成」 | Sheet 默认计划时长；确认后完成 |
| M-L12-core-5 | 切「按项目」 | 按项目分段；段内 index 与扁平一致 |

**造数提示**：滚入 badge → `projects.json` 任务 `auto_roll_days`；进度含已完成 → 同日 `scheduled_date` + `status: completed`。

---

## 2. X10 · `extend-learning-today-navigation`

### 2.1 Hermes · `schedule.py today` 扩展

| 字段 | 含义 |
|------|------|
| `pending[].source_url` | 项目级 `source_url`（可无） |
| `tomorrow_preview` | 明日摘要：`date`, `pending_count`, `study_minutes`, `study_budget`, `is_rest_day`, `tasks[]`（最多 5 条） |

**实现**：`_today_bucket_tasks` · `build_tomorrow_preview()` · 单测 `test_schedule_today_tomorrow_preview.py`

**smoke（R1）**：`integration_smoke.check_schedule_today` — pending 非空时 `index` 须为 `1..N` 连续。

---

### 2.2 行动卡

**出现条件**：正课超额 **或** 复习超额 **或** `warnings` 非空。

| 按钮 | 行为 |
|------|------|
| 今日只看项目 | `todayProjectFilter`；列表仅该 `project_id`；可「清除」 |
| 项目 Tab | 切 Tab + `scrollToProjectId` 滚到项目卡（**S3**） |
| 重排未完成课 | **R2**：`set-deadline --dry-run`（deadline 不变）→ 截止日 Sheet 预览 → 用户确认后 apply |
| 日程·明天 | 切日程 Tab，`selectedScheduleDate = tomorrow`，`loadSchedule` |

**刻意不做**：静默 repack；飞书深链（**S2**）。

**代码**：`LearningTodayActionCard.swift` · `LearningDeskPanelViewModel`（filter / jump / repack / openScheduleTomorrow）

---

### 2.3 Warnings 可点击

橙色「项目名 落后 N 天」行可点 → 高亮今日该 `project_id` 首条 pending；无则 `actionNotice`「今日无该项目任务」。

与行动卡 **双轨并存**（行动卡给按钮，warning 行可点定位）。

---

### 2.4 明日一瞥

列表底部「明天预告」只读块：`LearningTomorrowPreviewBlock.swift`。不可在此完成/推迟。

---

### 2.5 任务源链接

`pending.source_url` 非空时行内 link 图标 → `NSWorkspace` 打开浏览器。无 URL 不显示图标。

---

### 2.6 已移除：编号快完成

原 X10 #10 顶栏输入 `2` / `完成 2` — **用户要求删除**（2026-06-09）。面板完成方式：行内圆圈、⋯ 记录时长、或飞书对话。

---

### 2.7 X10 手工 QA（M-L12-nav）

| # | 步骤 | 预期 |
|---|------|------|
| M-L12-nav-1 | 超额或落后 | 行动卡；筛项目 / 项目 Tab 滚动 / 日程明天 / 重排预览+确认 |
| M-L12-nav-2 | 点 warning 行 | 高亮首条 pending；无则提示 |
| M-L12-nav-3 | 列表底部 | 明天日期、节数、分钟、≤5 条标题 |
| M-L12-nav-4 | 有 `source_url` | link 打开浏览器 |
| ~~M-L12-nav-5~~ | ~~编号输入~~ | **已取消**，跳过 |

---

## 3. 通用准备

### 3.1 构建与自动检查

```bash
cd ~/Public/MalDaze && xcodebuild -scheme MalDaze -destination 'platform=macOS' build

cd ~/.hermes && python3 -m pytest \
  tests/learning-assistant/test_schedule_today_progress.py \
  tests/learning-assistant/test_schedule_today_tomorrow_preview.py -q

cd ~/Public/MalDaze && xcodebuild test -scheme MalDaze -destination 'platform=macOS' \
  -only-testing:MalDazeTests/HermesScheduleModelsTests \
  -only-testing:MalDazeTests/LearningDeskPanelViewModelTests

python3 ~/.hermes/scripts/integration_smoke.py
```

### 3.2 造测试数据

| 想测什么 | 数据条件 |
|----------|----------|
| 双预算超额 | 今日 pending 分钟总和 > 日上限 或复习 > `review_budget_minutes` |
| 完成进度 | 同日有 `completed` + `pending`（`scheduled_date` = 今天） |
| 滚入置顶 | `auto_roll_days >= 3` |
| warnings | active 项目首条 incomplete 的 `scheduled_date` 早于今天 ≥3 天 |
| 明天预告 | 明天 `scheduled_date` 上有 pending |
| 源链接 | 项目 `source_url` 非空 |
| 行动卡 repack | 落后/超额 + 项目有 `deadline` |

---

## 4. 终端对照与 JSON 速查

```bash
python3 ~/.hermes/scripts/schedule.py rollover   # 可选
python3 ~/.hermes/scripts/schedule.py today      # UI 应以之为准
python3 ~/.hermes/scripts/integration_smoke.py   # progress + index 连续
```

**`today` 示例（字段与 UI 映射）**

```json
{
  "date": "2026-06-08",
  "pending": [
    {
      "index": 1,
      "task_id": "...",
      "title": "...",
      "project_id": "...",
      "project_name": "...",
      "duration_minutes": 45,
      "task_type": "study",
      "scheduled_date": "2026-06-08",
      "auto_roll_days": 0,
      "source_url": "https://..."
    }
  ],
  "progress": {
    "study": { "done": 1, "total": 3 },
    "review": { "done": 0, "total": 1 }
  },
  "tomorrow_preview": {
    "date": "2026-06-09",
    "pending_count": 2,
    "study_minutes": 90,
    "study_budget": 300,
    "is_rest_day": false,
    "tasks": [ { "index": 1, "title": "...", "project_name": "...", "duration_minutes": 45 } ]
  },
  "study": { "total_minutes": 120, "budget": 300 },
  "review": { "total_minutes": 30, "budget": 60 },
  "warnings": [ { "project_id": "...", "project_name": "...", "days_behind": 4 } ]
}
```

| 字段 | UI |
|------|-----|
| `progress` | 完成进度条 |
| `study` / `review` | 双预算顶栏 |
| `warnings` | 落后行 + 行动卡 |
| `tomorrow_preview` | 底部明天块 |
| `pending[].source_url` | 行内 link |
| `pending[].index` | 行首 `1.` `2.` |
| `pending[].auto_roll_days` | 行 badge + 置顶（≥3） |

**关键路径**

| 仓 | 路径 |
|----|------|
| Hermes | `~/.hermes/scripts/schedule.py` |
| Hermes 单测 | `~/.hermes/tests/learning-assistant/test_schedule_today_*.py` |
| MalDaze UI | `MalDaze/LearningDeskPanel/LearningDeskPanelView.swift` |
| MalDaze VM | `MalDaze/LearningDeskPanel/LearningDeskPanelViewModel.swift` |
| 模型 | `MalDaze/LearningDeskPanel/HermesScheduleModels.swift` |
| 新组件 | `LearningTodayRolloverStrip` · `LearningCompleteDurationSheet` · `LearningTodayActionCard` · `LearningTomorrowPreviewBlock` |

---

## 5. 建议 QA 顺序（~15–20 分钟）

1. 今日 Tab → 双预算 + 进度（core-1、2）
2. 圆圈完成一门（core-2）
3. ⋯ 记录时长（core-4）
4. 扁平 ↔ 按项目（core-5）
5. 滚入 ≥3 天置顶点击（core-3）
6. 行动卡各按钮（nav-1）
7. 点 warning（nav-2）
8. 底部明天预告（nav-3）
9. source_url link（nav-4）

---

## 6. 排障追溯

| 现象 | 先查什么 |
|------|----------|
| 顶栏数字不对 | `schedule.py today` 的 `study`/`review`/`progress`；正课预算 = MalDaze 设置，复习 = `review_budget_minutes` |
| 完成进度不更新 | CLI `progress` 是否变；完成的是否 `scheduled_date == 今天`；MalDaze `loadToday` 链 |
| 置顶区不显示 | 须 `auto_roll_days >= 3` 且仍在今日 `pending`（≠ warnings 落后） |
| 行动卡不出现 | 须正课/复习超额 **或** `warnings` 非空；仅滚入 badge 不够 |
| 重排无预览 | 须行动卡「重排未完成课」或项目 Tab 改截止日；项目须有 `deadline`；须点确认才写 JSON |
| 项目 Tab 没滚到卡 | 从行动卡「项目 Tab」进（`scrollToProjectId`）；项目在 `status` 列表存在 |
| 明天预告空 | `tomorrow_preview.is_rest_day`；明天是否有 pending |
| 无 link 图标 | 项目 `source_url` → `pending[].source_url` 是否带出 |
| 筛选后列表空 | 「今日只看项目」只保留该 `project_id` 今日 pending；落后项目今日无课可为空 |

---

## 7. 与旧版今日 Tab 差异（回归）

| 以前 | 现在 |
|------|------|
| 顶栏仅正课负荷 | 正课 + 复习 + 完成进度 |
| warnings 只读 | 可点 + 行动卡 |
| 无明天信息 | 列表底 `tomorrow_preview` |
| 无外链 | 可选 `source_url` link |
| 仅扁平正课/复习 | 可「按项目」分组 |

**未改**：建项目仅 Hermes；日程/项目 Tab 原能力；圆圈仍为默认完成路径。

---

## 8. 归档前检查

- [ ] M-L12-core 五条通过
- [ ] M-L12-nav 四条通过（无 nav-5）
- [ ] `openspec validate extend-learning-today-core --strict`
- [ ] `openspec validate extend-learning-today-navigation --strict`
- [ ] 用户确认后归档两 change

---

*维护：功能变更时同步本文件与 `learning-desk-panel.md` §交付分档。*
