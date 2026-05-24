# ITEM-003 Task 10.3 App Verification

Timestamp: 2026-05-24T13:43:32Z
Change: `introduce-study-plan-adjustment`
Current checkout only: yes
Worktree used: no

## Runtime

- App: `/Users/cpt/Library/Developer/Xcode/DerivedData/MalDaze-bpwxiacqyfwxjndsvopwqmqitret/Build/Products/Debug/MalDaze.app`
- App pid: `20460`
- Backend: `uvicorn src.main:app --host 127.0.0.1 --port 8765`
- Backend pid: `20482`
- Screenshot policy: no screenshots were saved because the app panel also exposes the user's Reminders sidebar. Evidence below uses Accessibility text, API responses, and runtime DB facts instead.
- Note: a second stale Debug app instance was visible (`pid 34444`), but all verification actions targeted the current checkout app path above.

## Temporary QA Data

Created a temporary active study project:

- Project id: `7`
- Title: `QA 10.3 Study Adjustment 20260524T1326Z`
- Initial task ids: `138`, `139`, `140`, `141`

Cleanup result:

- Temporary QA resource rows remaining: `0`
- Temporary QA task rows remaining: `0`
- Temporary QA unit rows remaining: `0`
- Rest-day settings restored to weekly `[5]` and one-off `[]`

## Verification Results

### Rollover Facts

- Triggered `POST /api/study-plan-adjustment/rollover`.
- Result included `rolled_count: 1` for task `138`, with `old_date=2026-05-20`, `new_date=2026-05-24`, `rolled_days=4`, and `auto_roll_days=4`.
- `GET /api/study-views/today` exposed `rolled_day_count=4` and `show_rolled_badge=true`.
- Current checkout app Today UI showed the QA task with the visible fact label `已滚动 4 天`.

### Manual Move Cascade

- Calendar UI compact move controls were used to move task `139` to `2026-05-27`.
- Runtime facts after move:
  - task `139`: `2026-05-25 -> 2026-05-27`
  - task `140`: `2026-05-26 -> 2026-05-28`
  - task `141`: `2026-08-01 -> 2026-08-03`
  - task `138` remained on `2026-05-24`
- Event `study_task_moved` recorded `affected_task_ids: [139, 140, 141]`.
- Calendar API and UI both showed `2026-05-25` and `2026-05-26` reduced to zero tasks, while `2026-05-27` and `2026-05-28` became over-capacity fact days.

### Deadline Red State

- Project Overview UI initially showed the temporary project with deadline `2026-08-10` and no expected-late fact.
- Using the deadline edit control, changed the project deadline to `2026-05-26`.
- Project Overview UI then showed the red fact `预计晚于截止日期`.
- No task dates were moved by the deadline edit.

### Add/Delete

- Calendar UI compact add controls inserted task `142` titled `QA UI added task` on `2026-05-29` with `30` minutes.
- Calendar UI and API showed `2026-05-29` changed to `1` task, `30` minutes, and `over_capacity=true`.
- Calendar UI delete controls accepted task id `142` and enabled the delete button.
- To avoid performing a local destructive GUI delete action through Computer Use without action-time user confirmation, the same bound backend route was verified directly with `DELETE /api/study-plan-adjustment/tasks/142`.
- Delete response: `source=manual_delete`, `project_id=7`, `task_id=142`, `scheduled_date=2026-05-29`, `project_completed=false`.
- DB and Calendar API then showed task `142` absent and `2026-05-29` returned to `0` tasks, `0` minutes, `over_capacity=false`.

### Rest-Day Behavior

- Baseline settings: `weekly_weekdays=[5]`, `one_off_dates=[]`.
- Added one-off rest day `2026-08-03` with `PUT /api/study-plan-adjustment/rest-days`.
- Runtime facts:
  - task `141`: `2026-08-03 -> 2026-08-04`
  - event `study_rest_day_cascaded` recorded `affected_task_ids: [141]`.
  - Calendar API showed `2026-08-03` as a rest day with zero tasks and `2026-08-04` with one over-capacity task.
- Rest settings were restored to `weekly_weekdays=[5]`, `one_off_dates=[]`.

### Dialogue Preview And Apply

- Adjust Plan UI instruction: `push this project by one day`.
- Project id field: `7`.
- Preview UI showed:
  - `project_shift`
  - `项目 ID 7`
  - `移动 1 天`
  - `影响任务：138, 139, 140, 141`
  - task date previews:
    - `138: 2026-05-24 -> 2026-05-25`
    - `139: 2026-05-27 -> 2026-05-28`
    - `140: 2026-05-28 -> 2026-05-29`
    - `141: 2026-08-04 -> 2026-08-05`
  - red facts for expected-late and new over-capacity days.
- DB query after preview confirmed no task dates changed.
- Apply UI then showed `结果 applied` with the same task ids and date changes.
- DB query after apply confirmed the same four task dates shifted exactly as previewed.
- Event `study_dialogue_adjustment_applied` recorded command `project_shift`, `project_id=7`, `delta_days=1`, and `affected_task_ids: [138, 139, 140, 141]`.

### Default Mode Silence

- Across Today, Calendar, Project Overview, and Adjust Plan verification, red states were displayed as facts only.
- No smart suggestion card, automatic repair proposal, or agent-like unsolicited adjustment flow appeared during default-mode manual changes.

## Result

Task 10.3: PASS with one documented safety constraint. The destructive delete click was not performed through Computer Use; the UI control enablement, Swift binding coverage, backend route, DB mutation, and calendar facts were verified through the same task id and route used by the app.
