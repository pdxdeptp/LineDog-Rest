import Foundation

/// 跨模块松耦合用通知；不含桌宠渲染逻辑。`WindowManager` 在常态小狗窗框变化时投递，其它功能仅订阅。
enum MalDazeBroadcastNotifications {
    static let idlePetScreenFrameChanged = Notification.Name("com.maldaze.idlePetScreenFrameChanged")
    /// 全局快捷键唤起智能提醒输入（Carbon 热键或 `MalDazeAppDelegate` 的 ⌥⌘R 监听投递）。
    static let openSmartReminderInput = Notification.Name("com.maldaze.openSmartReminderInput")
    /// 全局快捷键弹出桌宠菜单（与左键点桌宠相同面板）。
    static let presentDeskPetMenu = Notification.Name("com.maldaze.presentDeskPetMenu")
    /// 全局快捷键切换独立倒计时提醒（进行中则取消，否则按设置时长开始）。
    static let toggleSevenMinuteReminder = Notification.Name("com.maldaze.toggleSevenMinuteReminder")
    /// 全局快捷键：常态桌宠窗回到菜单栏屏可见区右下角并持久化（休息霸屏中忽略）。
    static let resetIdlePetPositionToDefault = Notification.Name("com.maldaze.resetIdlePetPositionToDefault")
    /// 设置页调整常态桌宠图标边长后投递；运行中的 `AppViewModel` 负责同步到窗口。
    static let idlePetIconSidePointsChanged = Notification.Name("com.maldaze.idlePetIconSidePointsChanged")
    /// `userInfo` 中为 `NSValue` 包 `NSRect`（屏幕坐标）。
    static let idlePetScreenFrameUserInfoKey = "screenFrame"
}
