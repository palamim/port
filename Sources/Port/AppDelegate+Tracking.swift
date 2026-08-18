import Cocoa

extension AppDelegate {
    /// `fallbackScreen` is used only as the last-resort reference for
    /// picking a host display — `DockTracker` itself resolves the Dock's
    /// actual host independently.
    func currentFrame(on fallbackScreen: NSScreen) -> NSRect {
        DockTracker.panelFrame(width: panelWidth, fallbackScreen: fallbackScreen)
    }

    func startDockTracking() {
        let timer = Timer(timeInterval: dockTrackingInterval, repeats: true) { [weak self] _ in
            self?.retrack()
        }
        RunLoop.main.add(timer, forMode: .common)
        dockTrackingTimer = timer
    }

    func retrack() {
        let screen = DockTracker.mainDisplayScreen() ?? NSScreen.screens.first ?? panel.screen
        guard let screen else { return }
        let frame = currentFrame(on: screen)
        PortDebug.log("retrack frame=\(frame)")
        guard panel.frame != frame else { return }
        panel.setFrame(frame, display: true)
    }

    @objc func screenParametersChanged(_ notification: Notification) {
        retrack()
    }
}
