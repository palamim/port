import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    private let poller = AgentPoller()

    private let panelWidth: CGFloat = 300
    /// Fraction of the screen's visible height the panel occupies — "full
    /// or majority screen height" per spec; a hair short of 100% reads as
    /// intentional margin rather than a panel that's clipping.
    private let heightFraction: CGFloat = 0.96
    private let cornerRadius: CGFloat = 12
    private let panelTintColor = NSColor(calibratedRed: 0.02, green: 0.035, blue: 0.06, alpha: 0.65)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = mainDisplayScreen() ?? NSScreen.screens.first
        let frame = leftEdgeFrame(on: screen)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // No Dock to clear here (unlike Starboard, which sits beside it) —
        // `.statusBar` just needs to reliably stay above normal app
        // windows and full-screen spaces, which it does.
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.collectionBehavior = [
            .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle,
        ]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false

        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .menu
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 1
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor

        let tintView = NSView(frame: effectView.bounds)
        tintView.autoresizingMask = [.width, .height]
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = panelTintColor.cgColor
        effectView.addSubview(tintView)

        let hosting = NSHostingView(rootView: ContentView(poller: poller))
        hosting.frame = effectView.bounds
        hosting.autoresizingMask = [.width, .height]
        effectView.addSubview(hosting)

        panel.contentView = effectView
        self.panel = panel

        panel.orderFrontRegardless()
        poller.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Left screen edge, `heightFraction` of the visible height, vertically
    /// centered within it. `visibleFrame` already excludes the menu bar and
    /// (regardless of orientation) whatever strip the Dock reserves, so a
    /// left-side Dock is avoided automatically with no Dock-tracking code —
    /// unlike Starboard, this frame is computed once and stays fixed.
    private func leftEdgeFrame(on screen: NSScreen?) -> NSRect {
        guard let screen else {
            return NSRect(x: 0, y: 0, width: panelWidth, height: 600)
        }
        let visible = screen.visibleFrame
        let height = visible.height * heightFraction
        let y = visible.minY + (visible.height - height) / 2
        return NSRect(x: visible.minX, y: y, width: panelWidth, height: height)
    }

    /// The display hosting the menu bar, via `CGMainDisplayID()` rather than
    /// `NSScreen.main` (which tracks keyboard focus) — a fixed, pinned panel
    /// shouldn't jump screens as the user works across multiple displays.
    private func mainDisplayScreen() -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
                .uint32Value == CGMainDisplayID()
        }
    }

    @objc private func screenParametersChanged(_ notification: Notification) {
        let screen = mainDisplayScreen() ?? NSScreen.screens.first
        panel.setFrame(leftEdgeFrame(on: screen), display: true)
    }
}
