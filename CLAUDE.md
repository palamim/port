# Port

Read-only macOS panel showing live Claude Code agent session state (see
README.md for the user-facing description). v1 scope: display only — no
clicking, no focusing terminals, no actions.

## Structure

Plain SPM executable, no third-party dependencies, no Xcode project, no
Info.plist. File-per-concern:

- `Sources/Port/main.swift` — creates `NSApplication`, sets
  `.accessory` activation policy before `app.run()` (no Dock icon, no
  Cmd+Tab entry).
- `Sources/Port/AppDelegate.swift` — builds the borderless `NSPanel`,
  hosts `ContentView` via `NSHostingView`, requests Accessibility
  permission, drives the 1s Dock-tracking timer.
- `Sources/Port/DockTracking.swift` — reads the Dock's live on-screen
  tray geometry via the Accessibility API (`AXUIElement`), same
  technique as Starboard's `dockIconTrayFrame` but trimmed of Starboard's
  hold/freeze state machine and auto-hide dual-cadence path — Port's
  panel never becomes key and isn't flush against the Dock's icons, so
  neither is needed. Anchored bottom-left (mirror of Starboard's
  bottom-right), same height as the Dock, live-tracked at a flat 1s.
  Falls back to the screen's Dock-reserved-strip height when
  Accessibility permission isn't granted.
- `Sources/Port/ContentView.swift` — SwiftUI, three scrollable columns
  (Working / Needs input / Completed), single-line rows (the panel is
  Dock-height, not full-screen — there's rarely room for more than a
  header and a couple of rows before a column needs to scroll).
- `Sources/Port/AgentSession.swift` — `Codable` model for one row of
  `claude agents --json --all`'s output, plus the Working/Needs
  input/Completed bucketing logic.
- `Sources/Port/AgentPoller.swift` — polls `claude agents --json --all`
  on a 1.5s timer, decodes, buckets, republishes as `@Published` arrays.

## The `claude agents --json --all` polling mechanism

Run via `zsh -lc "source ~/.zshrc >/dev/null 2>&1; claude agents --json --all"`,
not a direct `Process` launch of `claude`. Two real bugs shaped this exact
form — don't simplify it without re-reading both:

1. **PATH.** Port has no Dock icon and isn't launched from a shell, so its
   own `PATH` is whatever launchd/Terminal gives it, which may not include
   wherever `claude` actually lives (`~/.local/bin` on the dev machine this
   was built on). That directory is added to `PATH` from `~/.zshrc`, which
   a login-but-non-interactive shell (`-lc` alone) does not source. Hence
   the explicit `source ~/.zshrc` in the command string.

2. **Never use `-i` (interactive) to fix #1 instead.** It was tried first
   and looked correct in every background/simulated test — but an
   interactive zsh launched as a child of a process that has a *real*
   Terminal tty (e.g. `swift run` from an actual terminal) inherits that
   tty as its session's controlling terminal regardless of
   `Process.standardInput`, then blocks indefinitely trying to grab it for
   job control it's never granted (SIGTTIN/SIGTTOU). `waitUntilExit()`
   hangs forever, silently — no error, no data, indistinguishable from "not
   polling at all," and every poll leaks another stuck child process.
   Reproduced by launching the built binary under `script` (allocates a
   real pty). Explicitly sourcing `~/.zshrc` inside a plain `-lc` gets the
   same `PATH` without zsh ever entering interactive mode, so it never
   touches terminal job control.

Set `PORT_DEBUG=1` in the environment to log the resolved panel frame,
Accessibility-trust state, and bucketed session names to stderr on every
poll/retrack — added specifically because both bugs above were silent
without it.

## Data gaps handled deliberately, not silently

- `claude agents --json --all` has no completion timestamp for
  `state:"done"` jobs, only `startedAt` (job creation time) — these persist
  on disk indefinitely with no expiry. `AgentPoller` applies a rolling
  24h window on `startedAt` for the Completed column so it doesn't grow
  unbounded, the best available proxy given no finish time exists to
  filter on.
- A `state` value outside the documented `working`/`done`/`blocked` set
  (`"stopped"` has been observed, for a background job killed before
  finishing) is excluded from all three columns rather than guessed at —
  see `AgentSession.bucket`.
