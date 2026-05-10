# 学习助手重修进度记录

> 对应路线图：`docs/learning-assistant-rework-roadmap.md`
> 更新原则：每个闭环完成归档后更新状态；重要决策或偏差记录在"备注"栏。

---

## 闭环总览

| # | change 名 | 阶段 | 状态 | 归档日期 |
|---|-----------|------|------|----------|
| 1 | `redesign-learning-assistant-home` | 第一阶段 | ✅ 完成 | 2026-05-10 |
| 2 | `productize-learning-material-ingestion` | 第一阶段 | ⬜ 未开始 | — |
| 3 | `productize-today-learning-workbench` | 第二阶段 | ⬜ 未开始 | — |
| 4 | `productize-resource-progress-roadmap` | 第二阶段 | ⬜ 未开始 | — |
| 5 | `productize-conversational-planner-ui` | 第二阶段 | ⬜ 未开始 | — |
| 6 | `explain-morning-briefing-and-reschedule` | 第三阶段 | ⬜ 未开始 | — |
| 7 | `productize-weekly-review-experience` | 第三阶段 | ⬜ 未开始 | — |
| 8 | `clarify-assistant-backend-errors` | 第四阶段 | ⬜ 未开始 | — |
| 9 | `automate-learning-assistant-acceptance` | 第四阶段 | ⬜ 未开始 | — |

---

## 闭环详情

### ✅ 闭环一：学习助手首页 / 信息架构

**change:** `redesign-learning-assistant-home`
**归档路径:** `openspec/changes/archive/2026-05-10-redesign-learning-assistant-home/`

**完成内容**

- 宽屏 popover：`ControlPanelLayout` 从 `NSScreen.main?.visibleFrame` 计算宽度，左右栏固定，学习助手中栏自适应
- 首页 dashboard：summary-first 布局，替换原四 Tab 结构
- 底部固定导航：首页 / 添加资料 / 资料进度 / 调整计划，滚动时保持可见
- 今日任务列表：本地展示顺序（`UserDefaults` 持久化，不写后端 priority）
- 任务行展开：轻量详情 + 打开链接 / 链接不可用双状态
- 后端链接契约：`GET /api/today-briefing` 任务项新增 `resource_url` 和 `unit_url`
- 整栏离线状态：任何首页请求失败 → 整栏不可用，隐藏底部导航

**测试结果**

- `pytest`：9/9 passed
- `xcodebuild test`：TEST SUCCEEDED

**未完成项（非阻断）**

- 5.8：底部导航标签文字宽屏不重叠（已人工验证通过）
- 6.3：8 种视觉状态截图（已人工验证，未存档截图）

**关键决策**

- 不新增 dashboard summary API；前端组合 `/api/today-briefing` + `/api/resources`
- 任务展示顺序只存本地，不修改 Morning Agent 排期
- 离线不保留旧内容，整栏服务不可用替代缓存降级
- `NSPopover` 保持不变，通过 `contentSize` 实现宽屏

---

### ⬜ 闭环二：添加学习资料

**change:** `productize-learning-material-ingestion`
**目标:** 让粘贴链接 → 系统理解 → 草稿展示 → 确认写入成为可信可检查可撤销的完整体验

**待探索问题（开始前需回答）**

- 分析过程是否显示阶段进度（识别类型 → 读取结构 → 估算工时 → 生成排期）
- 草稿是否展示章节列表预览
- 方案 A/B 命名是否改成更自然的用户语言
- 确认前是否允许调整 deadline / speed factor / 方案
- 取消草稿后是否保留输入内容

---

### ⬜ 闭环三：今日学习工作台

**change:** `productize-today-learning-workbench`
**目标:** 把任务列表升级为当天学习工作台，支持实际用时记录和完成反馈

---

### ⬜ 闭环四：资料进度 / 学习路线图

**change:** `productize-resource-progress-roadmap`
**目标:** 把进度条列表升级为学习路线图，可见 deadline 风险和剩余量预测

---

### ⬜ 闭环五：对话式计划修改

**change:** `productize-conversational-planner-ui`
**目标:** 把聊天框改造为自然语言计划编辑器，proposal 展示结构化 diff

---

### ⬜ 闭环六：晨报 / 自动重排可解释性

**change:** `explain-morning-briefing-and-reschedule`
**目标:** 让用户理解 Morning Agent 为什么今天这样安排，尤其是自动重排和速度系数调整

---

### ⬜ 闭环七：周复盘

**change:** `productize-weekly-review-experience`
**目标:** 把后端 Weekly Review Agent 变成可被用户理解和确认的周复盘体验

---

### ⬜ 闭环八：后端运行可靠性 / 错误语义

**change:** `clarify-assistant-backend-errors`
**目标:** 把"助手离线"从万能错误改为清晰错误状态体系

---

### ⬜ 闭环九：验收自动化基础设施

**change:** `automate-learning-assistant-acceptance`
**目标:** 把人工验收清单升级为可重复运行的验收工具

---

## 当前状态

**活跃闭环:** 无（闭环一已归档，待开始闭环二）

**下一步:** 运行 `/opsx:explore` 探索 `productize-learning-material-ingestion` 的用户旅程和产品取舍，回答上方"待探索问题"后再创建 OpenSpec 文档。
