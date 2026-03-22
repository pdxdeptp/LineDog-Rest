import Foundation

/// 跨模块松耦合用通知；不含桌宠渲染逻辑。`WindowManager` 在常态小狗窗框变化时投递，其它功能仅订阅。
enum LineDogBroadcastNotifications {
    static let idlePetScreenFrameChanged = Notification.Name("com.linedog.idlePetScreenFrameChanged")
    /// 全局快捷键唤起智能提醒输入（Carbon 热键或 `LineDogAppDelegate` 的 ⌥⌘R 监听投递）。
    static let openSmartReminderInput = Notification.Name("com.linedog.openSmartReminderInput")
    /// 全局快捷键弹出桌宠菜单（与左键点桌宠相同面板）。
    static let presentDeskPetMenu = Notification.Name("com.linedog.presentDeskPetMenu")
    /// `userInfo` 中为 `NSValue` 包 `NSRect`（屏幕坐标）。
    static let idlePetScreenFrameUserInfoKey = "screenFrame"
}
