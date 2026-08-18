import Foundation

/// Polls `claude agents --json --all` on a timer and republishes the result
/// bucketed into the three columns the UI renders.
final class AgentPoller: ObservableObject {
    @Published private(set) var working: [AgentSession] = []
    @Published private(set) var needsInput: [AgentSession] = []
    @Published private(set) var completed: [AgentSession] = []

    private var timer: Timer?
    private let pollInterval: TimeInterval = 1.5

    /// `state:"done"` background jobs persist on disk indefinitely — the
    /// CLI has no expiry and no completion timestamp, only `startedAt`
    /// (when the job was *created*). So this can't be "hide jobs that
    /// finished before Port launched" (no finish time to test) or "hide
    /// jobs created before Port launched" (would hide already-done jobs at
    /// every fresh launch, including the ones this view exists to show).
    /// A rolling window on `startedAt` is the simplest thing that (a) keeps
    /// Completed from growing forever and (b) still shows recent history
    /// immediately on launch.
    private let completedRetentionWindow: TimeInterval = 24 * 60 * 60

    /// Runs via `/bin/zsh -ilc`, not a direct `Process` launch of `claude`:
    /// this app has no Dock icon and isn't launched from a shell, so its own
    /// `PATH` is whatever launchd gives a GUI app, which doesn't include
    /// `~/.local/bin` (where `claude` lives on this machine). `-l` (login)
    /// alone isn't enough to fix that — `~/.local/bin` is added to `PATH`
    /// from `~/.zshrc`, which is only sourced by an *interactive* shell, and
    /// `-c` on its own is non-interactive even combined with `-l`. Verified
    /// empirically: `zsh -lc "which claude"` fails against a GUI-launched
    /// process's stripped-down environment, `zsh -ilc "which claude"`
    /// succeeds. `-i` also means an interactive shell's stray stdout (job
    /// control notices etc.) could in principle land on the pipe, but none
    /// has been observed in practice, and `claude`'s JSON is still the last
    /// thing written, so a decode failure here would be visible rather than
    /// silently corrupt.
    private static let command = "claude agents --json --all"

    /// Gate for diagnosing the Process/decode path — set `PORT_DEBUG=1` in
    /// the environment and run via `swift run` (or Console.app for a
    /// Login-Items launch) to see it. Mirrors Starboard's `STARBOARD_DEBUG`.
    private static let debugEnabled = ProcessInfo.processInfo.environment["PORT_DEBUG"] == "1"

    private static func debugLog(_ message: @autoclosure () -> String) {
        guard debugEnabled else { return }
        FileHandle.standardError.write("[port.debug] \(message())\n".data(using: .utf8)!)
    }

    func start() {
        poll()
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let sessions = Self.fetchSessions() else { return }
            DispatchQueue.main.async {
                self?.apply(sessions)
            }
        }
    }

    private func apply(_ sessions: [AgentSession]) {
        let cutoff = Date().addingTimeInterval(-completedRetentionWindow)
        var working: [AgentSession] = []
        var needsInput: [AgentSession] = []
        var completed: [AgentSession] = []

        for session in sessions {
            switch session.bucket {
            case .working:
                working.append(session)
            case .needsInput:
                needsInput.append(session)
            case .completed:
                let startedAt = Date(timeIntervalSince1970: Double(session.startedAt) / 1000)
                if startedAt >= cutoff { completed.append(session) }
            case nil:
                break
            }
        }

        self.working = working
        self.needsInput = needsInput
        self.completed = completed
        Self.debugLog("working=\(working.map(\.name)) needsInput=\(needsInput.map(\.name)) completed=\(completed.map(\.name))")
    }

    private static func fetchSessions() -> [AgentSession]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-ilc", command]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            debugLog("Process.run() failed: \(error)")
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            debugLog(
                "exit \(process.terminationStatus), stderr: "
                    + (String(data: errData, encoding: .utf8) ?? "<undecodable>"))
            return nil
        }

        do {
            return try JSONDecoder().decode([AgentSession].self, from: data)
        } catch {
            debugLog("decode failed: \(error)")
            debugLog("raw stdout (\(data.count) bytes): \(String(data: data, encoding: .utf8) ?? "<undecodable>")")
            return nil
        }
    }
}
