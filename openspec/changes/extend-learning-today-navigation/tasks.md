# Tasks: extend-learning-today-navigation

> **前置**：`extend-learning-today-core` 已 apply 或同分支合并后再做。

## 1. Hermes `today` extensions

- [x] 1.1 `build_pending_list` 附加 `source_url`
- [x] 1.2 `tomorrow_preview` 块（明日 pending 摘要，最多 5 条）
- [x] 1.3 `test_schedule_today_tomorrow_preview.py` + pending source_url 测试
- [x] 1.4 `integration_smoke.check_schedule_today`：**必做** index 连续 1..N（pending 非空时）

## 2. MalDaze models

- [x] 2.1 `HermesTomorrowPreview`、`source_url` on `HermesPendingTask`
- [x] 2.2 单测解码

## 3. 行动卡 & warnings

- [x] 3.1 `LearningTodayActionCard`（超额 + warnings）
- [x] 3.2 过滤今日 `project_id` / 切日程明天 / 切项目 Tab + **scroll 到项目卡（S3）**
- [x] 3.3 warnings 点击 → `highlightTaskId` + 无任务提示
- [x] 3.4 **Repack（R2）**：行动卡「重排未完成课」→ dry-run `set-deadline`（deadline 不变）→ 确认 sheet → apply
- [x] 3.5 `LearningProjectStatusView`：`scrollToProjectId` + `ScrollViewReader`

## 4. 明日一瞥

- [x] 4.1 今日底部 `tomorrow_preview` 只读块

## 5. 源链接 & 编号完成

- [x] 5.1 行内 link 打开 `source_url`
- [x] 5.2 顶栏编号输入 + `quickComplete(index:)`
- [x] 5.3 错误态：无效 index

## 6. Docs & QA

- [x] 6.1 `learning-desk-panel.md`、`hermes.md`；晨报 index 一致一句
- [x] 6.2 `MANUAL_QA.md` M-L12-nav
- [x] 6.3 `openspec validate extend-learning-today-navigation --strict`
- [ ] 6.4 用户 MANUAL_QA M-L12-nav
