import Foundation

/// Runs `claude agents --json --all` and decodes its output. Isolated from
/// `AgentPoller`'s timer/bucketing logic because the *how* of invoking the
/// CLI is a separate, fragile concern in its own right — see the two bugs
/// documented below.
enum ClaudeCLI {
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

    static func fetchSessions() -> [AgentSession]? {
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
            PortDebug.log("Process.run() failed: \(error)")
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            PortDebug.log(
                "exit \(process.terminationStatus), stderr: "
                    + (String(data: errData, encoding: .utf8) ?? "<undecodable>"))
            return nil
        }

        do {
            return try JSONDecoder().decode([AgentSession].self, from: data)
        } catch {
            PortDebug.log("decode failed: \(error)")
            PortDebug.log("raw stdout (\(data.count) bytes): \(String(data: data, encoding: .utf8) ?? "<undecodable>")")
            return nil
        }
    }
}
