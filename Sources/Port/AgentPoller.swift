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
    /// this app has no Dock icon and isn't launched from a shell, so its
    /// own environment's `PATH` is whatever launchd gives a GUI app, which
    /// typically doesn't include `~/.local/bin` (where `claude` lives here).
    /// A login shell picks up the same `PATH` the user's own terminal
    /// would, from their `.zprofile`/`.zshrc`.
    private static let command = "claude agents --json --all"

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
    }

    private static func fetchSessions() -> [AgentSession]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        return try? JSONDecoder().decode([AgentSession].self, from: data)
    }
}
