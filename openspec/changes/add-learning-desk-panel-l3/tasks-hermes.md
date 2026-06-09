# Hermes · L3 CLI 增强

## 1. H-L3 pending auto_roll_days

- [x] 1.1 `build_pending_list` 增加 `auto_roll_days` 字段
- [x] 1.2 单测 / smoke：`today` pending 含滚入天数

## 2. H-L4 week-load

- [x] 2.1 新子命令 `week-load --from YYYY-MM-DD --days 28`
- [x] 2.2 输出：`days[]` with `date`, `total_minutes`, `budget`, `over_capacity`
- [ ] 2.3 单测：超 cap 日 `over_capacity: true`；休息日处理与 profile 一致
- [ ] 2.4 `skills/learning-assistant/SKILL.md` 可选一句（面板 Week Tab）

## 3. 文档

- [ ] 3.1 `integration_smoke.py` 可选 `week_load` 项
