import SwiftUI

struct FocusDayTimelineFailedMarkerPopover: View {
    let marker: FocusDayTimelineFailedMarker
    let onDelete: (UUID) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(FocusDayTimelineFormatting.dateLine(marker.sessionStartedAt))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(FocusDayTimelineFormatting.timeRangeLine(
                    start: marker.sessionStartedAt,
                    end: marker.sessionEndedAt
                ))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                Text("已放弃 · 不计入番茄")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("删除记录", role: .destructive) {
                onDelete(marker.sessionID)
                onDismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .frame(minWidth: 220, alignment: .leading)
    }
}
