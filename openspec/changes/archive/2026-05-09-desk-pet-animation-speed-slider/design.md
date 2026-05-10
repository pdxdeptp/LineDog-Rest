## Context

- 归档变更 「桌宠图标动态效果」已实现：`MalDazeDefaults` 布尔、`PetRenderer` 的 `animates` + 素材轮换定时器、`MenuBarContentView` 内 Toggle、通知刷新路径。
- 新需求：用 **单一滑杆** 覆盖 **静 ↔ 全速动** 的连续空间；右端对齐「当前全动态」行为，左端为 **完全静止**（含不轮换）。
- AppKit：`NSImageView` 对 GIF 多为整体 `animates` 开关；**帧间隔 / 播放速率** 无稳定公开旋钮，往往需要 **自定义解码与调度** 或通过 **Layer / 定时逐帧** 实现变速。

## Goals / Non-Goals

**Goals:**

- 持久化 **0…1**（或文档化的等价离散档位）标量；左端 = 静止，右端 = 与现状一致的「满速」动态（含轮换策略与当前一致）。
- **单调性**：标量增大时，用户感知到的「动态强度」**不应反向变弱**（除非刻意分段定义并写入 spec）。
- **菜单栏 / 桌宠** 共用 `MenuBarContentView`，Slider 与先前 Toggle 一样两处可见。
- **迁移**：曾使用布尔偏好的用户得到合理映射（关→0，开→1）。

**Non-Goals:**

- 不保证与 PawPal 或其它产品像素级一致的曲线；以 MalDaze 桌宠为准。
- 不在本设计稿中锁定具体 FPS 数值（依赖实现探测）。

## Decisions

1. **存储形态**  
   - **决策**：新增键 **`idlePetAnimationIntensity`**（示例名）存 **Double 0.0…1.0**（或 `UserDefaults` 可序列化的 Float）；**弃用**仅布尔键 `idlePetIconAnimationEnabled` 作为权威来源，启动时 **读旧键一次** 迁移：`false→0.0`、`true→1.0`，随后以新键为准。  
   - **理由**：连续模型与 Slider 一致；布尔键可保留兼容读取一轮后不再写入。

2. **UI**  
   - **决策**：`MenuBarContentView` 内用 **`Slider` + 两端标签**（如「静」「快」或「静止／ full」）替换 Toggle；**仅在结束拖动或松开时**（`onEditingChanged(false)`）投递通知，避免 RunLoop 过载。  
   - **备选**：连续通知 + ViewModel 节流——若实现更简单可切换，但默认避免噪音。

3. **标量 → 渲染语义（分两段）**  
   - **决策**：  
     - **\(s = 0\)**：`animates = false`，轮换 **Timer 关闭**，显示当前帧或首帧（与现「静态」一致）。  
     - **\(s = 1\)**：与归档行为一致：`animates = true`，轮换逻辑按 `PetDisplayMode` 连续态开启。  
     - **\(0 < s < 1\)**：**播放帧序列**，帧间隔 \(T(s) = T_{\max} + (1-s)(T_{\min}-T_{\max})\)** 或等价单调递减函数，使 \(s\) 越大越接近满速（\(T\) 越小）。若短期无法实现可靠变速，**最小可行**：两段线性插值 + **下限夹紧** 到可用间隔；或 **阶梯量化**（例如 5 档）并写入版本说明。  
   - **理由**：NSImageView 未必暴露速率 API，逐帧 Timer 可控；需后续 spike 验证性能与耗电。

4. **GIF 数据来源**  
   - **决策**：优先复用现有 `Bundle` GIF 解码路径；若逐帧需要，缓存 `NSImage` 帧数组或 `CGImageSource` 增量读取。  
   - **备选**：仅中间档降低 `animates` + 抽帧伪变速——体验差，不作为首选。

5. **通知**  
   - **决策**：扩展或替换为 **`idlePetAnimationIntensityChanged`**（或沿用原名但载荷含新值）；`AppViewModel` 仅触发 `PetRenderer` 刷新。  
   - **理由**：语义与布尔通知区分，便于排查。

## Risks / Trade-offs

- **[Risk]** 逐帧 Timer 耗电 / CPU → **缓解**：仅在 `0<s<1` 启用；`s∈{0,1}` 走原生路径。  
- **[Risk]** 多 GIF 轮换与「手动帧」路径并行 → **缓解**：统一由 `setDisplayMode` + `intensity` 入口编排，避免双 Timer 打架。  
- **[Trade-off]** 中间档实现复杂度 vs 产品期望 → 可在实现阶段将 **MVP** 定为 **三档**（静 / 半速 / 全速）再迭代连续 Slider，但 **spec 已按连续写**，实现若降级需回写 spec。

## Migration Plan

1. 发版读取 `idlePetIconAnimationEnabled`；若新键缺失则迁移并 **可选性清除** 旧键。  
2. 回滚：恢复布尔逻辑分支并忽略新键（需手工或 feature flag，不在此展开）。

## Open Questions

- 滑杆 **线性 vs 对数** 映射更符合直觉（实现前可做 1 次内部试用）。  
- **无障碍**：`accessibilityValue` 是否暴露「百分之 N 动态」。
