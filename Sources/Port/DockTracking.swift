import Cocoa

/// A trimmed-down port of Starboard's Dock-tracking, further trimmed of the
/// one piece that actually needed Accessibility permission: Starboard reads
/// the Dock's exact icon-tray rect (via the AX API) because it sits flush
/// against the Dock's icons and needs to know precisely where they end —
/// see its `dockIconTrayFrame`/`gluedFrame`. Port sits at the opposite
/// corner at a fixed width, independent of the Dock's icon layout, so it
/// never needs that rect. What's left is entirely permission-free: which
/// screen hosts the Dock (`dockWindowHostScreen`, from the Dock's own
/// window bounds) and how tall a strip macOS reserves for it there
/// (`NSScreen.visibleFrame`) — both public APIs that need no special
/// trust. This also folds in the Dock's orientation and auto-hide/concealed
/// state for free: a vertical or currently-concealed Dock reserves ~0
/// height, which falls through to `fallbackHeight` the same as any other
/// no-reserved-strip case, no separate check needed.
enum DockTracker {
    static let fallbackHeight: CGFloat = 64

    /// Frame for a panel of `width`, left edge flush with the Dock's host
    /// screen's left edge, height matching whatever strip macOS reserves
    /// for the Dock there (or `fallbackHeight` if nothing is reserved).
    static func panelFrame(width: CGFloat, fallbackScreen: NSScreen) -> NSRect {
        let host = dockWindowHostScreen() ?? mainDisplayScreen() ?? fallbackScreen
        let reserved = host.visibleFrame.minY - host.frame.minY
        let height = reserved > 4 ? reserved : fallbackHeight
        return NSRect(x: host.frame.minX, y: host.frame.minY, width: width, height: height)
    }

    static func mainDisplayScreen() -> NSScreen? {
        screen(for: CGMainDisplayID())
    }

    private static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { self.displayID(of: $0) == displayID }
    }

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
            .uint32Value
    }

    private static func dockApplication() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.dock" }
    }

    /// Which display the Dock belongs to, from its own window's bounds --
    /// permission-free (window *list*/bounds is public; it's window
    /// *content* that needs Screen Recording) and correct even while the
    /// Dock is concealed.
    private static func dockWindowHostScreen() -> NSScreen? {
        guard let dockApp = dockApplication(), let mainScreen = mainDisplayScreen() else {
            return nil
        }
        guard
            let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID)
                as? [[String: Any]]
        else {
            return nil
        }
        let matches = windows.filter {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == dockApp.processIdentifier
                && ($0[kCGWindowLayer as String] as? Int) == 20
        }
        guard matches.count == 1,
            let boundsValue = matches[0][kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsValue)
        else {
            return nil
        }
        let appKitY = mainScreen.frame.maxY - (bounds.origin.y + bounds.height)
        let frame = NSRect(x: bounds.origin.x, y: appKitY, width: bounds.width, height: bounds.height)
        return NSScreen.screens.first { !$0.frame.intersection(frame).isNull }
    }
}
