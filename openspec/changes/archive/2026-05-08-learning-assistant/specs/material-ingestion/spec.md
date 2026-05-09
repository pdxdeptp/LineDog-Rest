## ADDED Requirements

### Requirement: 资料类型识别与分发
系统 SHALL 根据输入 URL 或文件自动识别资料类型，并路由至对应 Handler。支持类型：`github_repo`、`bilibili_series`、`pdf`、`web_article`。未识别类型 SHALL 使用 Generic Scraper 兜底。

#### Scenario: GitHub repo 识别
- **WHEN** 用户输入 `github.com/*` 格式 URL
- **THEN** 系统路由至 GitHub Handler，使用 GitHub API 读取 README 和目录树

#### Scenario: B站合集识别
- **WHEN** 用户输入 `bilibili.com/video/BV*` 格式 URL
- **THEN** 系统检测视频是否属于合集（分P或playlist），若是则拉取完整合集列表

#### Scenario: 未识别类型兜底
- **WHEN** 用户输入不匹配任何已知模式的 URL
- **THEN** 系统使用 Generic Scraper 抓取页面内容，提取标题和章节结构后继续流程

---

### Requirement: GitHub Handler — 结构提取优先级
GitHub Handler SHALL 按以下优先级提取章节结构：
1. README 中的目录/Roadmap（LLM 解析）
2. 顶层目录结构（GitHub API tree）
3. LLM 兜底估算

#### Scenario: README 含目录
- **WHEN** GitHub repo 的 README 包含明确的章节列表或 Table of Contents
- **THEN** 系统优先使用 README 中的结构作为 units，不再读目录树

#### Scenario: README 无目录但有目录结构
- **WHEN** README 中没有明确目录，但 repo 有 chapters/lessons 等命名的子目录
- **THEN** 系统使用目录树推断章节，每个一级子目录对应一个 unit

---

### Requirement: Bilibili Handler — 三种视频形态处理
Bilibili Handler SHALL 区分并处理三种形态：单个视频（返回单 unit）、分P视频（返回每P一个 unit）、合集/系列（返回合集中所有视频为 units）。每个 unit SHALL 包含视频时长（秒）。

#### Scenario: 分P视频
- **WHEN** BV 号下存在多个 P（通过 `/x/player/pagelist` 接口检测）
- **THEN** 系统为每个 P 创建一个 unit，标题取分P标题，estimated_minutes 取视频时长

#### Scenario: 合集视频
- **WHEN** 视频属于某个合集（playlist/season）
- **THEN** 系统拉取整个合集的视频列表，为所有视频创建 units，按合集顺序排列

#### Scenario: Bilibili API 失败降级
- **WHEN** Bilibili API 返回错误或超时
- **THEN** 系统降级为单视频处理，仅创建一个 unit，estimated_minutes 设为 null，由 LLM 估算

---

### Requirement: 归一化中间格式
所有 Handler SHALL 输出统一的 ResourceStructure 格式，Scheduling Agent 仅消费此格式。

```
ResourceStructure {
  title: str
  type: str              # github_repo / bilibili_series / pdf / web_article
  tracking_mode: str     # sequential | pool
  url: str
  units: [
    { title, order_index, estimated_minutes }
  ]
  total_estimated_hours: float
}
```

#### Scenario: 归一化输出一致性
- **WHEN** 任意 Handler 完成解析
- **THEN** 输出必须包含 title、type、tracking_mode、units 字段，estimated_minutes 可为 null（由 LLM 估算补全）

---

### Requirement: 工时估算（方案 B+C）
系统 SHALL 使用 LLM 基于资料结构和内容摘要估算每个 unit 的 estimated_minutes（方案 B），并乘以 `resource.speed_factor`（用户个人速度系数，方案 C）。

#### Scenario: LLM 估算触发
- **WHEN** Handler 解析完成但部分 unit 的 estimated_minutes 为 null
- **THEN** 系统调用 LLM，传入资料类型、章节标题列表和内容摘要，补全所有 null 估算值

#### Scenario: speed_factor 应用
- **WHEN** 生成 ResourceStructure 后计算 total_estimated_hours
- **THEN** total_estimated_hours = sum(estimated_minutes) / 60 × resource.speed_factor

---

### Requirement: 容量冲突检测与 Option 3 交互
当用户向已有运行计划中添加新资料时，系统 SHALL 计算 capacity 冲突，并向用户呈现两个方案：仅填空档（Option A）或全局重排（Option B），由用户选择。

#### Scenario: 容量充足（无冲突）
- **WHEN** 新资料所需工时 ≤ deadline 前剩余空余 capacity
- **THEN** 系统直接生成填空档方案，无需呈现 Option B

#### Scenario: 容量不足（有冲突）
- **WHEN** 新资料导致 deadline 前 capacity 溢出
- **THEN** 系统生成两个方案草稿并提示用户选择：[仅填空档，部分内容可能超期] [全局重排，影响现有任务 X 天]

#### Scenario: 用户审核草稿
- **WHEN** 系统生成任务草稿（含每日任务分配和总工时预估）
- **THEN** 系统 SHALL 暂停（LangGraph interrupt），等待用户确认、修改或取消，不自动写入 DB

---

### Requirement: 草稿确认后写入
用户确认草稿后，系统 SHALL 原子性地写入 resources 表、units 表和 tasks 表。

#### Scenario: 写入成功
- **WHEN** 用户确认 Ingestion 草稿
- **THEN** 系统在一个事务内插入 resource 行、所有 unit 行、所有 task 行，并写入 events 表 `resource_added` 事件

#### Scenario: 写入失败回滚
- **WHEN** 写入过程中发生错误
- **THEN** 整个事务回滚，DB 保持原状，向用户返回错误信息
