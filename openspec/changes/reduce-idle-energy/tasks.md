## 1. Red Tests

- [x] 1.1 Add AutoTimerEngine tests proving waiting uses an anchor one-shot schedule and rest emits only whole-second countdown changes.
- [x] 1.2 Add backend lifecycle tests proving app launch does not eagerly start the assistant backend and assistant UI activation starts it idempotently.
- [x] 1.3 Add PetRenderer tests proving static and intermediate GIF paths reuse decoded frames for the same URL.
- [x] 1.4 Add focused tests or source assertions proving idle cursor tracking is adaptive, break-run targets about 30 Hz with elapsed-time movement, and fullscreen rest stops high-frequency visual updates after approach completion.
- [x] 1.5 Add settings/backend lifecycle tests proving the persisted lazy-backend option is exposed in Settings, defaults to energy-saving lazy startup, and allows eager startup at app launch when disabled.

## 2. Green Implementation

- [x] 2.1 Implement one-shot anchor scheduling and 1 Hz rest countdown updates in AutoTimerEngine.
- [x] 2.2 Implement lazy, idempotent assistant backend startup from LearningAssistantViewModel and stop eager startup from the app delegate.
- [x] 2.3 Implement PetRenderer decoded GIF frame caching for static and intermediate animation paths.
- [x] 2.4 Implement adaptive idle cursor tracking in WindowManager while preserving pass-through behavior.
- [x] 2.5 Implement 30 Hz, elapsed-time break-run movement.
- [x] 2.6 Implement lower-wakeup fullscreen rest ticking after the approach animation completes.
- [x] 2.7 Implement the persisted assistant backend lazy-start setting in defaults, Settings UI, and app launch lifecycle.

## 3. Verification

- [x] 3.1 Validate the OpenSpec change artifacts.
- [x] 3.2 Run the relevant xcodebuild test suite and resolve regressions.
- [x] 3.3 Build and briefly sample the app idle state to confirm no temporary processes remain and idle wakeups are reduced.
- [x] 3.4 Re-run OpenSpec validation and relevant/full test suites after adding the backend startup setting.
