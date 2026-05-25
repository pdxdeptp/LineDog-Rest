## MODIFIED Requirements

### Requirement: Tab 导航
学习助手中栏 SHALL 以首页 dashboard 作为后端就绪后的默认入口，并 SHALL 使用底部固定导航提供首页、添加/立项、资料进度和调整计划入口。

#### Scenario: 后端就绪后的默认入口
- **WHEN** 后端已连接且未离线
- **THEN** 中栏默认显示学习助手首页 dashboard
- **AND** 首页优先展示今日摘要、任务数量、总分钟数和资料风险
- **AND** 不将某一项任务作为系统推荐的下一步主行动

#### Scenario: 底部固定导航
- **WHEN** 中栏显示首页或任一学习助手工具页
- **THEN** 底部导航显示首页、添加/立项、资料进度和调整计划入口
- **AND** 底部导航固定在学习助手中栏底部
- **AND** 上方首页信息流滚动时底部导航仍保持可见

#### Scenario: 进入次级工具
- **WHEN** 用户点击底部导航中的添加/立项、资料进度或调整计划
- **THEN** 中栏切换到对应功能界面
- **AND** 用户可通过底部导航回到首页

#### Scenario: 导航降噪
- **WHEN** 首页首次渲染
- **THEN** 今日任务、资料进度、对话和添加/立项不作为四个同等优先级的第一屏内容平铺展示

### Requirement: 添加/立项视图
添加/立项 Tab SHALL support submitting learning or project items, route them into plan-generating or non-plan roles, and show a draft review before any active daily tasks are created.

#### Scenario: 提交目标或资料
- **WHEN** 用户输入目标文本、URL、GitHub repo、已有项目说明、面试训练项、简历素材或笔记片段并点击继续
- **THEN** 前端调用 intake route 获取推荐角色、置信度、理由和下一步动作
- **AND** 前端不直接调用旧 URL ingest path 创建 active tasks

#### Scenario: 角色确认
- **WHEN** intake route 返回推荐角色
- **THEN** 前端显示低成本确认控件，允许用户接受推荐角色或切换为新计划、挂到已有计划、参考资料、以后再看或暂不处理
- **AND** 当前端展示“支撑资料”时，该选择写入为挂到已有计划 + material-only attachment mode
- **AND** 若角色不需要排期，前端提供存档或挂载确认而不是计划生成表单

#### Scenario: 生成计划草案
- **WHEN** 用户确认该 item 需要新计划或已有计划阶段排期
- **THEN** 前端收集或展示 deadline、可用时间、目标产出和目标深度
- **AND** 前端允许用户接受推荐假设后继续生成草案

#### Scenario: 展示计划草案
- **WHEN** 后端返回计划草案
- **THEN** 前端默认展示计划角色、关键假设、第一周每日安排、buffer 摘要、低能量保底摘要、容量风险和截止风险
- **AND** 完整日程、资料结构和逐任务编辑通过明确入口展开
- **AND** 草案仍不进入 Today

#### Scenario: 展示处理进度
- **WHEN** 添加/立项流程正在分析、路由、预览资料、生成阶段、生成任务、校验任务、排期或准备 review
- **THEN** 前端展示当前处理阶段
- **AND** 不把处理中状态误显示为已创建今日任务

#### Scenario: 确认草案
- **WHEN** 用户点击确认立项
- **THEN** 前端调用确认接口激活计划
- **AND** 成功后刷新首页、今日任务、项目总览和日历事实

#### Scenario: 激活失败保留草案
- **WHEN** 确认立项失败
- **THEN** 前端保留当前草案和错误状态
- **AND** 用户可以重试确认、继续编辑或取消

#### Scenario: 取消草案
- **WHEN** 用户取消计划草案
- **THEN** 前端不创建 active tasks
- **AND** 允许用户丢弃 item 或存为以后再看

#### Scenario: GitHub repo role controls UI
- **WHEN** 用户提交 GitHub repo
- **THEN** 前端显示 repo role choices backed by canonical ids such as `main_learning_object`, `reference_source`, `clone_rebuild_target`, `project_material`, and `later_reading`
- **AND** 只有 plan-generating roles lead to draft scheduling

#### Scenario: 添加不生成今日行动
- **WHEN** 用户刚刚提交、路由、存档、挂载或生成未确认草案
- **THEN** 前端不在 Today 中显示该 item 的行动
- **AND** 前端不显示由该 item 触发的今日推荐行动

#### Scenario: 非计划条目不制造提醒噪音
- **WHEN** 用户把 item 存为支撑资料、参考资料或以后再看
- **THEN** 前端不为该 item 创建 Today badge、deadline 风险提示或智能模式提议入口
- **AND** 该 item 只在用户进入相关计划材料或资源列表时可见

#### Scenario: 不可行草案显示选择而不是错误
- **WHEN** 后端返回 infeasible review 草案
- **THEN** 前端显示容量缺口、超载、预计延期或 buffer 被吃掉的事实
- **AND** 前端提供 canonical infeasibility option ids 对应的本地化选项，例如降 scope、降低深度、延 deadline、增加容量、接受 crunch、接受 buffer 风险、接受超载、接受软延期或存为以后再看

#### Scenario: 硬 deadline 不提供接受延期
- **WHEN** 不可行草案的 deadline type 是 hard
- **THEN** 前端不显示 `accept_late_finish` 对应选项
- **AND** 前端只显示需要改变 scope、深度、deadline、容量、超载/crunch 或存为以后再看的选项

#### Scenario: 草案过期时阻止激活
- **WHEN** 用户尝试确认的 draft version 已经过期
- **THEN** 前端显示草案已更新或过期
- **AND** 不把旧版本写入 active plan
