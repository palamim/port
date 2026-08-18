import Foundation

/// Shared `PORT_DEBUG` gate — set it and run via `swift run` (or Console.app
/// for a Login-Items launch) to see per-poll/retrack diagnostics on stderr.
/// A free enum rather than an `AppDelegate`-scoped extension (Starboard's
/// pattern) because two independent types need it here: `AppDelegate` for
/// panel frames, `AgentPoller`/`ClaudeCLI` for the poll/decode path.
enum PortDebug {
    static let enabled = ProcessInfo.processInfo.environment["PORT_DEBUG"] == "1"

    static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        FileHandle.standardError.write("[port.debug] \(message())\n".data(using: .utf8)!)
    }
}
