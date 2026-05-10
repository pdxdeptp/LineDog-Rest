## Context

- **现状**：`MalDazeDefaults.idlePetIconSidePoints`（72…180 pt，默认 120，步进 4）由设置页 `Stepper` 写入；变更时 `MalDazeSettingsView` 投递 `idlePetIconSidePointsChanged`，`AppViewModel` → `WindowManager.applyIdlePetIconSideFromUserDefaults()` 更新桌宠窗口与点击命中区。逻辑已稳定。
- **目标交互**：与「桌宠动态强度」一致——在 **`MenuBarContentView`**（菜单栏与桌宠 Popover 共用）中用 **Slider** 调节边长，且控件出现在 **动态强度滑杆上方**。设置页移除重复入口，避免两处语义分叉。

## Goals / Non-Goals

**Goals:**

- Popover 内提供边长 Slider；拖动结束时再持久化并触发同步（与强度滑杆相同的「不在拖动每一帧刷屏」策略）。
- **与「桌宠动态强度」滑杆的视觉与交互一致**：同一套连续轨道外观与无极拖动体验（避免出现仅因 `Slider` 离散步进而产生的刻度线/刻度点）；存储侧仍按步进 4 pt 量化。
- 菜单栏入口与桌宠入口布局一致（同一 `MenuBarContentView`）。
- 更新依赖设置源码字符串的测试，使其反映面板侧控件。

**Non-Goals:**

- 不改变边长的合法区间、默认值、`UserDefaults` 键或通知名称。
- 不重构 `WindowManager` / `PetStageView` 的尺寸解析算法（仍使用 `clampedIdlePetIconSidePoints` 等现有工具）。
- 不要求在设置页保留「降级」副本控件（明确移除）。

## Decisions

1. **Slider 与整型步进 4**  
   - **做法**：UI 层使用 `Slider` + `step: 4`，绑定到与存储一致的整型闭区间（或通过 `Binding` 将 `Double` 与按步取整的 `Int` 桥接），保证落库值仍为步进 4 的整数。  
   - **理由**：与现有 `Stepper(step: 4)` 行为一致，避免存储中出现非法值。  
   - **备选**：连续滑杆仅在 `onEditingChanged(false)` 时四舍五入到最近 4 的倍数——略难预测，故优先离散步进。

2. **拖动中不写死 UserDefaults**  
   - **做法**：采用与 `idlePetAnimationIntensity` 相同的模式——可选用 `@State` 缓存拖动中的显示值，仅在 `onEditingChanged` 为 `false` 时写回 `@AppStorage` 并 `post` `idlePetIconSidePointsChanged`；若 SwiftUI 绑定在拖动结束才提交，则仅需在结束时分发通知。  
   - **理由**：减少 I/O 与窗口同步频率，避免主线程压力。

3. **安放区域**  
   - **做法**：在现有「桌宠动态强度」`VStack` **上方**新增「桌宠图标边长」分组（标签 + 左右端说明 + `Slider`），保持同一 `GroupBox`（专注计时）内视觉连贯；若垂直空间不足再调高 `controlPanelPreferredContentSize.height`。  
   - **理由**：与用户指定的相对顺序一致，并与相邻桌宠相关控件聚合。

4. **设置页**  
   - **做法**：删除「桌宠图标边长」`Stepper` 整段（含 `onChange` 发帖），保留同 Section 内快捷键等其余行。  
   - **理由**：单一事实来源在 Popover，避免重复维护。

## Risks / Trade-offs

- **[发现性]** 仅熟悉设置的用户可能找不到新位置 → **缓解**：保留 `.help` 或简短说明文案指向「菜单栏/桌宠面板」。
- **[测试脆性]** 静态源码断言依赖文件路径与字符串 → **缓解**：将断言改为扫描 `MenuBarContentView` 中的通知名与绑定键，或增加专用单元测试覆盖面板绑定。

## Migration Plan

- 无数据迁移；用户已保存的边长值不变。
- 回滚：恢复设置页 Stepper 并移除面板控件即可。

## Open Questions

- 是否在首次启动或升级后显示一次性提示（非本变更必须，可后续产品决定）。
