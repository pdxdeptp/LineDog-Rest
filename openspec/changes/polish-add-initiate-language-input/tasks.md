## 1. Label And Mapping Tests

- [x] 1.1 Add tests for source-type labels that hide raw tokens from primary UI text.
- [x] 1.2 Add tests for role and reason display that use localized summaries.
- [x] 1.3 Add tests for target-depth label-to-token mapping.
- [x] 1.4 Add tests for title review before plan or scheduled-work handoff.

## 2. Input UI

- [x] 2.1 Update Add / Initiate entry copy to describe user outcomes.
- [x] 2.2 Replace source-type menu primary labels with localized labels.
- [x] 2.3 Add title review/edit field before role confirmation handoff.
- [x] 2.4 Add local deadline validation and guidance.
- [x] 2.5 Replace raw target-depth text entry with meaningful choices.
- [x] 2.6 Show assumptions in reviewable form before draft generation.

## 3. Contract Safety

- [x] 3.1 Keep raw API values stable while adding display mappings.
- [x] 3.2 Ensure existing role confirmation and anchor confirmation requests still send expected machine values.

## 4. Verification

- [x] 4.1 Run focused Swift tests for Add / Initiate language and input controls.
- [x] 4.2 Run `openspec validate polish-add-initiate-language-input --strict`.
- [ ] 4.3 Manually verify entry, role review, title review, deadline validation, depth selection, and assumptions review in the desktop app.
