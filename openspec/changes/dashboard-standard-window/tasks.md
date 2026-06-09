## 1. Spec compliance tests (RED)

- [x] 1.1 更新 `ControlPanelPresentationTests`：Dashboard 使用 `NSWindow` 子类而非 `NSPanel`；断言统一 `show/toggle` 入口
- [x] 1.2 添加失败测试：`presentRest` / `presentBreakRun` 进入路径不得为休息启动而隐藏 Dashboard
- [x] 1.3 添加失败测试：无 global/local 外部点击 dismiss 监视器；无 `didResignActive` dashboard dismiss
- [x] 1.4 添加失败测试：`MalDazeDefaults` 含 dashboard frame 持久化键；`applicationShouldHandleReopen` 走 Dashboard 入口
- [x] 1.5 添加失败测试：桌宠 `presentDeskMenu` 不再依赖 `DeskPetDashboardPanelLayout` 锚点重定位（策略 A）

## 2. Dashboard standard window (GREEN)

- [x] 2.1 将 `DeskPetDashboardPanel` 升级为 `NSWindow` 子类：`canBecomeKey`/`canBecomeMain`、managed `collectionBehavior`、稳定 `identifier`
- [x] 2.2 实现 `toggleDashboardWindow()` 统一桌宠 / 快捷键 / Dock 入口；桌宠路径忽略 anchor（策略 A）
- [x] 2.3 实现 dashboard frame 持久化（`MalDazeDefaults` + load/save + clamp）；无记录时主屏居中
- [x] 2.4 移除外部点击与失活 dismiss 监视器；保留 Esc + `DeskPetDashboardEscapeRouter`；支持关闭钮 / Cmd+W 隐藏
- [x] 2.5 删除 `presentRest` / `presentBreakRun` 中因进入休息而 `closeDeskMenuImmediate()` 的调用

## 3. AppDelegate & integration

- [x] 3.1 `applicationShouldHandleReopen` 改为激活并 `toggle`/`show` Dashboard（恢复持久化 frame）
- [x] 3.2 确认全局快捷键 `presentDeskMenuFromGlobalShortcut` 走统一入口
- [x] 3.3 清理或降级 `DeskPetDashboardPanelLayout`（仅测试/首次默认 placement 若仍需要）

## 4. Verification

- [x] 4.1 `xcodebuild test` 相关用例通过（至少 `ControlPanelPresentationTests`）
- [ ] 4.2 手动 QA：Dock 打开记忆位置；桌宠左键开/关/toggle 不挪位；Mission Control 见 Dashboard 窗；Cmd+` 在桌宠窗与 Dashboard 间切换；点外部不关；休息霸屏时 Dashboard 未关、结束后仍可见；Esc 先关 sheet 再关窗
