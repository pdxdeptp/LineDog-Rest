import AppKit
import SwiftUI
import XCTest
@testable import MalDaze

final class TodayTodoContentLayoutTests: XCTestCase {
    func testScrollViewContentProbeReportsFullListHeightWhenViewportIsCapped() {
        assertScrollContentHeight(listHeight: 100, viewportHeight: 40, expectedContentHeight: 100)
        assertScrollContentHeight(listHeight: 220, viewportHeight: 80, expectedContentHeight: 220)
    }

    private func assertScrollContentHeight(
        listHeight: CGFloat,
        viewportHeight: CGFloat,
        expectedContentHeight: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let capture = ScrollContentHeightCapture()
        let probe = ScrollViewListContentProbe(
            listHeight: listHeight,
            viewportHeight: viewportHeight,
            capture: capture
        )
        let hostingView = NSHostingView(rootView: probe.frame(width: 320))
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertEqual(
            capture.value,
            expectedContentHeight,
            accuracy: 0.5,
            "ScrollView content probe should report intrinsic list height independent of viewport cap.",
            file: file,
            line: line
        )
    }
}

private final class ScrollContentHeightCapture {
    var value: CGFloat = 0
}

private struct ScrollViewListContentProbe: View {
    let listHeight: CGFloat
    let viewportHeight: CGFloat
    let capture: ScrollContentHeightCapture

    var body: some View {
        ScrollView(showsIndicators: false) {
            Color.clear
                .frame(height: listHeight)
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear {
                                capture.value = geometry.size.height
                            }
                            .onChange(of: geometry.size.height) { newHeight in
                                capture.value = newHeight
                            }
                    }
                }
        }
        .frame(height: viewportHeight)
    }
}
