import AppKit
import SwiftUI

/// 设置窗口：当前仅 Gemini API Key（PRD 额外需求）。
struct LineDogSettingsView: View {
    @AppStorage(LineDogDefaults.geminiAPIKey) private var geminiAPIKey = ""

    var body: some View {
        Form {
            Section {
                SecureField("Gemini API Key", text: $geminiAPIKey)
                    .textFieldStyle(.roundedBorder)
                Text("用于自然语言解析提醒事项；仅保存在本机 UserDefaults。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("智能输入 (Smart Input)")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 160)
        .padding()
    }
}

// MARK: - 独立设置窗（LSUIElement 下 `showSettingsWindow:` 往往无效）

@MainActor
enum LineDogSettingsWindowPresenter {
    private static var window: NSWindow?
    private static let windowDelegate = CloseHidesDelegate()

    /// 菜单栏代理应用需显式 `NSWindow`；与 SwiftUI `Settings` 场景并存，共享同一 `LineDogSettingsView` / `@AppStorage`。
    static func present() {
        NSApp.activate(ignoringOtherApps: true)
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 240),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            w.title = "LineDog 设置"
            w.isReleasedWhenClosed = false
            w.delegate = windowDelegate
            w.level = .floating
            let host = NSHostingController(rootView: LineDogSettingsView())
            w.contentViewController = host
            let contentSize = NSSize(width: 480, height: 240)
            let outerSize = w.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
            w.setFrame(LineDogPresentationAnchor.centeredFrame(forWindowContent: outerSize), display: false)
            window = w
        } else if let w = window {
            w.setFrame(LineDogPresentationAnchor.centeredFrame(forWindowContent: w.frame.size), display: true)
        }
        window?.makeKeyAndOrderFront(nil)
    }
}

/// 红点关闭时只隐藏，便于再次打开同一实例。
private final class CloseHidesDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
