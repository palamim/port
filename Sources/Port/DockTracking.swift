import ApplicationServices
import Cocoa

/// Where to put a Dock-height panel: glued to the Dock's actual on-screen
/// tray rect, or a fallback when that can't be read.
enum DockGeometry {
    /// Accessibility read succeeded and the Dock is on screen (bottom
    /// orientation, not concealed). `tray` is the icon row's tight bounding
    /// box, `host` the screen it's on.
    case glued(tray: NSRect, host: NSScreen)
    /// No Accessibility permission yet, a vertical Dock, an unreadable AX
    /// tree, or an auto-hidden Dock currently off screen. `host` is still a
    /// real screen to size the fallback against.
    case fallback(host: NSScreen)
}

/// A trimmed-down port of Starboard's Dock-tracking (`dockIconTrayFrame`,
/// `DockPresence`) for read-only sizing rather than pixel-perfect gluing
/// plus a hold/freeze state machine. Starboard needs that machine because
/// its panel can become key and sits immediately beside the Dock's icons;
/// Port's panel never becomes key (see `AppDelegate`) and sits at the
/// opposite corner, so there's nothing to freeze for and no coarse/fast
/// cadence split to earn back — this polls at a flat 1s.
enum DockTracker {
    /// Empirical corrections for the gap between the Dock's AXList
    /// bounding box and its actual painted chrome — same values Starboard
    /// uses, since it's the same AX read.
    static let dockBottomCorrection: CGFloat = 5
    static let dockTopCorrection: CGFloat = 5
    static let fallbackHeight: CGFloat = 64

    /// Resolves current Dock geometry against the given screen (used only
    /// as a last-resort fallback if nothing else can be determined).
    static func resolveGeometry(fallbackScreen: NSScreen) -> DockGeometry {
        let host = dockWindowHostScreen() ?? mainDisplayScreen() ?? fallbackScreen
        guard dockOrientation() == "bottom" else { return .fallback(host: host) }
        guard let mainScreen = mainDisplayScreen() ?? NSScreen.screens.first else {
            return .fallback(host: host)
        }
        guard let tray = dockIconTrayFrame(flippedAgainst: mainScreen) else {
            return .fallback(host: host)
        }
        guard let trayHost = screenHosting(tray) else {
            // Off screen entirely — an auto-hidden Dock currently concealed.
            return .fallback(host: host)
        }
        // Same test Starboard uses: a fully concealed tray sits at or below
        // its host's bottom edge; even the earliest partially-revealed
        // sample already clears it by several points.
        if tray.maxY <= trayHost.frame.minY + 1 {
            return .fallback(host: trayHost)
        }
        return .glued(tray: tray, host: trayHost)
    }

    /// Frame for a panel of `width`, left edge flush with the host screen's
    /// left edge — the mirror image of Starboard's right-edge-flush,
    /// glued-to-the-Dock's-tray frame.
    static func panelFrame(for geometry: DockGeometry, width: CGFloat) -> NSRect {
        switch geometry {
        case .glued(let tray, let host):
            let minY = tray.minY - dockBottomCorrection
            let maxY = tray.maxY - dockTopCorrection
            return NSRect(x: host.frame.minX, y: minY, width: width, height: maxY - minY)
        case .fallback(let host):
            // The height macOS reserves for the Dock is readable without
            // Accessibility permission at all, from the gap between the
            // screen's full frame and its visible frame — just not exact
            // pixel placement. Falls further back to a constant only when
            // there's no reserved strip either (Dock is auto-hidden and
            // currently concealed, or on a vertical edge).
            let reserved = host.visibleFrame.minY - host.frame.minY
            let height = reserved > 4 ? reserved : fallbackHeight
            return NSRect(x: host.frame.minX, y: host.frame.minY, width: width, height: height)
        }
    }

    // MARK: - Accessibility / Dock reads (ported from Starboard, trimmed)

    private static func dockApplication() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.dock" }
    }

    private static func dockOrientation() -> String {
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        return
            (CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString)
            as? String) ?? "bottom"
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

    /// The screen a rect belongs to: the one containing its center, with a
    /// greatest-overlap tiebreak. Nil when the rect touches no screen —
    /// which for a tray rect means the Dock is concealed below the edge.
    private static func screenHosting(_ rect: NSRect) -> NSScreen? {
        let centre = NSPoint(x: rect.midX, y: rect.midY)
        if let hit = NSScreen.screens.first(where: { $0.frame.contains(centre) }) { return hit }
        var best: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let overlap = screen.frame.intersection(rect)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best
    }

    /// Which display the Dock belongs to, from its own window's bounds —
    /// permission-free and correct even while the Dock is concealed, which
    /// is exactly when the tray rect can't answer the question.
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

    /// Tight bounding box of the Dock's icon tray (the `AXList` child of
    /// the Dock process), read via Accessibility. Nil if permission hasn't
    /// been granted or the AX tree can't be read.
    private static func dockIconTrayFrame(flippedAgainst mainScreen: NSScreen) -> NSRect? {
        guard let dockApp = dockApplication() else { return nil }
        let axApp = AXUIElementCreateApplication(dockApp.processIdentifier)

        var childrenRef: AnyObject?
        guard
            AXUIElementCopyAttributeValue(axApp, kAXChildrenAttribute as CFString, &childrenRef)
                == .success,
            let children = childrenRef as? [AXUIElement]
        else {
            return nil
        }
        guard let list = children.first(where: { axRole(of: $0) == (kAXListRole as String) })
        else {
            return nil
        }
        guard let position = axPoint(list, kAXPositionAttribute as CFString),
            let size = axSize(list, kAXSizeAttribute as CFString)
        else {
            return nil
        }
        // AX coordinates are Quartz's top-left-origin space, anchored to the
        // main display regardless of arrangement; flip to AppKit's
        // bottom-left-origin space, still relative to that same origin.
        let flippedY = mainScreen.frame.maxY - position.y - size.height
        return NSRect(x: position.x, y: flippedY, width: size.width, height: size.height)
    }

    private static func axRole(of element: AXUIElement) -> String? {
        var roleRef: AnyObject?
        guard
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
                == .success
        else {
            return nil
        }
        return roleRef as? String
    }

    private static func axPoint(_ element: AXUIElement, _ attribute: CFString) -> CGPoint? {
        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success,
            let axValue = valueRef
        else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func axSize(_ element: AXUIElement, _ attribute: CFString) -> CGSize? {
        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success,
            let axValue = valueRef
        else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(axValue as! AXValue, .cgSize, &size) else { return nil }
        return size
    }
}
