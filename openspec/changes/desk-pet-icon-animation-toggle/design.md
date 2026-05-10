## Context

- 桌宠窗口由 `PetStageView` 承载，内部使用 `PetRenderer` 加载 `Bundle` 内 GIF；`NSImageView.animates` 控制帧动画，另有 `Timer` 在「连续状态」（如计时中黑狗、思考态）下每隔固定间隔随机切换不同 GIF 文件。
- 菜单栏小狗不使用 `PetRenderer`，但**菜单栏与桌宠共用** `MenuBarContentView` 作为控制面板内容来源；产品期望两处 Popover **尽可能同步**（同一套控件与布局，而非某一入口独有）。
- 项目测试禁止在 `MenuBarContentView` 内注入 **桌宠专用 presentation 环境**（如 `maldazeDeskMenuPresentation` / `.deskPetFloatingPanel` 等 token）。在共享视图内增加与普通偏好一致的 `@AppStorage` Toggle **不违反**该约束，也与「边长 Stepper」等已有桌宠相关控件的模式一致。

## Goals / Non-Goals

**Goals:**

- 用户可在 **菜单栏面板** 与 **桌宠面板** 中**同一位置、同一控件**切换「桌宠图标是否动态」（默认动态，与现状一致）。
- 偏好写入 **UserDefaults**，应用重启后保持。
- 切换后立即作用于当前运行的桌宠 `PetRenderer`。
- 「静态」语义清晰：GIF 不播放且不在后台继续周期性更换素材（除非随后用户重新开启动态或切换显示模式触发刷新）。

**Non-Goals:**

- 不在本变更中强制在「设置」窗口重复该开关（可作为后续可用性增强）。
- 不改变 GIF 资源集合、休息/计时状态机或菜单栏图标绘制。
- 不提供「仅停止帧动画但仍每 N 分钟换一张静态图」的细分模式（若未来需要可单独提案）。

## Decisions

1. **持久化键名**  
   - **决策**：在 `MalDazeDefaults` 增加布尔键（例如 `idlePetIconAnimationEnabled`），默认 `true`。  
   - **理由**：与 `idlePetIconSidePoints` 等桌宠相关偏好并列。

2. **静态模式行为**  
   - **决策**：`animates = false` **且** `invalidate` 素材轮换 `Timer`。  
   - **理由**：避免「静态」却仍偶发换图。

3. **运行时同步机制**  
   - **决策**：`Notification.Name`（如 `idlePetIconAnimationChanged`）；`AppViewModel` 订阅并刷新 `PetRenderer`。  
   - **理由**：与边长热更新一致。

4. **UI 放置（修订）**  
   - **决策**：开关放在 **`MenuBarContentView` 内**，与现有 **Toggle / Stepper 分组同一视觉层级**（例如靠近已有「桌宠」相关控件区块或主控制列中的合适分组），**禁止**在 `WindowManager.makeDeskPetControlPanelRootView` 外包独立顶栏或单独工具条造成「只有桌宠才有」或「顶栏一条、下面一大块」的分裂布局。  
   - **理由**：用户期望菜单栏与桌宠 Popover **内容同步**；顶栏-only / 桌宠-only 违背该期望。  
   - **废止**：此前「仅在桌宠 Popover 外壳堆 `VStack` + 顶栏 Toggle」的方案。

5. **Popover 尺寸**  
   - **决策**：若新增控件导致纵向不足，调整 **`MenuBarContentView.controlPanelPreferredContentSize`**（或等价单一尺寸源），使 **菜单栏与桌宠** 共用同一尺寸逻辑，避免一侧裁切、另一侧留白不一致。

## Risks / Trade-offs

- **[Risk]** `MenuBarContentView` 已较密：新增一行需避免挤压可读性——**缓解**：与现有分组对齐，必要时略增首选高度。  
- **[Risk]** `PetRenderer` 与 `setDisplayMode` 交错——**缓解**：集中「应用素材 + 尊重动画开关」逻辑。

## Migration Plan

- 新键默认 `true`：现有用户无行为变化。  
- 若已实现「桌宠顶栏」版本：迁移为删除外壳 `VStack`/工具条，把 Toggle 移入 `MenuBarContentView`，并恢复 Popover 专用增量高度（若曾增加）。

## Open Questions

- 文案：「桌宠图标动态效果」等与产品中文 Copy 最终统一。
