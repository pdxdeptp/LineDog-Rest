## Context

The current settings window uses a left sidebar with "模型与密钥" and "快捷键" categories. After the LLM provider unification work, the rendered layout has two visible category-boundary regressions:

- The Smart Input "添加提醒" shortcut recorder row appears at the bottom of the "模型与密钥" page instead of in "快捷键".
- The learning-assistant lazy backend startup toggle appears inside the LLM/API-key configuration surface, even though it controls startup/runtime behavior rather than provider, model, or credentials.

These controls still work, but their placement violates the user's mental model. A category should be a contract: when the sidebar says "模型与密钥", the detail pane should contain model/provider/key controls only; when it says "快捷键", all shortcut recorders should be there together.

There is also a smaller control-shape issue inside the LLM cards: provider selection currently uses a segmented control while model selection uses a dropdown. With three providers and potentially localized labels, the segmented control adds horizontal pressure and contributes to the cramped, collision-prone feel. Provider should use the same compact dropdown/popup menu pattern as model.

## Goals / Non-Goals

**Goals:**

- Keep "模型与密钥" limited to the two LLM feature cards and their provider/model/API-key rows.
- Render both provider and model selection as dropdown/popup menu controls so the credentials card has one consistent compact selection pattern.
- Move Smart Input "添加提醒" to the "快捷键" category alongside the other global shortcut recorders.
- Move learning-assistant lazy backend startup out of the LLM/API-key card and into a dedicated "学习助手" category for startup/runtime behavior.
- Preserve all existing persistence keys, bindings, shortcut recording behavior, and lazy startup behavior.
- Ensure category switching, scrolling, and compact settings-window sizes do not make controls visually overlap or appear attached to the wrong section.

**Non-Goals:**

- No provider/runtime dispatch changes.
- No API-key storage migration.
- No new settings persistence keys unless a purely presentational section state requires one.
- No redesign of the entire settings window shell.
- No changes to the learning assistant backend process manager behavior.

## Decisions

### 1. Treat settings categories as exclusive surfaces

The implementation should avoid passing unrelated "extra rows" into a reusable LLM card if those rows are not credentials. The LLM card can remain reusable for provider/model/API-key controls, but category-level composition should decide where shortcut and runtime controls live.

Alternative considered: keep extra rows in the LLM cards and add stronger dividers. That would reduce code movement, but it would preserve the core information-architecture problem: users would still see a shortcut recorder and backend startup toggle under a credentials heading.

### 2. Put all shortcut recorders in the shortcut category

"快捷键" should contain every global shortcut recorder row, including:

- Desk menu / dashboard shortcut.
- Reset pet position shortcut.
- Countdown reminder shortcut.
- Smart Input "添加提醒" shortcut.

This keeps recording affordances, default shortcut copy, and restore actions in one predictable location.

Alternative considered: show Smart Input shortcut in both Smart Input and shortcut categories. That creates duplicate controls for the same setting and raises state-sync and layout risks without improving discoverability enough to justify the duplication.

### 3. Add a dedicated "学习助手" category for startup/runtime behavior

The lazy startup toggle belongs outside the LLM/API-key card. Add a third sidebar category:

- **Title:** "学习助手"
- **Subtitle:** "启动与运行"
- **Icon:** a learning/runtime-oriented SF Symbol such as `graduationcap`, `brain.head.profile`, or `bolt.horizontal.circle`; prefer a calm symbol that does not reuse the key/keyboard icons.
- **Order:** after "模型与密钥" and before "快捷键".

The category should contain a single settings group for now:

```
学习助手
└── 后端启动
    └── 启动策略
        ├── Toggle: 按需启动后端 / 开启懒启动
        └── Copy: 开启后，App 启动时不预热学习助手后端；首次打开学习助手时再启动，可能需要等待。
```

Recommended visible copy:

- Group title: "后端启动"
- Group subtitle: "控制学习助手本地后端何时启动。"
- Row title: "启动策略"
- Row subtitle: "在省电启动和首次打开速度之间取舍。"
- Toggle label: "按需启动后端"
- Help/caption: "开启后，App 启动时不会拉起后端，首次打开学习助手时再启动；关闭后，下次 App 启动完成后预先启动后端。切换此项不会立即启动或停止当前后端。"

This keeps the user's mental model clean:

- "模型与密钥" answers: Which LLM provider/model/key does each feature use?
- "学习助手" answers: How does the learning assistant runtime behave?
- "快捷键" answers: Which global keys trigger app actions?

Alternative considered: keep it in the Learning Assistant LLM card because it affects that feature. The user explicitly called this out as wrong, and the toggle does not configure the selected provider, model, or API key.

Alternative considered: create a broader "启动与性能" category. That would be reasonable if there were multiple app-wide startup/performance settings, but today this control is specifically about the learning-assistant backend. A feature-specific "学习助手" category is easier to scan and leaves room for future learning-assistant behavior settings without implying unrelated app performance controls.

### 4. Verify by rendered behavior, not only source shape

Tests should assert the category membership at the presentation/source level, and manual QA should open the actual settings window to verify:

- Provider selection is a dropdown/popup menu, visually aligned with the model dropdown, for both Learning Assistant and Smart Input.
- "模型与密钥" contains no "录制", "恢复默认", "添加提醒", or "开启懒启动" controls.
- "学习助手" contains the lazy backend startup toggle under startup/runtime copy, and that toggle does not appear in "模型与密钥".
- "快捷键" includes "添加提醒" and all existing shortcut rows.
- No row partially overlaps card boundaries at the default window size or after scrolling.

The sidebar/footer helper copy should also be category-aware. Do not leave global "API Key" helper text visible while "学习助手" or "快捷键" is selected. Either move the API-key helper into the "模型与密钥" detail pane, or make the sidebar helper copy reflect the selected category:

- "模型与密钥": API keys are saved locally and this page only improves entry/readability.
- "学习助手": startup changes take effect on next app launch and do not start/stop the current backend.
- "快捷键": shortcut recording stays local; Esc cancels recording.

### 5. Use dropdowns for provider and model selection

The provider control should be implemented with the same native compact menu style as the model selector. This reduces horizontal layout pressure, keeps provider and model visually parallel, and makes future provider label changes less likely to break the card width.

Alternative considered: keep segmented provider controls because only three providers exist today. That keeps one-click switching, but it consumes too much horizontal space in a dense credentials card and creates a different interaction pattern for two adjacent selection fields.

## Risks / Trade-offs

- Moving controls can make a previously visible control one click farther away -> Mitigate with clear sidebar labels and keeping every moved control in a semantically correct, scan-friendly section.
- Tests may become string-fragile across Chinese copy edits -> Mitigate by combining semantic/accessibility assertions with specific critical labels only where category membership matters.
- Adding a third category for one setting can feel sparse -> Mitigate by making the page intentionally focused ("后端启动") and using it as the future home for learning-assistant behavior settings, not provider credentials.
- The settings sidebar helper copy can become misleading outside the API page -> Mitigate with category-specific helper copy or by moving helper copy into each detail pane.
- Provider switching becomes one extra click compared with a segmented control -> Mitigate by placing provider and model controls consistently, with clear labels and current values visible.

## Migration Plan

1. Add failing settings tests that prove the current category leakage: Smart Input shortcut appears in "模型与密钥", "快捷键" lacks "添加提醒", and lazy startup appears inside the API/model surface.
2. Refactor settings composition so LLM cards contain only provider/model/API-key content.
3. Change provider selection to a dropdown/popup menu aligned with the model selector.
4. Add Smart Input shortcut row to the shortcut category.
5. Add a "学习助手" category with a "后端启动" group and move lazy startup there with startup/runtime copy.
6. Make sidebar/footer helper copy category-specific, or move helper copy into the relevant detail pane.
7. Re-run focused settings tests and manually verify the settings window at default and compact sizes.

Rollback: revert the layout composition changes. Because storage keys and runtime behavior are unchanged, rollback should not require data migration.

## Open Questions

- None for placement. The recommended destination is the new "学习助手" category with subtitle "启动与运行".
