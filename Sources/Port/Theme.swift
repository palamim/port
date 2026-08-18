import Cocoa
import Combine
import SwiftUI

/// Port's own light/dark toggle for the panel's translucent chrome —
/// independent of System Settings' appearance, since the panel is meant to
/// be readable against whatever's behind it regardless of what the rest of
/// the desktop is doing. Persisted so a relaunch keeps whichever mode was
/// last chosen.
enum PanelTheme: String {
    case dark
    case light

    /// Tint overlaid on the `NSVisualEffectView` in `AppDelegate`. `.dark`
    /// mirrors the original hardcoded constant this app shipped with;
    /// `.light` is a bright counterpart at the same alpha so translucency
    /// reads the same strength under either mode.
    var panelTint: NSColor {
        switch self {
        case .dark: return NSColor(calibratedRed: 0.02, green: 0.035, blue: 0.06, alpha: 0.65)
        case .light: return NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.98, alpha: 0.65)
        }
    }

    /// Forces the hosting `NSVisualEffectView` (and the SwiftUI content
    /// inside it, since `.primary`/`.secondary` follow the effective
    /// appearance) into the matching mode rather than following System
    /// Settings — same reasoning as `panelTint`.
    var appearance: NSAppearance? {
        NSAppearance(named: self == .dark ? .vibrantDark : .vibrantLight)
    }

    var borderColor: NSColor {
        self == .dark ? NSColor.white.withAlphaComponent(0.2) : NSColor.black.withAlphaComponent(0.15)
    }
}

/// Publishes the current `PanelTheme` and persists it to `UserDefaults`.
/// Shared between `AppDelegate` (which owns the Cocoa-level chrome — tint,
/// appearance, border) and `ContentView` (which owns the SwiftUI toggle
/// that flips it).
final class ThemeManager: ObservableObject {
    private static let defaultsKey = "port.theme"

    @Published var theme: PanelTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.defaultsKey) }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.defaultsKey)
        self.theme = stored.flatMap(PanelTheme.init(rawValue:)) ?? .dark
    }

    func toggle() {
        theme = (theme == .dark) ? .light : .dark
    }
}

extension Color {
    static let working = Color(red: 0.35, green: 0.68, blue: 0.98)
    static let needsInput = Color(red: 0.95, green: 0.75, blue: 0.25)
    static let completed = Color(red: 0.35, green: 0.78, blue: 0.45)

    /// Softer, lower-saturation variants used only for the column glow —
    /// the dot colors above read fine at 6pt but are too saturated for a
    /// background wash across a whole column.
    static let needsInputGlow = Color(red: 1.0, green: 0.91, blue: 0.62)
    static let completedGlow = Color(red: 0.68, green: 0.94, blue: 0.76)
}
