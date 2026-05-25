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
    fallback_completed_at     TIMESTAMP,
    fallback_actual_minutes   INTEGER,
    needs_followup            INTEGER DEFAULT 0,
    created_at                TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tasks_scheduled_date ON tasks(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_tasks_resource_id    ON tasks(resource_id);

CREATE TABLE IF NOT EXISTS study_project_drafts (
    id                    INTEGER PRIMARY KEY,
    intake_item_id        INTEGER REFERENCES study_intake_items(id),
    title                 TEXT    NOT NULL,
    source_url            TEXT    NOT NULL,
    deadline              DATE    NOT NULL,
    status                TEXT    NOT NULL DEFAULT 'review',
    schema_version        INTEGER NOT NULL DEFAULT 1,
    draft_version         INTEGER NOT NULL DEFAULT 1,
    latest_version        INTEGER NOT NULL DEFAULT 1,
    calibration_level     TEXT    NOT NULL DEFAULT 'standard',
    draft_kind            TEXT    NOT NULL DEFAULT 'new_plan',
    target_plan_id        INTEGER REFERENCES resources(id),
    capacity_minutes      INTEGER NOT NULL,
    clarification_skipped INTEGER NOT NULL DEFAULT 0,
    metadata              TEXT,
    activated_resource_id INTEGER REFERENCES resources(id),
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_study_project_drafts_status ON study_project_drafts(status);

CREATE TABLE IF NOT EXISTS study_project_draft_tasks (
    id                INTEGER PRIMARY KEY,
    draft_id          INTEGER NOT NULL REFERENCES study_project_drafts(id),
    stable_task_id    TEXT,
    phase_id          TEXT,
    title             TEXT    NOT NULL,
    order_index       INTEGER NOT NULL,
    estimated_minutes INTEGER NOT NULL,
    scheduled_date    DATE    NOT NULL,
    target_minutes    INTEGER NOT NULL,
    status            TEXT    NOT NULL DEFAULT 'draft',
    metadata          TEXT,
    schedule_slices   TEXT
);
CREATE INDEX IF NOT EXISTS idx_study_project_draft_tasks_order
    ON study_project_draft_tasks(draft_id, order_index);

CREATE TABLE IF NOT EXISTS study_project_draft_versions (
    id                     INTEGER PRIMARY KEY,
    draft_id               INTEGER NOT NULL REFERENCES study_project_drafts(id),
    draft_version          INTEGER NOT NULL,
    schema_version         INTEGER NOT NULL DEFAULT 1,
    status                 TEXT    NOT NULL,
    summary                TEXT,
    assumptions            TEXT    NOT NULL DEFAULT '{}',
    package_json           TEXT    NOT NULL DEFAULT '{}',
    phases                 TEXT    NOT NULL DEFAULT '[]',
    tasks                  TEXT    NOT NULL DEFAULT '[]',
    review_summary         TEXT    NOT NULL DEFAULT '{}',
    activation_eligibility TEXT    NOT NULL DEFAULT '{}',
    created_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(draft_id, draft_version)
);
CREATE INDEX IF NOT EXISTS idx_study_project_draft_versions_latest
    ON study_project_draft_versions(draft_id, draft_version);

CREATE TABLE IF NOT EXISTS study_intake_items (
    id                  INTEGER PRIMARY KEY,
    client_request_id   TEXT    NOT NULL UNIQUE,
    raw_input           TEXT    NOT NULL,
    source_type         TEXT    NOT NULL,
    recommended_role    TEXT    NOT NULL,
    confidence          TEXT    NOT NULL,
    reason_codes        TEXT    NOT NULL DEFAULT '[]',
    next_action         TEXT    NOT NULL DEFAULT 'role_review',
    confirmation_state  TEXT    NOT NULL DEFAULT 'pending',
    calibration_level   TEXT    NOT NULL DEFAULT 'standard',
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_study_intake_items_role_state
    ON study_intake_items(recommended_role, confirmation_state);

CREATE TABLE IF NOT EXISTS study_intake_non_plan_items (
    id             INTEGER PRIMARY KEY,
    intake_item_id INTEGER NOT NULL UNIQUE REFERENCES study_intake_items(id),
    role           TEXT    NOT NULL,
    title          TEXT    NOT NULL,
    url            TEXT,
    metadata       TEXT,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_study_intake_non_plan_items_role
    ON study_intake_non_plan_items(role);

CREATE TABLE IF NOT EXISTS study_intake_plan_attachments (
    id              INTEGER PRIMARY KEY,
    intake_item_id  INTEGER NOT NULL UNIQUE REFERENCES study_intake_items(id),
    target_plan_id  INTEGER NOT NULL REFERENCES resources(id),
    attachment_mode TEXT    NOT NULL,
    title           TEXT    NOT NULL,
    metadata        TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_study_intake_plan_attachments_target
    ON study_intake_plan_attachments(target_plan_id, attachment_mode);

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
