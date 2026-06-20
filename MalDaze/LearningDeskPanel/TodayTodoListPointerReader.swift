import AppKit
import SwiftUI

final class TodayTodoListPointerView: NSView {
    var onAttached: ((TodayTodoListPointerView) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            onAttached?(self)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func listPointerY(from event: NSEvent) -> CGFloat {
        let local = convert(event.locationInWindow, from: nil)
        return TodayTodoReorderPointerBridge.listPointerY(
            appKitLocalY: local.y,
            listHeight: bounds.height
        )
    }
}

struct TodayTodoListPointerReader: NSViewRepresentable {
    let onAttach: (TodayTodoListPointerView) -> Void

    func makeNSView(context: Context) -> TodayTodoListPointerView {
        let view = TodayTodoListPointerView()
        view.onAttached = onAttach
        return view
    }

    func updateNSView(_ nsView: TodayTodoListPointerView, context: Context) {
        nsView.onAttached = onAttach
        if nsView.window != nil {
            onAttach(nsView)
        }
    }
}
