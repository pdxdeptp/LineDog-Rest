# Scope Decision（用户拍板 · 2026-06-09）

来源：opsx:scope-decision 后续用户指令。

## 用户决策摘要

| ID | 决策 |
|----|------|
| **S1** | 滚入置顶区 **不提供** 推迟/完成；仅摘要 + `ScrollViewReader` 跳转主列表 |
| **S2** | 行动卡 **不提供**「打开飞书问 Hermes」深链 |
| **S3** | 行动卡「项目 Tab」须 **v1 即 scroll 到对应 `project_id` 卡片**，不等 v1.1 |
| **R1** | **`integration_smoke` 断言 `pending.index` 连续 1..N** — 必做（非 optional） |
| **R2** | **行动卡提供 repack** — 必做；用户确认后改 JSON（见下） |

## R2 · Repack 边界（相对默认模式）

- **不是**看到红色就静默 `repack`（违背「调整由用户发起」）。
- **是**行动卡在落后/超额诊断上提供 **「重排未完成课」**（或等价文案）：
  1. 选中 `project_id`（落后 warning 或用户从卡上选项目）
  2. `set-deadline --dry-run` 且 **deadline 不变** → 预览 `changes` / `overflow_count`（复用项目 Tab 已有 sheet 模式）
  3. 用户确认 → `set-deadline` 同 deadline、执行 spread repack
- 今日 **全项目超额**（非单项目）时：卡上引导先选项目再 repack，或切日程 Tab；不自动跨项目 repack。

## 纳入本 change（相对初版 proposal）

- R1、R2、S3 全部纳入。
- `LearningProjectStatusView` / ViewModel：支持 `scrollToProjectId`（行动卡跳入时）。

## 排除（不变）

- 飞书深链（S2）
- 智能模式多方案卡
- 无确认的静默 repack
