# MalDaze · X7 + US-10 · deadline repack

> **依赖**：`tasks-hermes` §1–2（repack 语义落地）。

## 1. Models + CLI

- [x] 1.1 扩展 `HermesSetDeadlineResponse`：`repacked`、`changes[]`、`overflow_count`、`overflow_tasks`
- [x] 1.2 可选 `setDeadline(..., dryRun: Bool)`
- [x] 1.3 单测：新 JSON fixture

## 2. 项目 Tab UI

- [x] 2.1 sheet 确认文案：说明 **重排未完成课程**（替换「不移动任务」）
- [x] 2.2 可选：确认前 `dry-run` 显示「将移动 N 节课」
- [x] 2.3 `overflow_count > 0` 提示

## 3. ViewModel

- [x] 3.1 成功后刷新 today + **week** + status
- [x] 3.2 确认流程对接新响应字段

## 4. 文档与验收

- [x] 4.1 `learning-desk-panel.md` / `MANUAL_QA` M-L9 修订
- [x] 4.2 `openspec validate add-learning-project-status --strict`
