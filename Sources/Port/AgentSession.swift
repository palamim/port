import Foundation

/// One row of `claude agents --json --all`'s output — an interactive
/// terminal session or a background/fleet job. Fields are a mix: some only
/// ever appear on one `kind`, so everything but the handful every row
/// carries is optional rather than split into two decodable shapes, which
/// would need its own discriminated-union boilerplate for no real benefit
/// here.
struct AgentSession: Codable, Identifiable {
    var id: String { sessionId }

    let pid: Int?
    /// Background/fleet jobs only — the job's short id. Interactive
    /// sessions have no equivalent.
    let jobId: String?
    let cwd: String
    let kind: String
    /// Epoch milliseconds.
    let startedAt: Int64
    let sessionId: String
    let name: String
    /// Interactive sessions: "idle" | "busy" | "waiting".
    let status: String?
    /// Background/fleet jobs: "working" | "done" | "blocked" | occasionally
    /// other values (e.g. "stopped" for a job killed before finishing) that
    /// the CLI doesn't document — see `bucket`.
    let state: String?
    let waitingFor: String?
    let needs: String?

    enum CodingKeys: String, CodingKey {
        case pid, cwd, kind, startedAt, sessionId, name, status, state, waitingFor, needs
        case jobId = "id"
    }

    /// Last path component of `cwd` — the project label the UI groups by.
    var projectName: String {
        (cwd as NSString).lastPathComponent
    }

    /// The one-line detail shown for a Needs Input row: `waitingFor` for an
    /// interactive session, `needs` for a fresh background job.
    var detail: String? { waitingFor ?? needs }

    enum Bucket {
        case working, needsInput, completed
    }

    /// Working/Needs-input/Completed, per the bucketing rules verified live
    /// against this CLI (see project notes): `status`/`state` are checked
    /// in that priority order because a row can carry both (a background
    /// job also reports `status` once it has a `pid`), and "still working"
    /// or "still blocked" always outranks a stale `state`.
    ///
    /// Returns nil for anything that matches none of the three documented
    /// states — e.g. `state:"stopped"`, observed on a killed-before-finish
    /// background job but never specified — rather than guessing which
    /// column an undocumented state belongs in.
    var bucket: Bucket? {
        if status == "busy" || state == "working" { return .working }
        if status == "waiting" || state == "blocked" { return .needsInput }
        if state == "done" { return .completed }
        return nil
    }
}
