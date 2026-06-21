import AppKit
import SwiftUI

final class TodayTodoScrollEdgeHostView: NSView {
    private var velocity: CGFloat = 0
    private var timer: Timer?

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func setVelocity(_ velocity: CGFloat) {
        self.velocity = velocity
        if velocity == 0 {
            stopTimer()
        } else if timer == nil {
            startTimer()
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard velocity != 0,
              let scrollView = enclosingScrollView,
              let clipView = scrollView.contentView as NSClipView?,
              let documentView = scrollView.documentView
        else { return }

        let delta = velocity / 60.0
        var origin = clipView.bounds.origin
        origin.y += delta

        let maxY = max(documentView.frame.height - clipView.bounds.height, 0)
        origin.y = min(max(origin.y, 0), maxY)
        clipView.scroll(to: origin)
        scrollView.reflectScrolledClipView(clipView)
    }

    deinit {
        stopTimer()
    }
}

struct TodayTodoScrollEdgeBridge: NSViewRepresentable {
    let velocity: CGFloat

    func makeNSView(context: Context) -> TodayTodoScrollEdgeHostView {
        TodayTodoScrollEdgeHostView()
    }

    func updateNSView(_ nsView: TodayTodoScrollEdgeHostView, context: Context) {
        nsView.setVelocity(velocity)
    }
}
