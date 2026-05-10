## Why

已有变更（归档：`desk-pet-icon-animation-toggle`）用 **布尔开关** 在「完全静态」与「当前完整 GIF 动态」之间切换。用户反馈希望 **更细粒度**：同一控件内从 **最左完全静止** 连续过渡到 **最右与现状一致的动态强度**，中间档位对应 **动画播放快慢（或等效的动态强度）**，而不是非此即彼的二元选择。

## What Changes

- **持久化模型演进**：用 **连续档位**（例如归一化 **0.0…1.0** 的标量，或等价整数存储）替代仅存的 **布尔**「是否动态」键；对已有用户做 **迁移**（例如曾关闭动画 → 0，曾开启 → 1），避免静默重置偏好。**BREAKING** 仅针对存储键语义：实现阶段需定义旧键读取策略（读一次迁移后删除或保留只读兼容）。
- **`PetRenderer`**：根据标量控制 **静止 vs 播放** 及 **播放快慢**：左端点等价于「定格 + 不轮换素材」；右端点等价于当前归档行为中的「全速 GIF + 原有轮换策略」；中间值 **单调** 映射到可见动画速率（具体映射见 design）。
- **共享控制面板 UI**：在 **`MenuBarContentView`** 中用 **Slider**（配简短标签 / 两端辅助文案）替换现有「桌宠图标动态效果」**Toggle**；菜单栏与桌宠 Popover **仍共用同一份视图**，保持 parity。
- **运行时同步**：沿用或细化通知（若标量变更频率高于布尔，需防抖或仅在 `onEditingChanged(false)` 提交，避免拖动时每秒轰炸——细节见 design）。
- **测试**：更新 `PetRenderer` 相关单测；必要时增加映射与迁移测试。

## Capabilities

### New Capabilities

- `desk-pet-animation-speed`: 用户在共享控制面板通过 **连续滑杆** 调节右下角桌宠 GIF 的「动态强度」：最小为完全静止；最大与当前产品「全动态」一致；中间值为单调变化的动画速率（或等效视觉效果）。

### Modified Capabilities

<!-- 根目录 `openspec/specs/` 尚无已合并的 `desk-pet-icon-animation`；归档中的行为由本变更 **语义替代**（布尔 → 连续）。若在合并主 specs 时需 delta，应在 archive 与主树对齐后再补。 -->

## Impact

- **修改**：`MalDazeDefaults`（新键或扩写旧键）、`PetRenderer`、`PetStageView`、`MenuBarContentView`（Toggle→Slider）、`AppViewModel` / `WindowManager`（通知与刷新路径）、`MalDazeBroadcastNotifications`（更名或扩展语义）
- **迁移**：首次启动读取旧布尔键并写入新标量
- **风险**：AppKit `NSImageView` 对 GIF **播放速率** 的直接 API 有限，实现可能需要自定义帧调度或 Layer；见 design
