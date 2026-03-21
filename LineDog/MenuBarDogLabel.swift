import SwiftUI

/// 状态栏小狗：计时中黑、暂停白身黑边、休息红。
struct MenuBarDogLabel: View {
    let mode: PetDisplayMode

    private let iconSize: CGFloat = 15

    var body: some View {
        switch mode {
        case .runningBlack:
            Image(systemName: "dog.fill")
                .font(.system(size: iconSize))
                .symbolRenderingMode(.monochrome)
                // `.black` 在深色菜单栏上不可见，表现为「图标消失」。
                .foregroundStyle(.primary)
        case .pausedWhiteOutline:
            ZStack {
                Image(systemName: "dog.fill")
                    .font(.system(size: iconSize * 1.22))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.black)
                Image(systemName: "dog.fill")
                    .font(.system(size: iconSize))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
            }
            .frame(width: 22, height: 18)
        case .restingRed:
            Image(systemName: "dog.fill")
                .font(.system(size: iconSize))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.red)
        case .thinking:
            Image(systemName: "sparkles")
                .font(.system(size: iconSize))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.indigo)
        }
    }
}
