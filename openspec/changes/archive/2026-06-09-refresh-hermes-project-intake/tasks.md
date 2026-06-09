# Tasks: refresh-hermes-project-intake

## 1. Hermes CLI

- [x] 1.1 Implement `cmd_create_project` + argparse
- [x] 1.2 Tests: create success, duplicate id, invalid deadline
- [x] 1.3 integration_smoke optional hook

## 2. Hermes skill

- [x] 2.1 SKILL §1: create-project → plan; single confirmation
- [x] 2.2 Split preview rules (plan intake exempt; move/set-deadline keep dry-run)
- [x] 2.3 Fix spec paths in SKILL + adjustment-logic.md
- [x] 2.4 Update `~/.hermes/openspec/build-hermes-learning-assistant-v1` plan-generation pointer if needed

## 3. MalDaze copy

- [x] 3.1 `LearningProjectStatusView` empty state
- [x] 3.2 `LearningInsertTaskSheet` empty projects message

## 4. Docs & QA

- [x] 4.1 `docs/integrations/hermes.md`, `learning-desk-panel.md`, MANUAL_QA M-L11
- [x] 4.2 `openspec validate refresh-hermes-project-intake --strict`
- [x] 4.3 User MANUAL_QA M-L11 (对话建项目端到端)
