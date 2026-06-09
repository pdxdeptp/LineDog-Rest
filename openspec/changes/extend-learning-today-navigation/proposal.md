## Why

今日执行台在 `extend-learning-today-core` 强化后，仍缺 **从诊断到行动的导航** 与 **和飞书/晨报一致的操作心智**。主 spec 要求超额/落后如实显示且面板侧不自动改计划，但用户需要一键跳到相关视图；同时减少为「明天紧不紧」「链接在哪」频繁切换日程 Tab。

## What Changes

### Hermes `schedule.py today`（扩展）

- `pending[]` 增加可选 `source_url`（来自项目元数据）。
- 响应增加 **`tomorrow_preview`**：明日 pending 摘要（条数、正课分钟、最多 N 条任务标题），只读。
- 无新子命令。

### MalDaze 今日 Tab

6. **落后/超额行动卡**：汇总 `warnings` + 今日超额 → 只读诊断 + 按钮（筛今日某项目 / 切日程并定位明天 / 切项目 Tab 并 **scroll 到项目卡** / **重排未完成课** 预览+确认 repack）。
7. **明日一瞥**：底部只读块，展示 `tomorrow_preview`。
8. **可点击 warnings**：点「LC 落后 N 天」→ 今日列表高亮该项目首条 pending。
9. **任务源链接**：行内链到 `source_url`。

### 文档

- `learning-desk-panel.md`；`MANUAL_QA` 增 M-L12-nav；`hermes-morning-briefing` 一句「index 与面板一致」。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `learning-desk-panel`: MODIFIED — 行动卡、明日一瞥、warnings 交互、源链接。
- `hermes-learning-calendar`: MODIFIED — `today` 扩展 `tomorrow_preview` 与 `source_url`。
- `hermes-morning-briefing`: MODIFIED — 文档化 pending `index` 与面板编号一致（行为已一致则仅 ADDITIONAL 说明）。

## Impact

- **Hermes**：`cmd_today` / `build_pending_list` + 单测。
- **MalDaze**：今日 Tab UI、ViewModel；`SMAppService`/`NSWorkspace` 打开 URL。
- **非目标**：无确认的静默 repack、飞书深链按钮、拖拽改期、智能模式方案卡。
- **Repack（R2）**：行动卡对选中项目提供 **预览 + 确认** 的 `set-deadline` spread repack（deadline 不变）；非自动改 JSON。
- **依赖**：`extend-learning-today-core` 应先归档或合并后再 apply 本 change。

## Affected Specs

- `learning-desk-panel`
- `hermes-learning-calendar`
- `hermes-morning-briefing`
