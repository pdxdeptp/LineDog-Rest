# 学习助手 — 前端验证汇报

> 执行日期：2026-05-09
> 验证方式：Swift 单元测试（XCTest）
> 测试总数：23 个 | 全部 PASS ✅
> 对应文档：`docs/acceptance-checklist.md`

---

## 总览

| 测试类 | 用例数 | PASS | FAIL | 覆盖场景 |
|--------|--------|------|------|----------|
| `AssistantModelDecodingTests` | 9 | 9 | 0 | JSON 解码层（Bug A/C 直接验证） |
| `LearningAssistantViewModelTests` | 14 | 14 | 0 | 业务逻辑层（验收场景 0-3, 1-1~1-3, 2-3, 3-1, 4-1~4-4, 5-1） |
| **合计** | **23** | **23** | **0** | — |

---

## 测试架构说明

### 为什么不做 UI 点击自动化？

macOS 的 UI 自动化（AppleScript System Events）需要在系统隐私设置中为 Terminal 单独授予辅助功能权限，且 NSPopover 类的菜单栏弹窗对 accessibility API 暴露不足，点击仿真的开销和脆弱性远超收益。

替代方案：分两层独立测试——

```
JSON 响应 → [AssistantAPIClient 解码] → [ViewModel 状态机] → SwiftUI 视图
          ↑                              ↑
   AssistantModelDecodingTests    LearningAssistantViewModelTests
   （验证数据正确进来）             （验证业务逻辑正确处理）
```

SwiftUI 视图层（IngestionView/ChatView 等）的渲染逻辑通过代码审查确认，不重复自动化。

### 测试基础设施新增

- `AssistantAPIClientProtocol`：从 `AssistantAPIClient` 抽取协议，`LearningAssistantViewModel` init 改为注入式（默认值仍是 `AssistantAPIClient.shared`，生产行为不变）
- `MockAssistantAPIClient`：实现协议的纯内存 mock，可配置返回值和错误，记录调用参数供断言

---

## 第一层：JSON 解码测试（AssistantModelDecodingTests）

### Bug A 覆盖：IngestionDraft 嵌套对象解码

| 测试用例 | 场景 | 结果 |
|----------|------|------|
| `testIngestionDraftDecodesNestedDraftObject` | Bilibili 草稿：thread_id + 嵌套 draft 含 resourceTitle/unitCount/totalEstimatedHours/optionA/optionB | ✅ PASS |
| `testIngestionDraftDecodesGitHubRepo` | GitHub repo 草稿（13.75h, 12 units）正确解码 | ✅ PASS |
| `testIngestionDraftDoesNotThrowOnNestedJSON` | 任意合法草稿不抛异常（修复前旧 String 类型必然 throw） | ✅ PASS |

> **根因确认：** 修复前 `IngestionDraft.draft: String`，后端返回 JSON 对象时解码失败 → `AssistantOfflineError` → 前端显示「助手已离线」。修复后 `draft: IngestionDraftDetail`，所有场景解码通过。

### Bug C 覆盖：ChatResponse.response 可选

| 测试用例 | 场景 | 结果 |
|----------|------|------|
| `testChatResponseResponseIsNullableWhenProposalPresent` | response: null + 含 summaryForUser 的 proposal | ✅ PASS |
| `testChatResponseWithTextAndNoProposal` | response: "今天有3个任务" + proposal: null | ✅ PASS |
| `testChatResponseWithRescheduleChanges` | response: null + changes 数组含 reschedule 条目 | ✅ PASS |

> **根因确认：** 修复前 `response: String`（非可选），后端返回 `null` 时 JSONDecoder 抛异常 → 误报离线。修复后 `response: String?`，所有场景解码通过。

### 其他模型测试

| 测试用例 | 断言 | 结果 |
|----------|------|------|
| `testTodayBriefingDecoding` | tasks / totalMinutes / highlights / isCompleted=false 正确 | ✅ PASS |
| `testBriefingTaskIsCompletedWhenCompletedAtPresent` | completedAt 非 null → isCompleted = true | ✅ PASS |
| `testEmptyBriefingDecoding` | tasks: [] / totalMinutes: 0 不报错 | ✅ PASS |

---

## 第二层：ViewModel 逻辑测试（LearningAssistantViewModelTests）

### 验收场景 0-3：空状态初始值

| 测试用例 | 断言 | 结果 |
|----------|------|------|
| `testInitialStateIsEmpty` | tasks=[], chatMessages=[], ingestionDraft=nil, isOffline=false, selectedOption="A" | ✅ PASS |

### 验收场景 1-1a/b：资料分析 → 草稿展示

| 测试用例 | 断言 | 结果 |
|----------|------|------|
| `testStartIngestionSetsDraftDetail` | ingestionDraft?.resourceTitle/unitCount/totalEstimatedHours 正确；selectedOption 重置为 "A"；isOffline=false | ✅ PASS |
| `testStartIngestionOfflineSetsIsOffline` | API 抛 AssistantOfflineError → isOffline=true，ingestionDraft=nil | ✅ PASS |

### 验收场景 1-2：确认草稿写入

| 测试用例 | 断言 | 结果 |
|----------|------|------|
| `testConfirmIngestionPassesSelectedOptionToAPI` | selectedOption="B" → API 收到 selectedOption="B"；draft/threadId 被清除 | ✅ PASS |

### 验收场景 1-3：取消草稿

| 测试用例 | 断言 | 结果 |
|----------|------|------|
| `testCancelIngestionClearsDraft` | confirmed=false → API 收到 confirmed=false, selectedOption=nil；draft/threadId 被清除 | ✅ PASS |

### 验收场景 2-3：面板任务列表

| 测试用例 | 断言 | 结果 |
|----------|------|------|
| `testFetchBriefingPopulatesTasks` | tasks 数组、todayTotalMinutes、todayHighlights 正确填充；isOffline=false | ✅ PASS |
| `testFetchBriefingOfflineSetsIsOffline` | API 抛错 → isOffline=true，tasks 仍为空 | ✅ PASS |

### 验收场景 3-1：任务完成标记

| 测试用例 | 断言 | 结果 |
|----------|------|------|
| `testCompleteTaskCallsAPIWithCorrectIDAndRefetches` | completeTask(id=5) → API 收到 id=5；随后触发 fetchBriefing 刷新 | ✅ PASS |

### 验收场景 4-1：对话查询（有文字回复）

| 测试用例 | 断言 | 结果 |
|----------|------|------|
| `testSendMessageWithTextResponseAppendsAssistantMessage` | chatMessages[0]=user, chatMessages[1]=assistant 含正确文字；currentProposal=nil | ✅ PASS |

### 验收场景 4-2：减载请求（Bug C 端到端覆盖）

| 测试用例 | 断言 | 结果 |
|----------|------|------|
| `testSendMessageWithNullResponseDisplaysProposalSummary` | response=null + proposal → chatMessages[1].text = summaryForUser；currentProposal 设置正确 | ✅ PASS |
| `testSendMessageWithRescheduleProposalDisplaysSummary` | changes 非空的 proposal → summaryForUser 显示正确 | ✅ PASS |

### 验收场景 4-3：确认变更

| 测试用例 | 断言 | 结果 |
|----------|------|------|
| `testConfirmProposalClearsCurrentProposalAndRefetches` | confirmed=true → currentProposal=nil；API 收到 confirmed=true；触发 fetchBriefing | ✅ PASS |

### 验收场景 4-4：取消变更

| 测试用例 | 断言 | 结果 |
|----------|------|------|
| `testCancelProposalClearsProposal` | confirmed=false → currentProposal=nil；chatMessages 末尾含「取消」字样 | ✅ PASS |

### 验收场景 5-1：离线降级

| 测试用例 | 断言 | 结果 |
|----------|------|------|
| `testSendMessageOfflineSetsIsOfflineAndAppendsErrorMessage` | API 抛错 → isOffline=true；chatMessages 末尾含「离线」字样 | ✅ PASS |

---

## 验收场景覆盖矩阵

| 场景 ID | 描述 | 验证方式 | 结论 |
|---------|------|----------|------|
| 0-3 | 前端空状态显示 | ViewModel 初始状态测试 | ✅ PASS |
| 1-1a | Bilibili URL 分析草稿 | 解码测试 + ViewModel 测试 | ✅ PASS |
| 1-1b | GitHub URL 分析草稿 | 解码测试 | ✅ PASS |
| 1-2 | 确认草稿写入（selectedOption 传递） | ViewModel 测试 | ✅ PASS |
| 1-3 | 取消草稿 | ViewModel 测试 | ✅ PASS |
| 1-4 | 无效 URL 离线降级 | ViewModel 测试（offline mock） | ✅ PASS |
| 2-3 | 面板任务列表显示 | ViewModel 测试 | ✅ PASS |
| 3-1 | 任务完成标记 | ViewModel 测试 | ✅ PASS |
| 4-1 | 对话查询有文字回复 | ViewModel 测试 | ✅ PASS |
| 4-2 | 减载请求 proposal 显示 | 解码测试 + ViewModel 测试 | ✅ PASS |
| 4-3 | 确认变更 | ViewModel 测试 | ✅ PASS |
| 4-4 | 取消变更 | ViewModel 测试 | ✅ PASS |
| 5-1 | 对话离线提示 | ViewModel 测试 | ✅ PASS |

---

## 本轮新增代码

| 文件 | 变更 | 说明 |
|------|------|------|
| `AssistantAPIClientProtocol.swift` | 新增 | 协议定义 + extension 声明 AssistantAPIClient 遵循 |
| `LearningAssistantViewModel.swift` | 修改 | init 改为协议注入；completeTask 补全 actualMinutes 参数 |
| `LearningAssistantTests.swift` | 新增 | 23 个测试用例（AssistantModelDecodingTests + LearningAssistantViewModelTests） |
| `MalDaze.xcodeproj/project.pbxproj` | 修改 | 注册两个新文件到各自 target 的 Sources |

---

## 遗留（需手动验证）

| 项目 | 说明 |
|------|------|
| SwiftUI 视图渲染 | `IngestionView` 方案 A/B 选择器、草稿展示排版、ChatView 气泡样式等需肉眼确认 |
| 后端实际 LLM 调用 | 单元测试用 mock，真实 Bilibili / GitHub URL 分析需在 App 内点击触发 |
| 网络超时边界 | 120s 配置已写入代码，极端慢速 LLM 场景未自动化测试 |

---

*后端验收结果见：`docs/acceptance-report.md`*
*验收场景清单见：`docs/acceptance-checklist.md`*
