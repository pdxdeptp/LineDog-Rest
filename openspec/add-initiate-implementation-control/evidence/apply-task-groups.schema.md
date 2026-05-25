# Apply Task Groups Evidence Schema

Each change must create `evidence/<change>/apply-task-groups.json` during apply-readiness, before any apply implementation starts.

Required JSON shape:

```json
{
  "changeId": "introduce-study-intake-router",
  "generatedAt": "2026-05-25T03:56:29Z",
  "groups": [
    {
      "id": "stable-kebab-case-group-id",
      "taskIds": ["1.1", "4.1"],
      "description": "One independently verifiable implementation group.",
      "targetFiles": ["path/to/file.swift"],
      "testCommands": ["swift test --filter SomeTests"],
      "evidenceFile": "openspec/add-initiate-implementation-control/evidence/<change>/apply-groups/stable-kebab-case-group-id.md",
      "dependsOn": []
    }
  ]
}
```

The automation uses this file plus `state.json.applyCursor` as the recovery source for multi-hour apply runs.
