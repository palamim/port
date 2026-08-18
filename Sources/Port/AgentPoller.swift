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

    /// Runs via `/bin/zsh -lc`, not a direct `Process` launch of `claude`:
    /// this app has no Dock icon and isn't launched from a shell, so its own
    /// `PATH` is whatever launchd gives a GUI app, which doesn't include
    /// `~/.local/bin` (where `claude` lives on this machine). `-l` (login)
    /// alone isn't enough — `~/.local/bin` is added to `PATH` from
    /// `~/.zshrc`, which a login-but-non-interactive shell doesn't source.
    ///
    /// The fix is *not* `-i` (interactive), even though that also sources
    /// `~/.zshrc` and was tried first: an interactive zsh, launched as a
    /// child of a real Terminal-backed process (e.g. `swift run` from an
    /// actual terminal — as opposed to any launch context used to test this
    /// that had no controlling tty at all), inherits that tty as its session
    /// controlling terminal regardless of what `Process.standardInput` is
    /// set to, and then blocks indefinitely trying to grab it for job
    /// control it's never granted (SIGTTIN/SIGTTOU) — `waitUntilExit()`
    /// below hangs forever, with zero output on any path, indistinguishable
    /// from "never polled at all". Reproduced directly: launching this
    /// binary under `script` (which allocates a real pty, mimicking a
    /// Terminal launch) left a pile of never-exiting `zsh -ilc` children.
    /// Explicitly sourcing `~/.zshrc` inside a plain non-interactive `-lc`
    /// gets the same `PATH` without zsh ever entering interactive mode, so
    /// it never attempts terminal job control at all. Verified the same way
    /// (under `script`): completes immediately, no leftover processes.
    private static let command = "source ~/.zshrc >/dev/null 2>&1; claude agents --json --all"

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
        process.arguments = ["-lc", command]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        // `Process` defaults `standardInput` to nil, i.e. "inherit the
        // current process's stdin" — for a binary launched from a real
        // Terminal, that's Terminal's own tty. Not needed for correctness
        // now that the shell stays non-interactive (see `command`), but
        // there's no reason for this child to ever touch a real terminal
        // either, so it stays explicitly detached.
        process.standardInput = FileHandle.nullDevice

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
