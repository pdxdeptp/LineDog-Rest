# Commit Evidence Schema

Before implementation begins for a change, write a pre-apply checkpoint commit evidence file:

```md
# Pre-Apply Checkpoint Commit: <change>

- Timestamp:
- Change:
- Commit hash:
- Staged paths:
- Verification commands:
- Result:
- Next checkpoint:
```

If a commit is deferred instead of created, write:

```md
# Commit Deferral: <change>

- Timestamp:
- Change:
- Reason:
- Dirty paths:
- Blocking category:
- Next safe action:
```

The matching structured failure category is `commit_blocked` when deferral prevents apply from starting.
