## 1. Keychain layer

- [x] 1.1 Keychain read/write/delete helper
- [x] 1.2 Unit tests with mock / entitlements note

## 2. Migration

- [x] 2.1 Legacy UserDefaults → Keychain one-time migration
- [x] 2.2 读路径统一走 secure storage

## 3. UI / logging

- [x] 3.1 Settings 与 Dashboard provider row 接 Keychain
- [x] 3.2 审计日志不打印 key

## 4. Validation

- [ ] 4.1 QA：save / relaunch / show-hide / 多 provider
- [ ] 4.2 用户文档：建议轮换已暴露 key
- [x] 4.3 `openspec validate secure-provider-api-keys`
