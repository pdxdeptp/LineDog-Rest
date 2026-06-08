# MalDaze 实施任务

> 依赖 Hermes 域 B 写端（`tasks-hermes.md` §4）产出有效契约后联调。  
> 域 A / 域 C **无** MalDaze 代码任务（仅 legacy 文案）。

## 1. 契约读取（域 B）

- [x] 1.1 **M-B1** 新建 `InterventionRequestContract.swift` 解析与校验（对齐 `desk-intervention-contract` spec）
- [x] 1.2 契约解析单元测试（合法 / 缺字段 / 过期 / 非法 kind）
- [x] 1.3 **M-B2** `InterventionRequestFileWatcher.swift`（对齐 Sleep 模式：FSEvents、唤醒、前台）

## 2. InterventionRequestController（域 B）

- [x] 2.1 **M-B1** `InterventionRequestController.swift`：加载、幂等、执行、ack
- [x] 2.2 **M-B5** ack 至 `consumed/{id}.json` 或等价机制
- [x] 2.3 **M-B3** `start(minutes:completionMessage:)`；结束铃铛用 `title` 非「X 分钟结束」
- [x] 2.3b **D2** 新 Hermes countdown 取消进行中任意倒计时
- [x] 2.3c 迟到启动：已过点 → 仅 `presentCenterBellReminder(title)`
- [x] 2.4 **M-B4** `kind: bell` → `presentCenterBellReminder`
- [x] 2.5 **B4/M** `kind: cancel` → 取消倒计时
- [x] 2.6 `AppViewModel` 持有并 `start()` Controller
- [x] 2.7 **M-B6** 契约单元测试（`InterventionRequestContractTests`）

## 3. Smart Input（D3：本 change 不改动）

- [x] 3.1 保持 SmartReminder / 右键 / 快捷键现状（无代码任务）

## 4. 工程与文档

- [x] 4.1 新文件加入 `MalDaze.xcodeproj`
- [x] 4.2 更新 `docs/integrations/hermes.md` 登记表（待联调状态已同步）
- [x] 4.3 README + `MANUAL_QA.md` 链到 features 文档

## 5. 联调验收

- [x] 5.1a 自动：`integration_smoke.py` bell/countdown 写入 → `consumed/`（⌘R 重启后）
- [x] 5.1b 30min countdown 铃铛文案 = `title`（`SevenMinuteReminderCompletionTests` + `integration_feishu_qa` `countdown_30_title`）
- [x] 5.2 重复同 `id` 不二次弹（`integration_smoke` idempotent）
- [x] 5.3 重启后未 ack 契约仍执行（轮询 3s 兜底 + 启动 `processPending`）
- [x] 5.4 非法 JSON fail-loud（smoke + `InterventionRequestContractTests`）
