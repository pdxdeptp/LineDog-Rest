SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS resources (
    id              INTEGER PRIMARY KEY,
    title           TEXT    NOT NULL,
    type            TEXT    NOT NULL,
    tracking_mode   TEXT    NOT NULL DEFAULT 'sequential',
    url             TEXT,
    status          TEXT    NOT NULL DEFAULT 'active',
    total_units     INTEGER,
    completed_units INTEGER DEFAULT 0,
    actual_minutes_total INTEGER DEFAULT 0,
    estimated_hours REAL,
    speed_factor    REAL    DEFAULT 1.0,
    deadline        DATE,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS units (
    id                INTEGER PRIMARY KEY,
    resource_id       INTEGER NOT NULL REFERENCES resources(id),
    title             TEXT    NOT NULL,
    order_index       INTEGER NOT NULL,
    estimated_minutes INTEGER,
    actual_minutes    INTEGER,
    status            TEXT    NOT NULL DEFAULT 'pending',
    completed_at      TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_units_resource_order ON units(resource_id, order_index);

CREATE TABLE IF NOT EXISTS tasks (
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
    auto_roll_days            INTEGER DEFAULT 0,
    last_auto_rolled_at       DATE,
    user_adjusted_at          TIMESTAMP,
    priority                  INTEGER DEFAULT 0,
    completed_at              TIMESTAMP,
    actual_minutes            INTEGER,
    created_at                TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tasks_scheduled_date ON tasks(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_tasks_resource_id    ON tasks(resource_id);

CREATE TABLE IF NOT EXISTS study_project_drafts (
    id                    INTEGER PRIMARY KEY,
    title                 TEXT    NOT NULL,
    source_url            TEXT    NOT NULL,
    deadline              DATE    NOT NULL,
    status                TEXT    NOT NULL DEFAULT 'review',
    capacity_minutes      INTEGER NOT NULL,
    clarification_skipped INTEGER NOT NULL DEFAULT 0,
    metadata              TEXT,
    activated_resource_id INTEGER REFERENCES resources(id),
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_study_project_drafts_status ON study_project_drafts(status);

CREATE TABLE IF NOT EXISTS study_project_draft_tasks (
    id                INTEGER PRIMARY KEY,
    draft_id          INTEGER NOT NULL REFERENCES study_project_drafts(id),
    title             TEXT    NOT NULL,
    order_index       INTEGER NOT NULL,
    estimated_minutes INTEGER NOT NULL,
    scheduled_date    DATE    NOT NULL,
    target_minutes    INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_study_project_draft_tasks_order
    ON study_project_draft_tasks(draft_id, order_index);

CREATE TABLE IF NOT EXISTS plan_versions (
    id              INTEGER PRIMARY KEY,
    content         TEXT    NOT NULL,
    change_summary  TEXT,
    triggered_by    TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS events (
    id          INTEGER PRIMARY KEY,
    event_type  TEXT    NOT NULL,
    payload     TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_events_type_time ON events(event_type, created_at);

CREATE TABLE IF NOT EXISTS system_state (
    key        TEXT PRIMARY KEY,
    value      TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"""

DEFAULT_SYSTEM_STATE = {
    "load_mode": "normal",
    "daily_capacity_min": "60",
    "reduced_capacity_min": "60",
    "user_speed_factor": "1.0",
    "study_rest_weekdays": "[5]",
    "study_rest_dates": "[]",
}
