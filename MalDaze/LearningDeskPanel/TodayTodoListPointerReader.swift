import AppKit
import SwiftUI

struct TodayTodoPointerSample {
    let contentY: CGFloat
    let viewportY: CGFloat
    let windowPoint: CGPoint
}

final class TodayTodoListPointerView: NSView {
    var onAttached: ((TodayTodoListPointerView) -> Void)?
    weak var viewportView: NSView?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            onAttached?(self)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func pointerSample(from event: NSEvent) -> TodayTodoPointerSample? {
        let windowPoint = event.locationInWindow
        let contentLocal = convert(windowPoint, from: nil)
        let contentY = TodayTodoReorderPointerBridge.listPointerY(
            appKitLocalY: contentLocal.y,
            listHeight: bounds.height
        )

        let viewportY: CGFloat
        if let viewportView, viewportView.bounds.height > 0 {
            let viewportLocal = viewportView.convert(windowPoint, from: nil)
            viewportY = TodayTodoReorderPointerBridge.listPointerY(
                appKitLocalY: viewportLocal.y,
                listHeight: viewportView.bounds.height
            )
        } else {
            viewportY = contentY
        }

        return TodayTodoPointerSample(
            contentY: contentY,
            viewportY: viewportY,
            windowPoint: windowPoint
        )
    }

    func listPointerY(from event: NSEvent) -> CGFloat {
        pointerSample(from: event)?.contentY ?? 0
    }
}

struct TodayTodoListPointerReader: NSViewRepresentable {
    let viewportHeight: CGFloat
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
        context.coordinator.updateViewportView(for: nsView, viewportHeight: viewportHeight)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private weak var viewportView: NSView?

        func updateViewportView(for listView: TodayTodoListPointerView, viewportHeight: CGFloat) {
            guard viewportHeight > 0 else { return }
            if viewportView == nil {
                let view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: viewportHeight))
                view.isHidden = true
                listView.addSubview(view)
                viewportView = view
            }
            viewportView?.frame.size.height = viewportHeight
            listView.viewportView = viewportView
        }
    }
}
