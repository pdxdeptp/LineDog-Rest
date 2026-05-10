## MODIFIED Requirements

### Requirement: 用户审核后写入
系统 SHALL 在用户确认前暂停导入流程，不自动写入数据库。

#### Scenario: 用户确认（含参数覆盖）
- **WHEN** 用户调用 `POST /api/ingest/confirm`，携带 `thread_id`、`confirmed=true`、`selected_option`，以及可选的 `deadline` 和 `speed_factor`
- **THEN** 系统优先使用请求中的 `deadline` / `speed_factor`（若存在），否则使用 graph state 中的值
- **AND** 按用户选择的方案写入 resources、units、tasks
- **AND** 写入 `resource_added` 事件
- **AND** 删除当日 briefing 缓存

#### Scenario: 用户取消
- **WHEN** 用户调用 `POST /api/ingest/confirm` 且 `confirmed=false`
- **THEN** 系统返回 `status='cancelled'`
- **AND** 不写入学习资料、单元或任务

### Requirement: 排期方案草稿
系统 SHALL 为导入资料生成两个排期方案，默认推荐"均匀铺开"。

#### Scenario: 方案 A（尽快学完）
- **WHEN** 系统生成 Option A
- **THEN** 系统按日期顺序贪心填充 deadline 前的剩余 capacity

#### Scenario: 方案 B（均匀铺开）
- **WHEN** 系统生成 Option B
- **THEN** 系统从今天开始按天均匀铺开学习单元，每天一个单元

#### Scenario: 前端默认选中方案 B
- **WHEN** 草稿首次展示给用户
- **THEN** 前端默认选中"均匀铺开"（Option B）
- **AND** 确认写入时使用 B 方案排期（除非用户主动切换至 A）

### Requirement: 每日学习容量默认值
系统 SHALL 将 `daily_capacity_min` 初始默认值设为 60 分钟。

#### Scenario: 全新数据库
- **WHEN** 系统初始化数据库，`system_state` 中无 `daily_capacity_min` 记录
- **THEN** 系统写入默认值 `60`（分钟）

#### Scenario: ingestion_agent 回退值
- **WHEN** `ingestion_agent` 读取 `daily_capacity_min` 且 key 不存在
- **THEN** 使用 60 分钟作为回退值（不使用 300）

### Requirement: 重新排期（不重新解析）
系统 SHALL 支持在确认前用新参数重新生成排期，无需重新解析 URL 或调用 LLM。

#### Scenario: 调整参数后重新排期
- **WHEN** 用户调用 `POST /api/ingest/reschedule`，携带 `thread_id`、`deadline`、`speed_factor`
- **THEN** 系统从 LangGraph 状态中读取已解析的 `resource` 结构
- **AND** 用新参数重新运行调度算法，生成新 `option_a / option_b`
- **AND** 返回新草稿，不写入数据库，不推进 LangGraph 图

#### Scenario: reschedule 的 thread 不存在或已完成
- **WHEN** `thread_id` 对应的 graph state 不存在或已写库
- **THEN** 系统返回 HTTP 404 或 HTTP 409（冲突）

## ADDED Requirements

### Requirement: 草稿卡片方案选择器可交互
前端 SHALL 提供可点击的方案选择按钮，允许用户在"尽快学完"和"均匀铺开"之间切换。

#### Scenario: 切换方案
- **WHEN** 用户点击"尽快学完"或"均匀铺开"按钮
- **THEN** 按钮响应点击（hit area 覆盖全宽）
- **AND** 选中状态更新，视觉高亮变化

### Requirement: 草稿卡片参数调整
前端 SHALL 在草稿卡片内提供 deadline 和 speed_factor 调整控件。

#### Scenario: 用户修改 deadline
- **WHEN** 用户在草稿卡片中修改截止日期
- **THEN** 500ms debounce 后，前端自动调用 `/api/ingest/reschedule`
- **AND** 草稿卡片就地刷新（带过渡动画），展示新排期

#### Scenario: 用户修改 speed_factor
- **WHEN** 用户拖动草稿卡片中的速度 Slider
- **THEN** 拖动结束 500ms 后，前端自动调用 `/api/ingest/reschedule`
- **AND** 草稿卡片就地刷新，展示新排期

### Requirement: 完整计划弹窗（只读）
前端 SHALL 提供完整每日排期预览弹窗。

#### Scenario: 打开完整计划
- **WHEN** 用户点击草稿卡片中的"查看完整计划"按钮
- **THEN** 系统打开弹窗，展示当前选中方案的完整每日排期
- **AND** 列表可滚动，每行显示：日期 + 单元标题 + 预计分钟
- **AND** 弹窗顶部显示方案名称及汇总行：总集数、总时长、截止日期
- **AND** 若所有单元均已排入截止日前，汇总行显示"全部 N 集已排入计划"
- **AND** 若存在单元无法排入截止日前（option_a 容量不足），汇总行显示"X 集因容量不足未能排入截止日前"

#### Scenario: 切换方案后弹窗同步
- **WHEN** 用户在主卡片切换方案后重新打开弹窗
- **THEN** 弹窗显示新方案的排期内容

### Requirement: 取消后保留 URL
前端 SHALL 在用户取消草稿后保留 URL 输入框内容。

#### Scenario: 取消草稿
- **WHEN** 用户点击"取消"
- **THEN** 草稿卡片消失
- **AND** URL TextField 内容保持不变
- **AND** 数据库无写入

### Requirement: 草稿显示每日学习容量
前端 SHALL 在草稿卡片内显示当前每日学习容量，并提供跳转设置入口。

#### Scenario: 显示容量
- **WHEN** 草稿卡片展示
- **THEN** 显示"每日容量：X 分钟"（从后端 learning preferences API 读取）
- **AND** 旁边显示"去设置 →"跳转链接

#### Scenario: 跳转学习偏好设置
- **WHEN** 用户点击"去设置 →"
- **THEN** 前端导航至学习偏好设置页

### Requirement: 重新排期失败处理
前端 SHALL 在 reschedule 请求失败时保留上一次成功的排期，不阻断用户继续确认。

#### Scenario: reschedule 网络或服务失败
- **WHEN** `POST /api/ingest/reschedule` 返回错误或超时
- **THEN** 草稿卡片仍显示上一次成功的排期内容
- **AND** 卡片内显示"重新排期失败，请稍后重试"提示
- **AND** "确认写入"按钮恢复可用（用上一次排期数据写入）

### Requirement: 确认写入失败处理
前端 SHALL 在 confirm 请求失败时保留草稿，允许用户重试。

#### Scenario: confirm 网络或服务失败
- **WHEN** `POST /api/ingest/confirm` 返回错误或超时
- **THEN** 草稿卡片保持不变（不消失）
- **AND** 卡片内显示"写入失败，请重试"提示
- **AND** "确认写入"按钮重新变为可用

### Requirement: 确认写入成功反馈
前端 SHALL 在 confirm 成功后给出明确的成功反馈，并恢复到可添加新资料的状态。

#### Scenario: confirm 成功
- **WHEN** `POST /api/ingest/confirm` 返回 `status='written'`
- **THEN** 草稿卡片消失
- **AND** IngestionView 回到空输入状态（URL TextField 清空）
- **AND** 显示短暂的成功提示（toast 形式，约 2 秒）
- **AND** 首页今日任务刷新（触发 `loadDashboard`）

### Requirement: 确认写入按钮仅在排期与当前参数同步时可用
前端 SHALL 追踪当前参数是否已与最近一次成功排期同步，仅在同步时允许确认写入。

#### Scenario: reschedule 进行中
- **WHEN** 前端已发出 `POST /api/ingest/reschedule` 且尚未收到响应
- **THEN** "确认写入"按钮处于禁用状态（视觉灰显，无文字说明）

#### Scenario: reschedule 成功后
- **WHEN** reschedule 请求返回成功，新排期已同步
- **THEN** "确认写入"按钮恢复可用

#### Scenario: reschedule 失败且参数已变更
- **WHEN** reschedule 请求返回错误，且当前 deadline 或 speed_factor 与上次成功排期时的参数不同
- **THEN** "确认写入"按钮保持禁用（不因失败而恢复）
- **AND** 卡片显示"重新排期失败，请稍后重试"提示

#### Scenario: reschedule 失败但参数未变
- **WHEN** reschedule 请求返回错误，但用户已将 deadline 和 speed_factor 改回上次成功排期时的值
- **THEN** "确认写入"按钮恢复可用（当前显示的排期与参数一致）

### Requirement: 重新排期或确认时会话失效处理
前端 SHALL 识别 thread 不存在（进程重启导致 MemorySaver 丢失）的情况，并引导用户重新提交而非重试。

#### Scenario: reschedule 返回 thread_not_found
- **WHEN** `POST /api/ingest/reschedule` 返回 HTTP 404 且响应体包含 `{"error": "thread_not_found"}`
- **THEN** 前端清除当前草稿状态（ingestionDraft、ingestionThreadId）
- **AND** 显示"分析会话已失效，请重新提交链接"（而非"请稍后重试"）
- **AND** URL TextField 内容保持不变

#### Scenario: confirm 返回 thread_not_found
- **WHEN** `POST /api/ingest/confirm` 返回 HTTP 404 且响应体包含 `{"error": "thread_not_found"}`
- **THEN** 前端清除草稿状态
- **AND** 显示"写入失败：分析会话已失效，请重新提交链接"
- **AND** URL TextField 内容保持不变

### Requirement: 排期方案为空时的弹窗处理
前端 SHALL 在完整计划弹窗中处理方案排期为空的边缘情况。

#### Scenario: 当前方案排期为空
- **WHEN** 用户点击"查看完整计划"，但当前选中方案的排期数组为空（如截止日已过或容量不足）
- **THEN** 弹窗打开，显示提示信息："当前参数下无法在截止日前安排任何任务，请调整截止日期或每日学习容量"
- **AND** 不渲染空列表
