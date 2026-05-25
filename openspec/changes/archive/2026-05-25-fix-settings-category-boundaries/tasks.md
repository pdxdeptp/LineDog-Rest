## 1. Tests And Assertions

- [x] 1.1 Add failing settings assertions that the "模型与密钥" category renders only Learning Assistant and Smart Input LLM provider/model/API-key controls.
- [x] 1.2 Add failing assertions that the "模型与密钥" category excludes shortcut recorder controls, including "添加提醒", "录制", and "恢复默认".
- [x] 1.3 Add failing assertions that the "模型与密钥" category excludes the learning-assistant lazy backend startup toggle.
- [x] 1.4 Add failing assertions that Learning Assistant and Smart Input provider selectors render as dropdown/popup controls instead of segmented controls.
- [x] 1.5 Add failing assertions that a "学习助手" category exists, uses startup/runtime copy, and contains the lazy backend startup toggle.
- [x] 1.6 Add failing assertions that category helper copy is not API-key-specific when "学习助手" or "快捷键" is selected.
- [x] 1.7 Add failing assertions that the "快捷键" category includes Smart Input "添加提醒" with record and restore-default behavior alongside the existing shortcut rows.

## 2. Settings Composition

- [x] 2.1 Refactor the shared LLM settings card so provider/model/API-key content is not mixed with unrelated shortcut or runtime rows.
- [x] 2.2 Replace the LLM provider segmented control with a dropdown/popup menu aligned with the existing model picker.
- [x] 2.3 Move the Smart Input "添加提醒" shortcut recorder row into the "快捷键" category while preserving its existing binding, default copy, record flow, and restore-default behavior.
- [x] 2.4 Add a "学习助手" settings category with subtitle "启动与运行" and a "后端启动" group for learning-assistant runtime behavior.
- [x] 2.5 Move the learning-assistant lazy backend startup toggle into the "学习助手" category while preserving its binding, help text semantics, and storage key.
- [x] 2.6 Make persistent settings helper copy category-aware, or move API-key helper copy into the "模型与密钥" detail pane.
- [x] 2.7 Preserve the existing provider/model/API-key storage keys, shortcut storage keys, lazy backend storage key, and all existing runtime semantics.

## 3. Layout And Visual QA

- [x] 3.1 Verify the default settings window size shows no overlapping controls, clipped rows, or cross-category content bleed.
- [x] 3.2 Verify scrolling within "模型与密钥" never reveals shortcut recorder rows or lazy backend controls.
- [x] 3.3 Verify provider and model selectors use matching compact dropdown styling and stay aligned in both LLM cards.
- [x] 3.4 Verify the "学习助手" category presents lazy startup as startup/runtime behavior, not credentials or shortcut configuration.
- [x] 3.5 Verify switching between "模型与密钥", "学习助手", and "快捷键" resets the user's mental context cleanly and keeps selected-category copy accurate.
- [x] 3.6 Verify compact window sizing keeps controls inside their owning cards/sections without overlap.

## 4. Verification

- [x] 4.1 Run focused settings tests covering the category boundary, provider dropdown, learning-assistant category, and category-helper-copy assertions.
- [x] 4.2 Run relevant broader app tests or build checks after focused tests pass.
- [x] 4.3 Run `openspec validate fix-settings-category-boundaries --strict`.
- [x] 4.4 Manually verify the settings window and capture the final observed placement of provider dropdowns, the "学习助手" lazy backend startup page, and "添加提醒" in shortcuts.
