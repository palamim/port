import AppKit
import SwiftUI

/// The 4th, non-scrolling container: thin enough that it reads as chrome
/// rather than a fourth data column. Quit button over the moon/divider/sun
/// theme toggle, top to bottom, sharing the same narrow strip — the quit
/// button sits in what was empty space above the toggle (the top `Spacer`
/// used to have nothing to balance against the bottom one). Whichever theme
/// mode is active stays solid, the other fades, so the pair alone
/// communicates state without a track/thumb metaphor.
struct ThemeToggleColumn: View {
    @ObservedObject var themeManager: ThemeManager

    private let dimOpacity: Double = 0.25

    var body: some View {
        VStack {
            QuitButton()
                .padding(.top, 6)
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

/// A small red dot, mirroring the macOS traffic-light close button, that
/// swaps in an "×" glyph on hover and quits Port on click. Deliberately
/// idle-state minimal (just a dot, no glyph) so it doesn't read as a data
/// indicator alongside the status glyphs in the three session columns —
/// the hover reveal is what marks it as a control, not content.
private struct QuitButton: View {
    @State private var isHovering = false

    private static let diameter: CGFloat = 10

    var body: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.37, blue: 0.35))
                    .frame(width: Self.diameter, height: Self.diameter)
                if isHovering {
                    Image(systemName: "xmark")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.black.opacity(0.65))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Quit Port")
    }
}
