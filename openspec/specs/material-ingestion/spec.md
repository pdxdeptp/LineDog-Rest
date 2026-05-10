# material-ingestion Specification

## Purpose

学习助手支持从学习资料 URL 生成结构化学习计划草稿。当前实现通过 FastAPI 调用 LangGraph Ingestion Agent，识别资料类型、抽取学习单元、估算工时、生成两个排期方案，并在用户确认后写入本地数据库。

## Requirements

### Requirement: 资料 URL 类型识别
系统 SHALL 根据用户输入 URL 选择对应 Handler。

#### Scenario: GitHub repo URL
- **WHEN** 用户输入包含 `github.com/` 的 URL
- **THEN** 系统使用 GitHub Handler 处理该资料

#### Scenario: Bilibili 视频 URL
- **WHEN** 用户输入匹配 `bilibili.com/video/BV*` 的 URL
- **THEN** 系统使用 Bilibili Handler 处理该资料

#### Scenario: PDF URL
- **WHEN** 用户输入以 `.pdf` 结尾或查询串前为 `.pdf` 的 URL
- **THEN** 系统使用 PDF Handler 处理该资料

#### Scenario: 其他 URL
- **WHEN** 用户输入不匹配已知类型的 URL
- **THEN** 系统使用 Web Handler 兜底处理

### Requirement: 归一化资料结构
所有 Handler SHALL 返回统一的 `ResourceStructure`。

#### Scenario: Handler 输出
- **WHEN** 任意 Handler 完成解析
- **THEN** 输出包含 title、type、tracking_mode、url、units、total_estimated_hours
- **AND** 每个 unit 包含 title、order_index、estimated_minutes

### Requirement: GitHub 结构提取
GitHub Handler SHALL 优先从 README 和目录结构中提取学习单元。

#### Scenario: README 包含目录
- **WHEN** README 中存在目录、章节、lesson、module 或编号链接结构
- **THEN** 系统优先调用 LLM 从 README 中提取有序学习单元

#### Scenario: README 不可用或无目录
- **WHEN** README 不能提供明确结构，但仓库目录存在章节式目录名
- **THEN** 系统从目录树中推断学习单元

#### Scenario: 结构提取兜底
- **WHEN** README 与目录树都不能提供学习单元
- **THEN** 系统使用 LLM 根据 repo 名称生成学习单元
- **AND** 若 LLM 失败，系统至少返回一个以 repo 名称命名的 unit

### Requirement: Bilibili 结构提取
Bilibili Handler SHALL 区分合集、分 P 视频和单视频。

#### Scenario: 合集视频
- **WHEN** Bilibili view API 返回 `ugc_season`
- **THEN** 系统按合集 episodes 生成有序 units

#### Scenario: 分 P 视频
- **WHEN** pagelist 返回多个 P
- **THEN** 系统为每个 P 创建一个 unit
- **AND** 若 duration 存在，系统将秒数换算为 estimated_minutes

#### Scenario: 单视频
- **WHEN** 资料不是合集且不是多 P
- **THEN** 系统创建一个 unit

### Requirement: 缺失工时估算
系统 SHALL 对缺失 estimated_minutes 的学习单元执行 LLM 批量估算。

#### Scenario: 有缺失估时
- **WHEN** Handler 返回的部分 unit `estimated_minutes = null`
- **THEN** 系统调用 LLM 估算这些 unit 的学习分钟数

#### Scenario: 估算失败
- **WHEN** LLM 估算失败
- **THEN** 系统保留原始 unit 列表
- **AND** 后续排期使用默认 30 分钟作为该 unit 的临时估算

### Requirement: 排期方案草稿
系统 SHALL 为导入资料生成两个排期方案。

#### Scenario: 方案 A
- **WHEN** 系统生成 Option A
- **THEN** 系统按日期顺序填充 deadline 前的剩余 capacity

#### Scenario: 方案 B
- **WHEN** 系统生成 Option B
- **THEN** 系统从今天开始按天均匀铺开学习单元

### Requirement: 用户审核后写入
系统 SHALL 在用户确认前暂停导入流程，不自动写入数据库。

#### Scenario: 返回待确认草稿
- **WHEN** `POST /api/ingest` 到达 `present_draft`
- **THEN** API 返回 `thread_id`、`status='pending_confirmation'` 和 draft

#### Scenario: 用户确认
- **WHEN** 用户调用 `POST /api/ingest/confirm` 且 `confirmed=true`
- **THEN** 系统按用户选择的方案写入 resources、units、tasks
- **AND** 系统写入 `resource_added` 事件
- **AND** 系统删除当日 briefing 缓存，使下一次今日简报反映新任务

#### Scenario: 用户取消
- **WHEN** 用户调用 `POST /api/ingest/confirm` 且 `confirmed=false`
- **THEN** 系统返回 `status='cancelled'`
- **AND** 不写入学习资料、单元或任务
