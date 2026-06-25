## Context

- Provider API keys in UserDefaults/preferences domain.
- Discovered during energy diag session—rotation recommended if logs shared.

## Goals / Non-Goals

**Goals:**

- Keychain storage with migration.
- No plaintext in preferences after migration.

**Non-Goals:**

- Energy fixes.
- Server-side key management.

## Decisions

### D1: Keychain service identifier

`com.maldaze.settings.provider-api-key.<providerId>` or single generic service with account per provider.

### D2: One-time migration on read

If UserDefaults has value and Keychain empty → migrate → remove UserDefaults key.

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| Migration miss | read path checks both once |
| Keychain access prompt | not applicable for app self storage |

## Migration Plan

1. Keychain helper.
2. Migration on settings load.
3. QA show/hide/save/relaunch.
4. User comms: rotate if exposed.

## Open Questions

- Which providers in scope—match existing settings picker list.
