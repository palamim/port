import Cocoa
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    let poller = AgentPoller()
    let themeManager = ThemeManager()
    var themeSubscription: AnyCancellable?
    var dockTrackingTimer: Timer!

    /// Kept so `applyTheme` can restyle them after the initial build —
    /// `NSVisualEffectView.appearance`/its sublayers aren't reachable any
    /// other way once `applicationDidFinishLaunching` returns.
    var effectView: NSVisualEffectView!
    var tintView: NSView!

    let panelWidth: CGFloat = 360
    let cornerRadius: CGFloat = 12
    /// Same cadence Starboard settled on for its own once-a-second full
    /// evaluation. Starboard also runs a 60ms fast path while the Dock is
    /// auto-hiding, to catch a reveal within ~100ms instead of up to 1s;
    /// skipped here — Port's panel never becomes key and isn't glued flush
    /// against the Dock's icons, so shaving reveal latency down doesn't earn
    /// back the extra always-on polling the way it does for a panel someone
    /// is actively about to type into.
    let dockTrackingInterval: TimeInterval = 1.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        let initialScreen = DockTracker.mainDisplayScreen() ?? NSScreen.screens.first
        let initialFrame =
            initialScreen.map { currentFrame(on: $0) }
            ?? NSRect(x: 0, y: 0, width: panelWidth, height: DockTracker.fallbackHeight)

        let panel = NSPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // No Dock to clear on this side of the screen (unlike Starboard,
        // which sits immediately beside the Dock's own icons) — `.statusBar`
        // just needs to reliably stay above normal app windows and
        // full-screen spaces, which it does.
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

        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: initialFrame.size))
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .menu
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 1
        self.effectView = effectView

        let tintView = NSView(frame: effectView.bounds)
        tintView.autoresizingMask = [.width, .height]
        tintView.wantsLayer = true
        effectView.addSubview(tintView)
        self.tintView = tintView

        let hosting = NSHostingView(rootView: ContentView(poller: poller, themeManager: themeManager))
        hosting.frame = effectView.bounds
        hosting.autoresizingMask = [.width, .height]
        effectView.addSubview(hosting)

        panel.contentView = effectView
        self.panel = panel

        // `@Published`'s sink fires immediately with the current value, so
        // this alone also does the initial styling — no separate call needed.
        themeSubscription = themeManager.$theme.sink { [weak self] theme in
            self?.applyTheme(theme)
        }

        panel.orderFrontRegardless()
        PortDebug.log("initialFrame=\(initialFrame) isVisible=\(panel.isVisible)")
        poller.start()
        startDockTracking()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
}
