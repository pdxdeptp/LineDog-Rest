## Why

The new "模型与密钥" settings page mixes unrelated controls into the LLM/API-key surface: the Smart Input shortcut row appears at the bottom of the credentials page, and the learning-assistant lazy backend toggle is embedded inside the API/model card. This breaks the settings window's navigation promise and makes controls appear in places users do not expect.

## What Changes

- Keep "模型与密钥" focused only on LLM provider, model, selected-provider API key, saved/empty state, show/hide behavior, and local-only copy for Learning Assistant and Smart Input.
- Change the LLM provider selector from a segmented control to a dropdown/popup menu using the same compact control pattern as the model selector.
- Move all shortcut recorder rows, including Smart Input "添加提醒", into the "快捷键" category.
- Move the learning-assistant lazy backend startup toggle out of the LLM/API-key card and into a dedicated "学习助手" settings category focused on startup/runtime behavior.
- Preserve existing storage keys and behavior for provider/model/API key, shortcut recording, and lazy backend startup.
- Tighten the settings layout so controls do not visually overlap, bleed across category boundaries, or appear partially attached to the wrong section when the content scrolls.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `desk-pet-controls`: Settings category boundaries must keep LLM credentials, shortcut recorders, and learning-assistant startup/runtime controls in their correct surfaces with no cross-category leakage or overlap, and LLM provider selection must use a compact dropdown control aligned with the model selector.

## Impact

- Affected SwiftUI settings code:
  - `MalDaze/Settings/MalDazeSettingsView.swift`
- Affected defaults/bindings only if existing settings bindings need to be passed to a different category; no persistence key migration is intended.
- Affected tests:
  - Settings presentation/source assertions that "模型与密钥" excludes shortcut recorders and lazy backend startup controls.
  - Settings presentation/source assertions that provider selection renders as dropdown/popup controls rather than segmented controls.
  - Settings presentation/source assertions that a "学习助手" category owns the lazy backend startup toggle and explains its startup/runtime trade-off.
  - Settings presentation/source assertions that "快捷键" includes Smart Input "添加提醒" alongside the other global shortcut recorders.
  - Layout assertions or manual QA covering category switching, scrolling, and compact window sizing.
- No new external dependencies.
