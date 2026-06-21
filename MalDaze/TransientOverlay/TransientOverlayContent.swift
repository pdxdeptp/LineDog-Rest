import AppKit

/// Panel-free hosted content handed to `MalDazeTransientOverlayPresenter`.
struct TransientOverlayContent {
    let view: NSView
    let size: NSSize
    /// Retains SwiftUI hosting controllers for the lifetime of the overlay shell.
    let retainedObject: AnyObject?

    init(view: NSView, size: NSSize, retainedObject: AnyObject? = nil) {
        self.view = view
        self.size = size
        self.retainedObject = retainedObject
    }
}
