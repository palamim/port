import SwiftUI

/// The 4th, non-scrolling container: thin enough that it reads as chrome
/// rather than a fourth data column. Moon over a hairline divider over sun,
/// top to bottom; whichever mode is active stays solid, the other fades, so
/// the pair alone communicates state without a track/thumb metaphor.
struct ThemeToggleColumn: View {
    @ObservedObject var themeManager: ThemeManager

    private let dimOpacity: Double = 0.25

    var body: some View {
        VStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    themeManager.toggle()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.primary)
                        .opacity(themeManager.theme == .dark ? 1 : dimOpacity)
                    Rectangle()
                        .fill(Color.primary.opacity(0.2))
                        .frame(width: 11, height: 1)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.primary)
                        .opacity(themeManager.theme == .light ? 1 : dimOpacity)
                }
                .padding(6)
            }
            .buttonStyle(.plain)
            .help(themeManager.theme == .dark ? "Switch to light theme" : "Switch to dark theme")
            Spacer()
        }
        .frame(width: 20)
    }
}
