import Foundation

/// Polls `ClaudeCLI` on a timer and republishes the result bucketed into the
/// three columns the UI renders.
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
            guard let sessions = ClaudeCLI.fetchSessions() else { return }
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
        PortDebug.log("working=\(working.map(\.name)) needsInput=\(needsInput.map(\.name)) completed=\(completed.map(\.name))")
    }
}
