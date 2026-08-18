import Cocoa

extension AppDelegate {
    /// Restyles the Cocoa-level chrome (tint, forced appearance, border) for
    /// `theme`. The SwiftUI side (`ContentView`'s `.primary`/`.secondary`
    /// colors and the toggle itself) updates on its own from the same
    /// `ThemeManager` via `@ObservedObject` — this only covers what SwiftUI
    /// can't reach: the `NSVisualEffectView` and its tint overlay.
    func applyTheme(_ theme: PanelTheme) {
        tintView.layer?.backgroundColor = theme.panelTint.cgColor
        effectView.layer?.borderColor = theme.borderColor.cgColor
        effectView.appearance = theme.appearance
    }
}
