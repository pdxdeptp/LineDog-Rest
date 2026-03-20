# LineDog Rest

Mac 菜单栏护眼桌宠（MVP）：25 分钟专注 / 5 分钟休息霸屏，或按系统整点、半点提醒休息。需求见根目录 [PRD.md](PRD.md)。

## 用 Xcode 打开与运行

1. 双击打开 **`LineDog.xcodeproj`**。
2. 选择 Scheme **LineDog**，运行目标为 **My Mac**（⌘R）。
3. 应用为 **仅菜单栏**（`LSUIElement`），Dock 中无图标；点菜单栏 **小狗图标** 打开控制面板。
4. 全程 **只有一只小狗**：默认在桌面 **右下角**；**点击桌宠**会弹出与菜单栏相同的控制面板（同一套 `MenuBarContentView`）。进入休息时 **同一只** 变为 **红色**，并沿原路径放大、移到屏幕中央，背景渐暗；除桌宠区域外点击仍穿透桌面。
5. **多显示器**：桌宠固定在 **菜单栏所在物理显示器**（通过 `CGMainDisplayID` 匹配 `NSScreen`，不依赖 `NSScreen.main`——后者在仅菜单栏类应用里会随键盘焦点屏漂移）。插拔或调换主屏后会短暂防抖再对齐几何；窗口不使用 `fullScreenAuxiliary`，以免双屏合成时被压在桌面之下。

## 使用说明

启动后**默认**为 **整点 / 半点** 模式（对齐系统时钟）；可在菜单里切到 **手动番茄**。

| 模式 | 行为 |
|------|------|
| **手动番茄** | 点「开始专注」后计时 25 分钟，结束后进入 5 分钟休息霸屏，再自动进入下一轮 25 分钟。 |
| **整点 / 半点** | 对齐系统时钟，在每小时 `:00` 与 `:30` 触发 5 分钟休息霸屏（例如 10:25 进入则 10:30 会提醒）。 |

两种模式下，计时进行中显示 **「停止计时」**；暂停后同一位置变为 **「恢复计时」**（手动：重新从 25 分钟工作段开始；自动：重新按当前时间对齐 `:00` / `:30` 锚点）。未点「开始专注」时「停止计时」为灰色不可点。

休息期间为 **无边框全屏置顶**（`NSWindow.Level.screenSaver`），**无关闭按钮**；需结束进程请使用菜单中的 **「退出应用」**（与 PRD 中「从状态栏菜单强行退出」一致）。

菜单中的 **「立即开始休息（测试）」** 会立刻走一遍 5 分钟霸屏动画，**不改动**当前番茄钟 / 自动锚点计时（仅用于联调 UI）。

## 自定义线条小狗素材

在 Xcode 中打开 **`LineDog/Assets.xcassets`**，向 **`LineDogPet`** 图像集拖入 PNG/PDF（建议透明底）。未配置时使用系统符号 `dog.fill` 作为占位。

## 工程结构（对应 PRD 模块化）

- **`TimerEngine/`**：`TimerEngine` 协议 + `ManualTimerEngine` / `AutoTimerEngine`，统一产出 `TimeState`。
- **`WindowManager/`**：唯一全屏透明 `NSWindow` + `PetStageView`（常态与休息同一套视图与 `PetRenderer`）。
- **`PetRenderer/`**：桌宠图像布局与缩放（可替换实现以接入 GIF / SpriteKit 等）。

## 命令行编译（可选）

```bash
cd /path/to/LineDog
xcodebuild -scheme LineDog -configuration Debug -destination 'platform=macOS' build
```

若需在沙箱或 CI 中指定产物目录，可增加 `-derivedDataPath ./DerivedData`。
