## Why

能耗排查旁发现 **偏好域存储明文 API key**（LLM provider settings）。与 CPU 无关，但是 **独立安全债务**；不应塞进 energy changes，避免 scope 膨胀与 review 混淆。

## What Changes

- 将 provider API key 从 `UserDefaults` 明文迁移至 **Keychain**（或等效 secure storage）。
- 迁移路径：首次 launch 读旧键 → 写入 Keychain → 删除明文。
- UI：show/hide 行为不变；日志不打印 key。
- 文档：建议用户轮换已暴露 key。
- **不** 改 LLM 调用契约。

## Capabilities

### New Capabilities

- `settings-secrets-storage`: Secure storage for provider credentials in MalDaze settings.

### Modified Capabilities

- `desk-pet-controls`: API key row SHALL persist secrets in secure storage, not plaintext preferences.

## Depends On

- None（与 energy changes 并行）。

## Impact

- `MalDaze/Settings/` 相关存储
- `MalDazeDefaults` / Keychain wrapper
- Settings UI tests
