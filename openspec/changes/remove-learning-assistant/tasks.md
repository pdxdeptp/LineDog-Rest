## 1. Guard Rails

- [x] 1.1 Add or update retained-app tests that fail while `AssistantPanelView`, `LearningAssistantViewModel`, `BackendProcessManager`, `assistant_backend`, or Learning Assistant settings references remain wired into the Swift app.
- [x] 1.2 Add or update dashboard/settings source tests that assert the retained dashboard has no Learning Assistant column/category and still exposes reminders, desktop pet controls, Smart Reminder settings, and shortcuts.

## 2. Swift App Removal

- [x] 2.1 Delete `MalDaze/LearningAssistant/` Swift sources and remove all references from the Xcode project.
- [x] 2.2 Simplify `DashboardRootView` and `DeskPetDashboardView` to a retained non-learning layout and update preferred sizing.
- [x] 2.3 Remove Learning Assistant backend startup, lazy-startup defaults, provider/model/API-key defaults, notifications, and settings UI while preserving Smart Reminder configuration.
- [x] 2.4 Update `WindowManager`, `AppViewModel`, and retained dashboard controls so no active Swift code references Learning Assistant types, tabs, backend APIs, or backend process management.

## 3. Backend, Docs, And Specs Cleanup

- [x] 3.1 Delete tracked `assistant_backend/` code, tests, launch-agent scripts, dependency files, and local learning database artifacts.
- [x] 3.2 Delete or rewrite Learning Assistant-only tests, docs, acceptance reports, and planning notes; keep unrelated docs intact.
- [x] 3.3 Delete retired Learning Assistant OpenSpec specs and active changes/evidence while preserving unrelated active work such as `add-t7-eject-helper`.
- [x] 3.4 Update README/PRD references so the app description no longer advertises Learning Assistant behavior.

## 4. Verification

- [x] 4.1 Run focused searches proving no active Swift app code references Learning Assistant symbols, `assistant_backend`, or retired `/api/study`, `/api/ingest`, `/api/chat`, `/api/resources`, `/api/today-briefing`, morning, or review APIs.
- [x] 4.2 Run retained Xcode tests or focused source tests for dashboard/settings/reminders/Smart Reminder behavior.
- [x] 4.3 Build the app with `xcodebuild -scheme MalDaze -configuration Debug -destination 'platform=macOS' -derivedDataPath ./DerivedData build`.
- [x] 4.4 Launch the built app and confirm the process starts from `DerivedData/Build/Products/Debug/MalDaze.app`.
