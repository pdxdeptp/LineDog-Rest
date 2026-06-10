## 1. Hermes skill — Menu Turn rubric (Direction A)

- [x] 1.1 Add Menu Turn semantic YES/NO rubric to `nutrition-menu/SKILL.md` (explicitly not keyword-router authority)
- [x] 1.2 Add Menu Turn ordering checklist: facts → plan → author → publish → status before user-facing sync claim
- [x] 1.3 Add rule: do not send final menu text until `nutrition_authoring_publish.py status` is `ok: true` (or unavailable written)
- [x] 1.4 Replace nutrition Feishu-owned wording with Hermes agent / ingress-agnostic language; keep Feishu only as ingress example where needed

## 2. Hermes publish defaults and docs

- [x] 2.1 Change `nutrition_authoring_publish.py` default and stdin fallback `source.kind` to `hermes_nutrition`
- [x] 2.2 Update `data/nutrition/README.md` publish examples and Menu Turn pointer
- [x] 2.3 Update skill publish stdin JSON example to `hermes_nutrition`

## 3. Tests and QA rename

- [x] 3.1 Rename `test_integration_feishu_nutrition_qa.py` → `test_integration_hermes_nutrition_qa.py` and class/fixture names
- [x] 3.2 Update `test_nutrition_authoring_publish.py` fixtures to `hermes_nutrition`
- [x] 3.3 Add/extend QA asserting skill text contains Menu Turn semantic gate + publish/status checklist
- [x] 3.4 Add Menu Turn simulation test: log → plan → publish → status fresh on isolated `NUTRITION_DATA_DIR`

## 4. MalDaze integration docs

- [x] 4.1 Update `docs/integrations/hermes.md` nutrition paragraph: Menu Turn, `hermes_nutrition`, no gateway auto-publish
- [x] 4.2 Update `docs/integrations/features/nutrition-today-panel.md` stale/sync explanation to reference Menu Turn completion gate

## 5. Verification

- [x] 5.1 Run Hermes nutrition unit/integration tests
- [x] 5.2 Run `openspec validate enforce-nutrition-menu-turn-publish --strict`
- [x] 5.3 Manual QA: Hermes agent Menu Turn (indirect phrasing) → `status ok:true` → MalDaze panel fresh within ~1s FSEvents debounce
