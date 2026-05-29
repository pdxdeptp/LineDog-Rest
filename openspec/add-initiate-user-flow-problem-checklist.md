# Add / Initiate 用户流程问题清单与拆分映射

## 拆分结论

原 `improve-add-initiate-user-flow` 范围过大，应拆成三个可独立 apply、独立测试的 OpenSpec changes：

1. `fix-add-initiate-state-boundaries`
   - 修 route/draft needs-input 混用、非计划确认、material-only quiet state、激活成功终态、active surface 刷新边界。
2. `polish-add-initiate-language-input`
   - 修入口文案、输入类型显示、角色/原因自然语言、标题 review、deadline 校验、target depth 控件、assumptions review。
3. `harden-add-initiate-draft-review`
   - 修草案编辑真实性、estimate edits、不可行选项参数确认、hard deadline option guard、草案审阅 summary-first。

## P0 阻塞级问题

### P0-1 `needs_input` 状态混用导致无草案卡死
- **归属:** `fix-add-initiate-state-boundaries`
- **用户路径:** 输入内容后，后端路由阶段返回低置信度 `needs_input`。
- **问题:** 此时可能还没有 `draftId`，用户继续后会触发“缺少 Add / Initiate 草案，请重新确认角色。”这类不可操作错误。
- **建议:** 将 route clarification 与 draft clarification 分成不同 UI 分支；无 `draftId` 时只显示路由问题和角色选择。

### P0-2 草案任务标题编辑可能假生效
- **归属:** `harden-add-initiate-draft-review`
- **用户路径:** 草案审阅里展开“单项编辑”，修改任务标题和分钟。
- **问题:** 当前 option 参数只发送 `estimate_edits` 的分钟，不发送标题；激活请求也只带 `draftId/draftVersion`。
- **建议:** 要么实现标题持久化并生成新 draft version，要么移除标题编辑或明确标注为不可保存。

### P0-3 激活成功缺少明确终态
- **归属:** `fix-add-initiate-state-boundaries`
- **用户路径:** 用户点击“激活草案”且后端成功。
- **问题:** 状态机变为 `.activated`，但 review/terminal 卡片没有成功态内容。
- **建议:** 增加激活成功卡片，显示“计划已创建”，并提供 Today、项目总览、日历、继续添加入口。

## P1 高优先级体验问题

### P1-1 入口命名混乱
- **归属:** `polish-add-initiate-language-input`
- **建议:** 统一为用户结果导向文案，例如“添加学习内容”作为入口，“创建计划 / 保存资料 / 加到已有计划”作为下一步。

### P1-2 输入前先选类型增加认知负担
- **归属:** `polish-add-initiate-language-input`
- **建议:** 允许直接粘贴内容，类型作为自动识别后的可编辑辅助项；去掉 raw value 展示。

### P1-3 角色确认暴露机器语言
- **归属:** `polish-add-initiate-language-input`
- **建议:** 显示自然语言摘要；raw reason code 只保留在 debug/test。

### P1-4 非计划条目可能被误认为已保存
- **归属:** `fix-add-initiate-state-boundaries`
- **建议:** 路由推荐后先显示确认卡，用户确认后才显示已保存。

### P1-5 长输入会直接成为标题
- **归属:** `polish-add-initiate-language-input`
- **建议:** 在角色确认或规划锚点前提供标题预览/编辑。

## P2 中优先级体验问题

### P2-1 规划锚点表单过于工程化
- **归属:** `polish-add-initiate-language-input`
- **建议:** 日期做本地校验；目标深度改成用户能理解的选项。

### P2-2 不可行选项缺少参数入口
- **归属:** `harden-add-initiate-draft-review`
- **建议:** 选项按钮打开参数确认区；如果复用已有锚点值，也要显式展示。

### P2-3 成功、取消、存储后的下一步不够清楚
- **归属:** `fix-add-initiate-state-boundaries`
- **建议:** 为每个终态提供一个主行动和一个次行动。

### P2-4 底部导航项目过多且标签拥挤
- **归属:** future follow-up
- **建议:** 暂不纳入上述三个 changes；后续单独做导航信息架构调整。

## 建议执行顺序

1. `fix-add-initiate-state-boundaries`
2. `polish-add-initiate-language-input`
3. `harden-add-initiate-draft-review`

每个 change 在 apply 前都应单独跑 `opsx:apply-readiness`，并重新检查 subagent dispatch 边界。
