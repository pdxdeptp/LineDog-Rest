import AppKit
import CoreGraphics

/// 与「系统菜单栏」绑定的物理屏。勿用 `NSScreen.main`：在 LSUIElement / 仅菜单栏应用等场景下它会随**键盘焦点屏**变化，桌宠会跟着 Xcode 跑。
enum MenuBarNSScreen {
    private static let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")

    static var screen: NSScreen? {
        let menuBarDisplayID = CGMainDisplayID()
        for candidate in NSScreen.screens {
            guard let num = candidate.deviceDescription[screenNumberKey] as? NSNumber else { continue }
            if num.uint32Value == menuBarDisplayID {
                return candidate
            }
        }
        return NSScreen.screens.first
    }
}
