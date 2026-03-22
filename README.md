# LineDog Rest

Mac 菜单栏护眼桌宠（MVP）：25 分钟专注 / 5 分钟休息霸屏，或按系统整点、半点提醒休息。需求见根目录 [PRD.md](PRD.md)。

## 用 Xcode 打开与运行

1. 双击打开 **`LineDog.xcodeproj`**。
2. 选择 Scheme **LineDog**，运行目标为 **My Mac**（⌘R）。
3. 应用为 **仅菜单栏**（`LSUIElement`），Dock 中无图标；点菜单栏 **小狗图标** 打开控制面板。
4. **全局快捷键**（均在 **LineDog 设置** 中可改；默认用 **Carbon 全局热键**，一般 **无需**「辅助功能」）：
   - **⌘⇧<**（默认）：唤起 **添加提醒 / 智能输入** 对话框。
   - **⌘⇧.**（默认）：弹出与 **左键点桌宠** 相同的控制面板。
   - **⌥⌘R**（可选备用）：同上智能输入；依赖 **系统设置 → 隐私与安全性 → 辅助功能** 中对 LineDog 的授权（`NSEvent` 全局监听）。

自然语言里说「每天 / 每周 / 每月…」时，模型会在 JSON 里输出 `recurrence`，应用会写入系统提醒事项的 **重复**（EventKit `EKRecurrenceRule`）；`alarm_date` 表示**下一次**截止时间。

### 提醒事项权限：为什么每次编译都要再点一次「允许」？

系统 **不允许** App 自动勾选或绕过提醒权限，必须由你在系统对话框里确认（和日历、麦克风一样，属于 TCC）。

若你发现 **每 ⌘R / 重新编译一次就要再授权**，多半不是代码问题，而是 **调试签名不稳定**：Xcode 未指定 **Team** 时，常用临时/ ad hoc 签名，**每次构建主程序哈希会变**，macOS 会像对待「新应用」一样再次弹窗。

**建议**：Target **LineDog** → **Signing & Capabilities** → 勾选 **Automatically manage signing**，**Team** 选你的 **Apple ID（Personal Team）** 或开发者账号。保持 **Bundle Identifier** 不变（工程里为 `com.linedog.LineDog`）。这样授权会记在 **系统设置 → 隐私与安全性 → 提醒事项** 里，一般不必每编一次点一次。

从 macOS 14 起，若系统已记录为已授权，应用侧会先查 `authorizationStatus` 再决定是否调用 `requestAccess`，避免多余弹窗。
5. 全程 **只有一只小狗**：默认在桌面 **右下角**；**点击桌宠**会弹出与菜单栏相同的控制面板（同一套 `MenuBarContentView`）。进入休息时 **同一只** 变为 **红色**，并沿原路径放大、移到屏幕中央，背景渐暗；除桌宠区域外点击仍穿透桌面。
6. **多显示器**：桌宠固定在 **菜单栏所在物理显示器**（通过 `CGMainDisplayID` 匹配 `NSScreen`，不依赖 `NSScreen.main`——后者在仅菜单栏类应用里会随键盘焦点屏漂移）。插拔或调换主屏后会短暂防抖再对齐几何；窗口不使用 `fullScreenAuxiliary`，以免双屏合成时被压在桌面之下。

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
