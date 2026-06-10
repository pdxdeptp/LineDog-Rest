# Scope Decision · add-nutrition-today-panel

日期：2026-06-09（用户追加 · 2026-06-09）

## 用户已定稿（P0）

| ID | 决策 |
|----|------|
| **D1** | 方案 A：`daily_log.json` + `panel` |
| **D2** | 左栏计划 + 饮食垂直分栏（默认 60/40） |
| **D4** | 健身仅 `dayLabel` 一行 |
| **D5** | Superseded by `use-hermes-authored-nutrition-recommendations`: v1 keeps `panel.suggestions: []` for schema compatibility; user-visible recommendations come from Hermes-authored `recommendation.json` |

## 用户追加纳入（2026-06-09 · 覆盖初版展示-only）

| ID | 决策 |
|----|------|
| **S3** | `integration_smoke` 断言 `panel.schemaVersion == 1` — **必做** |
| **S4** | `recommend.py refresh-panel` — **必做** |
| **S5** | 桌宠展示钠 `sodium_mg` — **必做** |
| **S6** | 设置可调左栏 60/40 比例 — **必做** |
| **S7** | 建议区每个食物项点击 → `recommend.py log` — **必做** |
| **S7-K** | 主键盘 `1`–`9` 扁平序号快捷 log — **必做**；详设 `design-nutrition-log-interaction.md` |

## 仍纳入（初版）

| ID | 决策 |
|----|------|
| **S1** | `plan_engine` 脚本内常量食物集仅作 candidate-only 上下文；不发布到 `panel.suggestions` 或 MalDaze |
| **S2** | 45s `updatedAt` 轮询兜底 |

## 仍排除

- 面板 undo / 试算 / 改日型
- Python/Swift 本地生成、过滤或重排用户可见建议
- 中栏学习饮食 Tab、P3 健身助手、飞书深链

## Final

**KEEP CURRENT SCOPE + S3–S7**（加入受控写交互；写路径仅 CLI `log`）
