## Context

`MalDazeSettingsView` currently uses one grouped SwiftUI `Form` with sequential `Section`s for learning-assistant LLM provider settings, Smart Input Gemini settings, and four shortcut recorders. The independent settings window is a small `480 x 440` floating `NSWindow` that hosts the same view.

This is functionally compact, but it creates three UX problems:

- API key entry looks like raw plumbing: a `SecureField` with a placeholder, no stable visible label, no show/hide affordance, no saved/empty state, and no provider context.
- unrelated settings have equal weight, so backend model selection, Smart Input parsing, lazy startup, and shortcut recording feel like one long undifferentiated form.
- shortcut rows are repetitive, narrow, and visually primitive even though they are important safety controls.

The design uses `ui-ux-pro-max` guidance as the baseline: visible labels, keyboard/focus accessibility, progressive disclosure, clear active state, icon-only controls with accessible names, 44 pt-ish interaction comfort, and native controls rather than custom painted widgets.

## Goals / Non-Goals

**Goals:**

- Make the settings window feel like a polished macOS utility surface with clear category navigation and calm density.
- Make API key input trustworthy and legible: visible label, provider status, show/hide action, local-only storage reassurance, and empty/saved state.
- Preserve all existing settings: backend provider/model/key, backend lazy startup, Smart Input Gemini key/model, and all global shortcuts.
- Preserve current `@AppStorage` keys and shortcut capture behavior.
- Keep the settings window useful when opened from the Dashboard right-column gear or the menu bar settings action.
- Improve accessibility labels, focus order, and control target comfort.

**Non-Goals:**

- No changes to LLM provider catalogs or model IDs.
- No migration from `UserDefaults` to Keychain in this change.
- No backend startup behavior changes.
- No redesign of the Dashboard right controls column itself beyond preserving the settings entry point.
- No new dependency or external design system package.

## Decisions

### 1. Use a split settings shell instead of a single form

The new `MalDazeSettingsView` should render as a two-column settings surface:

1. a left navigation rail with categories such as "学习助手", "智能输入", and "快捷键";
2. a right content pane showing the selected category with grouped setting rows.

This follows familiar macOS settings structure and reduces the feeling of an endless form. It also lets the API key experience occupy enough horizontal space without increasing cognitive load.

Alternative considered: keep the existing `Form` and restyle each `Section`. That would improve surface polish but would not solve the hierarchy problem because every setting would still compete in one vertical stack.

### 2. Use local reusable row components

Implementation should keep helpers local to `MalDaze/Settings/`:

- `SettingsCategory`
- `SettingsSidebarButton`
- `SettingsPane`
- `SettingsGroup`
- `APIKeySettingRow`
- `ShortcutSettingRow`

These components are view-level only and should not introduce new persistence or business-logic abstractions.

Alternative considered: extract a project-wide settings design system. The current need is narrow, and a broad abstraction would create churn before the app has multiple settings windows.

### 3. Redesign API key input as a provider-aware row

API key rows should include:

- stable visible label, not placeholder-only;
- provider icon via SF Symbols, text label, and model/provider context;
- secure input by default;
- show/hide toggle with accessibility label;
- empty/saved state text such as "未填写" or "已保存在本机";
- short local-only helper copy;
- no network validation or save button because current persistence is immediate through `@AppStorage`.

For backend LLM settings, only the selected provider's key row should be emphasized; other provider keys can remain hidden to match current behavior. For Smart Input, Gemini stays explicit and separate so users understand it powers natural-language reminder parsing rather than the learning assistant backend.

Alternative considered: add a "Test key" action. That would require network validation behavior and failure states beyond this visual redesign.

### 4. Keep native macOS controls but style the surrounding structure

The implementation should keep `Picker`, `Toggle`, `TextField` / `SecureField`, and `Button` for platform accessibility. Visual polish should come from layout, background surfaces, row spacing, keycap text treatment, and clear labels rather than bespoke controls.

Alternative considered: fully custom controls. This would risk keyboard and VoiceOver regressions for little benefit.

### 5. Improve shortcut recorder state without changing capture semantics

Each shortcut row should show:

- a title and short explanation;
- a monospaced keycap display;
- a primary "录制" / "等待按键..." action;
- a secondary restore-default action;
- disabled state when another recorder is active;
- the existing hidden `GlobalShortcutKeyRecorder`.

Esc cancellation, modifier requirements, and default shortcut values remain unchanged.

Alternative considered: combine all shortcuts into one compact table. A table would be dense, but shortcut descriptions differ enough that row cards are clearer.

### 6. Resize the independent window around the new layout

The presenter should increase the content size from the current small form window to a wider settings layout, for example around `720 x 520` content points, while still centering with `MalDazePresentationAnchor`.

Alternative considered: keep `480 x 440`. That would force the split layout into cramped proportions and reintroduce scrolling as the primary experience.

## Risks / Trade-offs

- Larger settings window could feel heavy → Keep it centered, fixed, and visually calm with native materials and concise copy.
- Show/hide key controls could expose secrets on shared screens → Default to hidden, provide explicit per-row toggle only, and do not persist visibility state.
- String-based tests may be brittle for visual components → Use focused source assertions for structure and key persistence, plus normal build/test verification.
- Immediate `@AppStorage` persistence lacks explicit "saved" feedback → Communicate "本机即时保存" clearly and avoid fake save buttons.

## Migration Plan

1. Add failing tests/source assertions for settings structure, API key row affordances, shortcut row presentation, and preserved storage keys.
2. Implement the redesigned settings shell and helper views.
3. Update `MalDazeSettingsWindowPresenter` content size for the new layout.
4. Run relevant XCTest targets and compile checks.
5. Manually open settings from the Dashboard gear and menu bar settings action to verify layout, focus, shortcut recording, Esc behavior, and API key show/hide.

Rollback is simple: revert the settings view and presenter sizing while leaving persistence values untouched.

## Open Questions

- Should API keys eventually move from `UserDefaults` to Keychain? This change intentionally does not do that, but the redesigned UI should avoid implying stronger storage than the app currently provides.
