## Context

`plan` 要求项目已存在；历史由 agent 直接编辑 JSON，易错且无校验。MalDaze 面板只消费 `projects.json`。

## Goals / Non-Goals

**Goals**

- 对话内单层确认后原子化：`create-project` + `plan`。
- `plan`  stdout 含 `scheduled` / `overflow` 供 agent 回复用户。
- 面板文案对齐唯一入口。

**Non-Goals**

- 不做 `plan --dry-run`（建项目）。
- 不做 MalDaze 建项目表单。
- 不做 URL 拆解（仍在对话 LLM）。

## Decisions

1. **project id**：CLI `--id` 必填，slug 如 `lc_review`；agent 从标题生成。
2. **重复 id**：报错退出，不覆盖。
3. **确认层**：仅任务列表；overflow 在 plan 结果中说明，不二次确认。
4. **预览规则拆分**（SKILL）：plan 建项目免预览；move/set-deadline/insert/remove 保持原纪律。

## CLI sketch

```bash
schedule.py create-project \
  --id swift_intro \
  --name "Swift 入门" \
  --deadline 2026-08-01 \
  --source-url "https://..."

schedule.py plan --project-id swift_intro --tasks-file /tmp/candidates.json
```

## Risks

- Agent 仍可能跳过 create-project → skill 硬性步骤 + 单测覆盖 create-project。
