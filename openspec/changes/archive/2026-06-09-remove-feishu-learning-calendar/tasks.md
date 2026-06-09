# Tasks: remove-feishu-learning-calendar

## 1. OpenSpec / docs prep

- [x] 1.1 `openspec validate remove-feishu-learning-calendar --strict`
- [x] 1.2 Mark `fix-learning-rollover-calendar` cancelled in follow-up doc (do not apply)

## 2. Hermes schedule.py

- [x] 2.1 Remove Feishu API helpers, `calendar-sync`, `calendar_create/patch/delete` usage
- [x] 2.2 Strip calendar branches from plan/complete/move/insert/remove/rollover/review/set-deadline
- [x] 2.3 Remove `calendar_errors`, `feishu_event_id` from outputs and new task writes
- [x] 2.4 Remove `--no-calendar` argparse flags

## 3. Hermes data & tests

- [x] 3.1 Update default profile template / migration note for removed keys
- [x] 3.2 Delete or gut `test_schedule_calendar.py`; fix smoke + set-deadline/move tests
- [x] 3.3 Run `pytest tests/learning-assistant/` (18 passed)

## 4. Hermes skill & cross-repo spec

- [x] 4.1 Update `learning-assistant/SKILL.md` — remove calendar sections
- [x] 4.2 Remove `calendar-setup.md`, `calendar-orphan-cleanup.md`
- [x] 4.3 Deprecate note in `~/.hermes/openspec/.../learning-calendar-sync` + build-hermes v1 proposal

## 5. MalDaze

- [x] 5.1 Remove `calendarErrors` from models and ViewModel notices
- [x] 5.2 Update tests
- [x] 5.3 Update `docs/integrations/hermes.md`, `learning-desk-panel.md`, `ROADMAP.md`, `learning-calendar.md`

## 6. Verification

- [x] 6.1 `openspec validate remove-feishu-learning-calendar --strict`
- [x] 6.2 MalDaze unit tests for learning panel models/VM
- [x] 6.3 MANUAL_QA checklist entry (user) — C-R1 JSON-only · C-2 无 calendar 字段
