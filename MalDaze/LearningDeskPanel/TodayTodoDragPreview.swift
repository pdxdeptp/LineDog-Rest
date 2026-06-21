import SwiftUI

struct TodayTodoDragPreview: View {
    let title: String
    let width: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(Color.primary)
                .accessibilityHidden(true)

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
        }
        .frame(width: width, alignment: .leading)
    }
}
