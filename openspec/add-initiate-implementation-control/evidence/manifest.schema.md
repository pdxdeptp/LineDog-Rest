# Evidence Manifest Schema

`manifest.json` is the machine-readable index for automation recovery. Append an entry after each completed checkpoint, migration, stale lock recovery, apply planning pass, apply group, cross-change contract check, and final report.

Required shape:

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-05-25T04:01:51Z",
  "entries": [
    {
      "id": "introduce-study-intake-router-product-deepen-round-1",
      "timestamp": "2026-05-25T03:43:28Z",
      "kind": "checkpoint",
      "changeId": "introduce-study-intake-router",
      "checkpoint": "introduce-study-intake-router:product_deepen_round_1",
      "result": "completed",
      "commands": [
        {
          "command": "openspec validate introduce-study-intake-router --strict",
          "exitCode": 0,
          "summary": "valid"
        }
      ],
      "artifacts": [
        {
          "path": "openspec/changes/introduce-study-intake-router/review-records/product-deepen-round-1.md",
          "sha256": "...",
          "description": "Human-readable product deepening evidence."
        }
      ],
      "nextCheckpoint": "introduce-study-intake-router:product_deepen_round_2"
    }
  ]
}
```

Allowed `kind` values:

- `checkpoint`
- `migration`
- `lock_recovery`
- `scope_dependency_check`
- `apply_planning`
- `apply_group`
- `cross_change_contract`
- `final_report`
