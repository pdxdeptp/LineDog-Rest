## 1. Tests And Source Assertions

- [x] 1.1 Add failing settings assertions that the LLM/API-key category renders two instances of one reusable provider settings module.
- [x] 1.2 Add failing settings assertions that Smart Input exposes Gemini, OpenAI, and DeepSeek provider choices with provider-specific model defaults.
- [x] 1.3 Add failing persistence assertions for independent learning-assistant and Smart Input provider/model/key storage.
- [x] 1.4 Add failing Smart Reminder runtime tests for provider-aware dispatch, selected-provider missing-key messages, and existing Gemini fallback.

## 2. Provider Configuration Model

- [x] 2.1 Add or generalize a provider ID and model catalog shared by learning assistant and Smart Input settings.
- [x] 2.2 Add Smart Input provider, model, Gemini key, OpenAI key, and DeepSeek key defaults while preserving existing Gemini-only fallback keys.
- [x] 2.3 Add helper bindings/resolvers that return the selected provider API key for each feature without cross-writing the other feature.
- [x] 2.4 Ensure switching either feature's provider resets only that feature's model to the selected provider default.

## 3. Settings UI Redesign

- [x] 3.1 Replace duplicated learning-assistant and Smart Input provider controls with a reusable LLM provider settings module.
- [x] 3.2 Add a dedicated "模型与密钥" or equivalent settings category containing learning-assistant and Smart Input LLM cards.
- [x] 3.3 Render each LLM card with consistent provider picker, model picker, API key row, saved/empty state, show/hide control, local-only copy, and pale-blue accent.
- [x] 3.4 Keep feature-specific controls reachable without clutter: learning assistant lazy startup and Smart Input shortcut behavior must remain available.
- [x] 3.5 Preserve the settings window presenter, Esc handling, shortcut recorders, and existing category navigation behavior.

## 4. Smart Input Runtime

- [x] 4.1 Introduce a provider-agnostic reminder LLM generation protocol/facade.
- [x] 4.2 Implement Gemini, OpenAI, and DeepSeek request paths that normalize responses into the existing reminder JSON text contract.
- [x] 4.3 Update `SmartReminderOrchestrator` to resolve Smart Input provider/model/key at request time and dispatch through the provider facade.
- [x] 4.4 Update user-facing error copy so missing-key messages name the selected Smart Input provider.
- [x] 4.5 Preserve existing Smart Input prompt construction, JSON decoding, reminder mutation, draft lifecycle, and toast behavior.

## 5. Verification

- [ ] 5.1 Run focused settings/source tests covering the shared LLM settings module.
- [ ] 5.2 Run focused Smart Reminder tests covering provider dispatch and Gemini fallback.
- [ ] 5.3 Run `openspec validate unify-llm-provider-settings --strict`.
- [ ] 5.4 Run a broader app test/build check after focused tests pass.
- [ ] 5.5 Manually verify the settings window: provider switching for both feature cards, key show/hide, saved/empty states, local-only copy wrapping, and Smart Input shortcut accessibility.
