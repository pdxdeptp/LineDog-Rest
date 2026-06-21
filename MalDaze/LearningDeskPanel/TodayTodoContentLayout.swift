import SwiftUI

struct TodayTodoMeasuredGeometry: Equatable {
    var listSize: CGSize?
    var draftRowHeight: CGFloat?

    var isComplete: Bool {
        guard let listSize, let draftRowHeight else { return false }
        guard listSize.width.isFinite, listSize.height.isFinite,
              draftRowHeight.isFinite, draftRowHeight > 0,
              listSize.width >= 0, listSize.height >= 0
        else { return false }
        return true
    }

    mutating func merge(_ other: TodayTodoMeasuredGeometry) {
        if let listSize = other.listSize {
            self.listSize = listSize
        }
        if let draftRowHeight = other.draftRowHeight {
            self.draftRowHeight = draftRowHeight
        }
    }
}

struct TodayTodoMeasuredGeometryKey: PreferenceKey {
    static let defaultValue = TodayTodoMeasuredGeometry()

    static func reduce(value: inout TodayTodoMeasuredGeometry, nextValue: () -> TodayTodoMeasuredGeometry) {
        value.merge(nextValue())
    }
}

private enum TodayTodoContentLayoutAnchors {
    static let top = "today-todo-scroll-top"
    static let bottom = "today-todo-scroll-bottom"
}

/// 固定 ScrollView / draft / Spacer 结构；由 policy 派生 viewport 与滚动。
struct TodayTodoContentLayout<ListContent: View, DraftContent: View>: View {
    let listRowSpacing: CGFloat
    let draftMinimumHeight: CGFloat
    @ViewBuilder var todoEntries: () -> ListContent
    @ViewBuilder var draftFieldRow: () -> DraftContent

    @State private var lastCompleteSnapshot: TodayTodoMeasuredGeometry?
    @State private var liveWidth: CGFloat = 0
    @State private var availableHeight: CGFloat = 0
    @State private var lastResolvedMode: TodayTodoLayoutMode = .measuring
    @State private var edgeScrollVelocity: CGFloat = 0

    private var resolution: TodayTodoLayoutResolution {
        let snapshot = lastCompleteSnapshot
        return TodayTodoLayoutPolicy.resolve(
            listHeight: snapshot?.listSize?.height,
            draftRowHeight: snapshot?.draftRowHeight,
            draftMinimumHeight: draftMinimumHeight,
            measuredListWidth: snapshot?.listSize?.width,
            liveWidth: liveWidth,
            availableHeight: availableHeight,
            listRowSpacing: listRowSpacing
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ScrollViewReader { scrollProxy in
                VStack(alignment: .leading, spacing: listRowSpacing) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: listRowSpacing) {
                            Color.clear
                                .frame(height: 0)
                                .id(TodayTodoContentLayoutAnchors.top)

                            measuredTodoEntries()

                            Color.clear
                                .frame(height: 0)
                                .id(TodayTodoContentLayoutAnchors.bottom)

                            TodayTodoScrollEdgeBridge(velocity: edgeScrollVelocity)
                                .frame(width: 0, height: 0)
                        }
                    }
                    .scrollDisabled(!resolution.listScrollEnabled)
                    .frame(height: resolution.listViewportHeight, alignment: .topLeading)
                    .environment(\.todayTodoListViewportHeight, resolution.listViewportHeight)

                    measuredDraftFieldRow()
                        .layoutPriority(1)

                    Spacer(minLength: 0)
                }
                .frame(width: width, height: height, alignment: .topLeading)
                .onAppear {
                    liveWidth = width
                    availableHeight = height
                    lastResolvedMode = resolution.mode
                }
                .onChange(of: geometry.size) { newSize in
                    liveWidth = newSize.width
                    availableHeight = newSize.height
                }
                .onChange(of: resolution.mode) { newMode in
                    guard newMode != lastResolvedMode else { return }
                    scrollToAnchor(for: newMode, scrollProxy: scrollProxy)
                    lastResolvedMode = newMode
                }
                .onPreferenceChange(TodayTodoMeasuredGeometryKey.self) { geometry in
                    guard geometry.isComplete else { return }
                    let previousListHeight = lastCompleteSnapshot?.listSize?.height
                    lastCompleteSnapshot = geometry

                    guard resolution.mode == .pinned,
                          let newListHeight = geometry.listSize?.height,
                          let previousListHeight,
                          newListHeight > previousListHeight + TodayTodoLayoutPolicy.layoutTolerance
                    else { return }

                    scrollToAnchor(for: .pinned, scrollProxy: scrollProxy)
                }
                .onPreferenceChange(TodayTodoReorderEdgeScrollPreferenceKey.self) { preference in
                    edgeScrollVelocity = resolution.listScrollEnabled && preference.enabled
                        ? preference.velocity
                        : 0
                }
            }
        }
    }

    private func measuredTodoEntries() -> some View {
        todoEntries()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { contentGeometry in
                    Color.clear.preference(
                        key: TodayTodoMeasuredGeometryKey.self,
                        value: TodayTodoMeasuredGeometry(
                            listSize: contentGeometry.size,
                            draftRowHeight: nil
                        )
                    )
                }
            }
    }

    private func measuredDraftFieldRow() -> some View {
        draftFieldRow()
            .background {
                GeometryReader { contentGeometry in
                    Color.clear.preference(
                        key: TodayTodoMeasuredGeometryKey.self,
                        value: TodayTodoMeasuredGeometry(
                            listSize: nil,
                            draftRowHeight: contentGeometry.size.height
                        )
                    )
                }
            }
    }

    private func scrollToAnchor(for mode: TodayTodoLayoutMode, scrollProxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            switch mode {
            case .compact:
                scrollProxy.scrollTo(TodayTodoContentLayoutAnchors.top, anchor: .top)
            case .pinned:
                scrollProxy.scrollTo(TodayTodoContentLayoutAnchors.bottom, anchor: .bottom)
            case .measuring:
                break
            }
        }
    }
}
