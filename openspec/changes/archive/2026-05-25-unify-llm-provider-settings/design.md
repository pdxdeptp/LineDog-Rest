## Context

`MalDazeSettingsView` now has a polished split settings shell, but the LLM settings model is still uneven:

- Learning assistant has provider, model, and selected-provider API key state for Gemini, OpenAI, and DeepSeek.
- Smart Input still has Gemini-only `geminiAPIKey` and `geminiModelId` storage, plus a Gemini-specific API client and orchestrator dependency.
- The UI repeats the same conceptual controls in different shapes, which made the latest polish pass feel inconsistent as soon as both features needed provider choice.

The user-facing mental model should be: "MalDaze has two LLM-powered features. Each feature can independently choose a provider, model, and local key, but both use the same settings component."

```
Settings
└── API Key / LLM
    ├── Learning Assistant
    │   ├── Provider: Gemini | OpenAI | DeepSeek
    │   ├── Model
    │   └── Selected-provider API Key
    └── Smart Input
        ├── Provider: Gemini | OpenAI | DeepSeek
        ├── Model
        └── Selected-provider API Key
```

## Goals / Non-Goals

**Goals:**

- Give Smart Input the same provider choices as the learning assistant.
- Replace duplicated LLM controls with a reusable settings module that can render either feature's provider/model/API-key controls.
- Preserve independent settings per feature; Smart Input changes must not mutate learning-assistant provider/model/key values.
- Preserve existing Gemini Smart Input defaults so current users do not lose behavior after upgrade.
- Update Smart Input runtime dispatch so the selected provider and model are used for reminder parsing.
- Keep the settings page visually calm, native, and aligned with the panel's pale-blue accent.

**Non-Goals:**

- No Keychain migration in this change; API keys remain local `UserDefaults` values with truthful copy.
- No network "test key" button.
- No backend learning-assistant API redesign; learning assistant keeps its current backend provider behavior.
- No new third-party dependency.
- No shared global API key unless the user explicitly asks later. Each feature owns separate credentials.

## Decisions

### 1. Introduce a reusable LLM settings module

Add a reusable SwiftUI module such as `LLMProviderSettingsSection` or `LLMProviderSettingsCard` that accepts:

- feature title and subtitle;
- feature context copy;
- provider binding;
- model binding;
- provider-specific key bindings;
- provider/model catalog;
- optional extra rows, such as learning assistant lazy startup or Smart Input shortcut.

The module should own the visual pattern: feature header, provider segmented control, model picker, selected-provider API key row, local-only copy, saved/empty state, and show/hide state.

Alternative considered: keep separate `learningAssistantSettingsPane` and `smartInputSettingsPane` layouts and only align their strings. That would fix today's screenshot but leave duplicated logic and make the next provider/model change fragile.

### 2. Use a shared provider/model catalog shape

Create a provider model abstraction with a small common type, for example:

```
LLMProviderID: gemini | openai | deepseek
LLMProviderCatalog.models(for:)
LLMProviderCatalog.defaultModel(for:)
LLMProviderCatalog.displayName/icon/help
```

The existing `BackendLLMCatalog` can either be renamed/generalized or wrapped by a new catalog. Smart Input should use the same provider list, while still allowing different default model values if needed.

Alternative considered: reusing `BackendLLMCatalog` directly from Smart Input. That is acceptable only if the naming is generalized; otherwise Smart Input runtime would depend on a "backend" concept that does not describe it.

### 3. Keep separate persistence namespaces

Learning assistant keeps existing backend keys:

- `MalDaze.backend.llmProvider`
- `MalDaze.backend.llmModel`
- `MalDaze.backend.geminiAPIKey`
- `MalDaze.backend.openAIAPIKey`
- `MalDaze.backend.deepSeekAPIKey`

Smart Input should gain parallel keys, for example:

- `MalDaze.smartInput.llmProvider`
- `MalDaze.smartInput.llmModel`
- `MalDaze.smartInput.geminiAPIKey`
- `MalDaze.smartInput.openAIAPIKey`
- `MalDaze.smartInput.deepSeekAPIKey`

The existing `MalDaze.geminiAPIKey` and `MalDaze.geminiModelId` values should be read as migration/default fallback for Smart Input Gemini so existing users do not have to re-enter their Gemini key.

Alternative considered: one app-wide provider/key shared by both features. That reduces settings surface, but it removes useful separation: a user may want the learning assistant on a stronger/expensive model while Smart Input uses a fast/cheap model.

### 4. Rename the settings category to API Key / LLM

Instead of keeping separate "学习助手" and "智能输入" categories for provider controls, introduce a dedicated category such as "API Key" or "模型与密钥". The detail pane contains two feature cards:

1. "学习助手" card: provider, model, API key, lazy startup.
2. "智能输入" card: provider, model, API key, shortcut.

The shortcuts-only category can remain for global shortcuts if the Smart Input shortcut should stay grouped with other shortcuts; however the Smart Input card should at minimum show the provider/model/key controls. My recommendation is:

- "模型与密钥": two LLM feature cards.
- "快捷键": all shortcut recorders, including Smart Input reminder shortcut.

This keeps credentials in one place and avoids mixing API keys with keyboard controls.

Alternative considered: keep "学习助手" and "智能输入" as separate categories that both use the shared component. That is simpler to implement but makes users compare two screens to understand provider parity.

### 5. Generalize Smart Input LLM runtime dispatch

Replace the Gemini-specific orchestrator dependency with a provider-agnostic protocol, for example:

```
protocol ReminderLLMGenerating {
    func generateStructuredReminderJSON(
        provider: LLMProviderID,
        model: String,
        systemPrompt: String,
        userText: String,
        apiKey: String,
        timeoutSeconds: TimeInterval
    ) async throws -> String
}
```

Provider-specific clients can be separate private helpers under one facade. The orchestrator should resolve Smart Input provider/model/key at request time so settings changes apply immediately.

Alternative considered: keep `GeminiRemindersGenerating` and branch inside it. That would preserve old names while hiding non-Gemini behavior behind a misleading type.

### 6. UI style

Follow the current settings visual system:

- pale-blue accent for selected states and saved status;
- native `Picker`, `TextField` / `SecureField`, `Button`, `Toggle`;
- visible labels, not placeholder-only labels;
- icon-only show/hide buttons with accessibility labels;
- compact cards with clear boundaries, not nested decorative cards;
- no network validation affordance until behavior exists.

## Risks / Trade-offs

- Existing Smart Input Gemini users may lose their configured key if migration is missed -> Read old keys as fallback and write to new keys when the settings view or runtime resolves them.
- OpenAI/DeepSeek response formats may differ from Gemini -> The provider facade must normalize provider responses into the existing raw JSON text contract before `LLMReminderJSONDecoderService` runs.
- Model catalog naming can drift -> Keep one provider catalog used by both settings modules and runtime lookup tests.
- Settings may become dense -> Move credentials into one "模型与密钥" category with two scan-friendly feature cards, and keep shortcuts in the shortcut category.
- Tests may become brittle if they assert only strings -> Add both source-structure tests for shared module reuse and behavior tests for provider dispatch/default fallback.

## Migration Plan

1. Add failing tests for Smart Input provider keys, provider/model selection, shared settings module reuse, and provider-aware runtime dispatch.
2. Add Smart Input provider/model/key defaults and migration fallback from existing Gemini-only keys.
3. Generalize provider/model catalog and settings bindings.
4. Refactor settings UI to render two instances of the shared LLM module in a dedicated "模型与密钥" category.
5. Replace Gemini-specific Smart Input runtime dispatch with a provider-agnostic facade while preserving the existing JSON decoding contract.
6. Run focused settings and Smart Reminder tests, then broader app tests.
7. Manually verify settings navigation, provider switching, key show/hide, saved/empty states, and Smart Input with each configured provider path where credentials are available.

Rollback: revert the new Smart Input provider keys and runtime facade; existing Gemini-only `MalDaze.geminiAPIKey` and `MalDaze.geminiModelId` values remain untouched.

## Open Questions

- Should the left sidebar label be "API Key", "模型与密钥", or "AI 设置"? My recommendation is "模型与密钥" because the section contains provider, model, and key, not only secrets.
- Should Smart Input default to Gemini even if the learning assistant is currently OpenAI/DeepSeek? My recommendation is yes: keep independent defaults and avoid surprising behavior.
- Should the old Gemini-only Smart Input keys be written forward into new Smart Input Gemini keys automatically, or only read as fallback? My recommendation is read as fallback in runtime plus write forward when settings opens, so UI state becomes explicit without forcing a one-time migration task elsewhere.
