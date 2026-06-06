## Why

The redesigned settings window now makes API keys look trustworthy, but retired middle-column feature and Smart Input still model provider choice differently. Smart Input remains Gemini-only while the retired middle-column feature already supports Gemini, OpenAI, and DeepSeek, which makes the UI feel inconsistent and blocks users who want one provider strategy across both features.

## What Changes

- Add provider selection for Smart Input with the same supported providers as the retired middle-column feature: Google Gemini, OpenAI, and DeepSeek.
- Replace duplicated provider/model/API-key UI with a reusable LLM provider settings module that can be configured for either retired middle-column feature or Smart Input.
- Give settings a dedicated API Key / LLM configuration surface where each feature appears as a clear "usage card" using the same provider picker, model picker, selected-provider key row, saved/empty state, show/hide behavior, and local-only copy.
- Preserve separate persistence for retired middle-column feature and Smart Input so changing one feature's provider, model, or key does not silently affect the other.
- Update Smart Input runtime behavior so reminder parsing uses the selected Smart Input provider and model rather than always calling the Gemini client.
- Preserve the existing Smart Input shortcut and reminder creation flow.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `desk-pet-controls`: Settings must expose shared, provider-agnostic LLM/API-key configuration for retired middle-column feature and Smart Input, and Smart Input must support Gemini, OpenAI, and DeepSeek with independent provider/model/key state.

## Impact

- Affected SwiftUI/AppKit code:
  - `MalDaze/Settings/MalDazeSettingsView.swift`
  - Potentially new local settings helper types under `MalDaze/Settings/`
- Affected Smart Input LLM code:
  - `MalDaze/SmartReminder/GeminiRemindersAPIClient.swift` or a replacement provider-agnostic client abstraction
  - `MalDaze/SmartReminder/SmartReminderOrchestrator.swift`
  - `MalDaze/SmartReminder/MalDazeGeminiModelCatalog.swift` or a shared provider model catalog
  - `MalDaze/MalDazeDefaults.swift`
- Affected tests:
  - Settings source/presentation assertions for shared module reuse and independent Smart Input provider state.
  - Smart Reminder orchestrator/client tests for provider dispatch, missing-key messages, and model lookup.
- No new external dependencies.
- UserDefaults remains the storage mechanism for this change; existing Gemini Smart Input settings should continue to work as the default/migration path.
