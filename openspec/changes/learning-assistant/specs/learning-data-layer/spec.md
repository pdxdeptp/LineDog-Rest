## ADDED Requirements

### Requirement: SQLite 数据库 Schema
系统 SHALL 使用单个 SQLite 文件（`learning.db`）存储所有运营数据，通过 aiosqlite 异步访问。数据库 SHALL 在后端首次启动时自动初始化（CREATE TABLE IF NOT EXISTS）。

#### Scenario: 首次启动初始化
- **WHEN** 后端进程启动且 `learning.db` 不存在
- **THEN** 系统自动创建所有表和索引，写入默认 `system_state` 键值（load_mode=normal，daily_capacity_min=300，reduced_capacity_min=60，pending_weekly_review=false，user_speed_factor=1.0）

---

### Requirement: resources 表
系统 SHALL 维护 resources 表，记录所有学习资料元数据。

```sql
CREATE TABLE resources (
    id              INTEGER PRIMARY KEY,
    title           TEXT    NOT NULL,
    type            TEXT    NOT NULL,
    tracking_mode   TEXT    NOT NULL DEFAULT 'sequential',
    url             TEXT,
    status          TEXT    NOT NULL DEFAULT 'active',
    total_units     INTEGER,
    completed_units INTEGER DEFAULT 0,
    estimated_hours REAL,
    speed_factor    REAL    DEFAULT 1.0,
    deadline        DATE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Scenario: 资料状态流转
- **WHEN** 某资料 completed_units = total_units
- **THEN** 系统 SHALL 将该资料 status 更新为 'completed'，并写入 `resource_completed` 事件

---

### Requirement: units 表
系统 SHALL 维护 units 表，记录 sequential 类型资料的子单元（chapters/videos）。pool 类型资料不创建 unit 行。

```sql
CREATE TABLE units (
    id                INTEGER PRIMARY KEY,
    resource_id       INTEGER NOT NULL REFERENCES resources(id),
    title             TEXT    NOT NULL,
    order_index       INTEGER NOT NULL,
    estimated_minutes INTEGER,
    actual_minutes    INTEGER,
    status            TEXT    NOT NULL DEFAULT 'pending',
    completed_at      TIMESTAMP
);
CREATE INDEX idx_units_resource_order ON units(resource_id, order_index);
```

#### Scenario: unit 完成更新
- **WHEN** 用户标记某任务完成且该任务关联 unit_id
- **THEN** 系统更新对应 unit 的 status='completed'、completed_at 和 actual_minutes，并将 resource.completed_units + 1

---

### Requirement: tasks 表
系统 SHALL 维护 tasks 表，记录每日调度的具体任务。

```sql
CREATE TABLE tasks (
    id                        INTEGER PRIMARY KEY,
    unit_id                   INTEGER REFERENCES units(id),
    resource_id               INTEGER REFERENCES resources(id),
    title                     TEXT    NOT NULL,
    task_kind                 TEXT    NOT NULL DEFAULT 'count',
    target_count              INTEGER,
    target_minutes            INTEGER,
    scheduled_date            DATE    NOT NULL,
    originally_scheduled_date DATE,
    reschedule_count          INTEGER DEFAULT 0,
    priority                  INTEGER DEFAULT 0,
    completed_at              TIMESTAMP,
    actual_minutes            INTEGER,
    created_at                TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_tasks_scheduled_date ON tasks(scheduled_date);
CREATE INDEX idx_tasks_resource_id    ON tasks(resource_id);
```

#### Scenario: 任务重排记录
- **WHEN** Morning Agent 将某任务从日期 A 移至日期 B
- **THEN** 更新 scheduled_date=B，reschedule_count+1，originally_scheduled_date 保持首次排入值不变

#### Scenario: 任务完成记录
- **WHEN** 用户在前端标记任务完成
- **THEN** 更新 completed_at=now()，actual_minutes 由用户输入或留 null

---

### Requirement: plan_versions 表
系统 SHALL 在每次 plan.md 被修改时向 plan_versions 表插入快照。plan.md 文件本身是 source of truth。

```sql
CREATE TABLE plan_versions (
    id           INTEGER PRIMARY KEY,
    content      TEXT    NOT NULL,
    change_summary TEXT,
    triggered_by TEXT,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Scenario: 修改触发快照
- **WHEN** 任何 Agent 修改 plan.md 后
- **THEN** 系统将修改后的完整内容插入 plan_versions，记录 triggered_by 来源

---

### Requirement: events 表（不可变事件流）
系统 SHALL 维护 events 表记录所有重要系统事件，已写入的行 SHALL NOT 被修改或删除。

```sql
CREATE TABLE events (
    id          INTEGER PRIMARY KEY,
    event_type  TEXT    NOT NULL,
    payload     TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_events_type_time ON events(event_type, created_at);
```

支持的 event_type：`task_completed`、`task_rescheduled`、`resource_added`、`resource_completed`、`plan_updated`、`load_mode_changed`、`weekly_review_done`

#### Scenario: 事件写入
- **WHEN** 任何上述系统行为发生
- **THEN** 系统在操作完成后向 events 表插入对应事件行，payload 为 JSON 格式的事件上下文数据

---

### Requirement: system_state 表（全局键值存储）
系统 SHALL 使用 system_state 表存储全局运行时状态，支持任意键值的 upsert 操作。

```sql
CREATE TABLE system_state (
    key        TEXT PRIMARY KEY,
    value      TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Scenario: 状态读取
- **WHEN** 任何 Agent 需要读取 load_mode 或 daily_capacity_min 等全局配置
- **THEN** 通过 `SELECT value FROM system_state WHERE key = ?` 读取，不在代码中硬编码默认值（默认值在初始化时写入）

---

### Requirement: plan.md 文件管理
系统 SHALL 维护一个 `plan.md` 文件（路径可通过环境变量 `PLAN_MD_PATH` 配置），作为战略规划的 source of truth。写入前 SHALL 获取文件锁防止并发冲突。

#### Scenario: plan.md 读取
- **WHEN** Agent 调用 get_current_plan 工具
- **THEN** 返回 plan.md 文件的完整文本内容

#### Scenario: plan.md 写入
- **WHEN** Agent 调用 rewrite_plan 工具
- **THEN** 系统获取文件锁 → 写入新内容 → 释放锁 → 向 plan_versions 插入快照
