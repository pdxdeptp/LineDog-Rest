## Why

`InterventionRequestController` 在 `start()` 时除 FSEvents 外还启动 **3s repeating** `pollTimer`，理由是 FSEvents 漏报兜底。同一 spec（`desk-intervention`）已要求 **wake / becomeActive reconcile**，与 sleep 链路一致——repeating poll 是 **机制重复**，对 idle baseline 有 constant wake，且不是 diag 主因。治本是 **单一可靠通道**：FSEvents + lifecycle reconcile，而非拉长 poll 间隔。

## What Changes

- 移除 `InterventionRequestController` 的 3s repeating `pollTimer`（或 gated 为仅 debug）。
- 保留/强化：`InterventionRequestFileWatcher`（FSEvents）、`wakeObserver`、`becomeActiveObserver` → `processPendingIfNeeded()`。
- 补测试：文件变更、wake 后对账仍可靠。
- **不** 改 Hermes contract、bell UI、ack 语义。

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `desk-intervention`: Lifecycle watching SHALL NOT require a repeating poll timer when FSEvents and wake/foreground reconcile are active.

## Depends On

- Recommended after M1；与 Change 3 可并行。

## Impact

- `MalDaze/InterventionRequest/InterventionRequestController.swift`
- `MalDazeTests/*Intervention*`（现有或新增）
