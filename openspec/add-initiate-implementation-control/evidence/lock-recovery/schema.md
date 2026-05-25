# Lock Recovery Evidence Schema

When a stale `run.lock` is recovered automatically, write one Markdown evidence file in this directory.

Required fields:

- Timestamp
- Previous lock path
- Recovered lock path
- Stale age minutes
- Stale source: `lock.json.startedAt` or directory mtime
- Previous `lock.json` contents, if readable
- Recovery result
- Fresh lock creation result

The automation must move stale locks into `openspec/add-initiate-implementation-control/recovered-locks/`; it must not delete them silently.
