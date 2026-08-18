import Cocoa
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    private let poller = AgentPoller()
    private let themeManager = ThemeManager()
    private var themeSubscription: AnyCancellable?
    private var dockTrackingTimer: Timer!

    /// Kept so `applyTheme` can restyle them after the initial build —
    /// `NSVisualEffectView.appearance`/its sublayers aren't reachable any
    /// other way once `applicationDidFinishLaunching` returns.
    private var effectView: NSVisualEffectView!
    private var tintView: NSView!

    private let panelWidth: CGFloat = 360
    private let cornerRadius: CGFloat = 12
    /// Same cadence Starboard settled on for its own once-a-second full
    /// evaluation. Starboard also runs a 60ms fast path while the Dock is
    /// auto-hiding, to catch a reveal within ~100ms instead of up to 1s;
    /// skipped here — Port's panel never becomes key and isn't glued flush
    /// against the Dock's icons, so shaving reveal latency down doesn't earn
    /// back the extra always-on polling the way it does for a panel someone
    /// is actively about to type into.
    private let dockTrackingInterval: TimeInterval = 1.0

    /// Mirrors `AgentPoller`'s `PORT_DEBUG` gate — set it and run via
    /// `swift run` (or Console.app for a Login-Items launch) to see the
    /// panel's frame on every retrack.
    private static let debugEnabled = ProcessInfo.processInfo.environment["PORT_DEBUG"] == "1"

    private static func debugLog(_ message: @autoclosure () -> String) {
        guard debugEnabled else { return }
        FileHandle.standardError.write("[port.debug] \(message())\n".data(using: .utf8)!)
    }

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
        Self.debugLog("initialFrame=\(initialFrame) isVisible=\(panel.isVisible)")
        poller.start()
        startDockTracking()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Restyles the Cocoa-level chrome (tint, forced appearance, border) for
    /// `theme`. The SwiftUI side (`ContentView`'s `.primary`/`.secondary`
    /// colors and the toggle itself) updates on its own from the same
    /// `ThemeManager` via `@ObservedObject` — this only covers what SwiftUI
    /// can't reach: the `NSVisualEffectView` and its tint overlay.
    private func applyTheme(_ theme: PanelTheme) {
        tintView.layer?.backgroundColor = theme.panelTint.cgColor
        effectView.layer?.borderColor = theme.borderColor.cgColor
        effectView.appearance = theme.appearance
    }

    /// `fallbackScreen` is used only as the last-resort reference for
    /// picking a host display — `DockTracker` itself resolves the Dock's
    /// actual host independently.
    private func currentFrame(on fallbackScreen: NSScreen) -> NSRect {
        DockTracker.panelFrame(width: panelWidth, fallbackScreen: fallbackScreen)
    }

    private func startDockTracking() {
        let timer = Timer(timeInterval: dockTrackingInterval, repeats: true) { [weak self] _ in
            self?.retrack()
        }
        RunLoop.main.add(timer, forMode: .common)
        dockTrackingTimer = timer
    }

    private func retrack() {
        let screen = DockTracker.mainDisplayScreen() ?? NSScreen.screens.first ?? panel.screen
        guard let screen else { return }
        let frame = currentFrame(on: screen)
        Self.debugLog("retrack frame=\(frame)")
        guard panel.frame != frame else { return }
        panel.setFrame(frame, display: true)
    }

    @objc private func screenParametersChanged(_ notification: Notification) {
        retrack()
    }
}
