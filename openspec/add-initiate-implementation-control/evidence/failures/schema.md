# Structured Failure Evidence Schema

Failures are appended as JSON lines to `failure-log.jsonl`. The latest blocking failure is also copied to `state.json.lastFailure`.

Required fields:

```json
{
  "timestamp": "2026-05-25T04:01:51Z",
  "automationId": "add-initiate-changes",
  "runCounter": 3,
  "currentChange": "introduce-study-intake-router",
  "currentCheckpoint": "introduce-study-intake-router:product_deepen_round_3",
  "checkpointAttempt": 1,
  "stage": "product_deepen",
  "category": "openspec_validate_failed",
  "summary": "Short human-readable summary.",
  "retryable": true,
  "command": "openspec validate introduce-study-intake-router --strict",
  "exitCode": 1,
  "paths": ["openspec/changes/introduce-study-intake-router/specs/study-intake-planning/spec.md"],
  "evidenceFile": "openspec/add-initiate-implementation-control/evidence/failures/2026-05-25T040151Z-openspec-validate-failed.md",
  "nextAction": "Fix validation issue within current checkpoint and retry."
}
```
