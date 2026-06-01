# Progress

## 2026-05-31

- Implemented Add / Initiate UI language polish in the desktop assistant panel:
  localized source, role, reason, confidence, and target-depth display; clearer entry outcome copy; editable title review; deadline guidance and validation; target-depth choices; and editable assumptions review.
- Kept backend-facing request values machine-stable by normalizing legacy depth aliases such as `apply`, `understand`, and `skim` into explicit tokens before requests.
- Added focused Swift coverage for the language polish, title handoff behavior, deadline validation, target-depth mapping, fallback labels, and draft summary localization.
- Review status: spec compliance and code-quality reviews passed after fixes. Remaining non-blocking follow-up: source labels such as `URL` and `GitHub repo` could be further localized if desired.
- Verification passed:
  - `xcodebuild test -project MalDaze.xcodeproj -scheme MalDaze -parallel-testing-enabled NO -only-testing:MalDazeTests/LearningAssistantUISourceTests -only-testing:MalDazeTests/LearningAssistantViewModelTests -quiet`
  - `openspec validate polish-add-initiate-language-input --strict`
  - `git diff --check -- MalDaze/LearningAssistant/LearningAssistantViewModel.swift MalDaze/LearningAssistant/AssistantPanelView.swift MalDazeTests/LearningAssistantTests.swift`
- Pending: manual desktop QA for entry, role review, title review, deadline validation, depth selection, and assumptions review.
