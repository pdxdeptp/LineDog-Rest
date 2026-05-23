# App Verification Evidence: ITEM-001 Study Plan Foundation

## Scope

- OpenSpec change: `introduce-study-plan-foundation`
- Task: 5.4
- App path verified: `/Users/cpt/Public/MalDaze/DerivedData/Build/Products/Debug/MalDaze.app`
- Backend observed: local FastAPI server on `127.0.0.1:8765`, launched by the current checkout app process.
- Verification method: Computer Use accessibility tree plus local API/SQLite checks. `screencapture` could not create images from the desktop rect/display in this environment, so this run records textual App Use evidence instead of screenshots.

## Build And Launch

- Built the current checkout app with:
  - `xcodebuild -project MalDaze.xcodeproj -scheme MalDaze -configuration Debug -derivedDataPath /Users/cpt/Public/MalDaze/DerivedData build`
  - Result: `** BUILD SUCCEEDED **`
- A stale bundle instance from `/Users/cpt/Library/Developer/Xcode/DerivedData/.../MalDaze.app` was present, so Computer Use was explicitly targeted at the current checkout path.

## UI Flow Observed

- Opened the desk pet and dashboard from the current checkout app.
- The `添加资料` tab displayed the v2 study-plan intake surface:
  - `学习资料 URL`
  - required deadline field with visible default `2026/6/23`
  - daily capacity stepper defaulting to `15 分钟`
  - `生成学习计划` button enabled after URL input.
- Entered `https://example.com/course-v2` and generated a study plan.
- Guided clarification appeared before draft generation with three questions:
  - familiarity
  - learning goal/depth
  - focus/skip scope
- During this app verification, the first run exposed a real UI bug: radio options that shared the same answer value appeared selected at the same time. A TDD fix changed the UI selection key to `option.id` while preserving submitted answer values.
- Rebuilt and relaunched the current checkout app, then verified the fixed radio behavior:
  - selecting `Some familiarity` left only that option selected for the first question,
  - the other familiarity options were unselected,
  - default selections remained single-selected for the other questions.
- Submitted the clarified answers and reached the review draft state:
  - title: `Course V2`
  - status: `review`
  - deadline: `2026-06-23`
  - daily capacity: `15 分钟`
  - source URL: `https://example.com/course-v2`
  - draft tasks:
    - `Review Course V2 overview`, scheduled `2026-05-24`, target `45 分钟`
    - `Practice Course V2 application`, scheduled `2026-06-08`, target `45 分钟`
  - over-capacity markers were visible for scheduled days exceeding the 15-minute daily cap.
- Verified duration edit:
  - incremented the first draft task from `45 分钟` to `50 分钟`,
  - clicked `更新时长`,
  - reopened the dashboard and observed the review draft persisted the first task at `目标 50 分钟`, with updated over-capacity text.
- Verified cancel:
  - clicked `取消`,
  - review draft disappeared and the intake form returned without active task creation for that draft.
- Verified confirm:
  - generated a rough plan through `生成粗略计划`,
  - observed the low-calibration warning in review state,
  - clicked `确认创建计划`,
  - review state cleared and the intake form returned.

## Backend Evidence

- `GET /api/resources` after confirmation included:
  - resource `id=6`
  - `title="Course V2"`
  - `type="study_project"`
  - `url="https://example.com/course-v2"`
  - `status="active"`
  - `total_units=2`
  - `deadline="2026-06-23"`
- SQLite confirmed the latest draft transitions:
  - draft `id=2`: `status=cancelled`, URL `https://example.com/course-v2`
  - draft `id=3`: `status=confirmed`, URL `https://example.com/course-v2`
- SQLite confirmed the active tasks for resource `id=6`:
  - task `136`: `Review Course V2 overview`, `target_minutes=45`, scheduled `2026-05-24`
  - task `137`: `Practice Course V2 application`, `target_minutes=45`, scheduled `2026-06-08`

## Result

- PASS: URL intake, guided clarification, draft review, duration edit, cancel, and confirm behavior were verified on the current checkout app path.
- PASS: The app-discovered radio-selection regression was fixed through TDD and reverified in the app.
- PASS: `openspec instructions apply --change introduce-study-plan-foundation --json` reports `20/20` tasks complete and `state=all_done`.
- PASS: backend study-plan tests report `27 passed, 2 warnings`.
- PASS: Swift targeted tests report `** TEST SUCCEEDED **`.
- Residual note: confirmation intentionally created a local test resource/task pair in `assistant_backend/learning.db` as part of end-to-end verification.
