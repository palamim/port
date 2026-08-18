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
  hosts `ContentView` via `NSHostingView`, drives the 1s Dock-tracking
  timer.
- `Sources/Port/DockTracking.swift` — sizes the panel off the strip
  macOS reserves for the Dock (`NSScreen.visibleFrame`) and which screen
  hosts the Dock (from the Dock's own window bounds via
  `CGWindowListCopyWindowInfo`) — both public, no-permission APIs.
  Deliberately does *not* read the Dock's exact icon-tray rect the way
  Starboard's `dockIconTrayFrame` does (which needs Accessibility
  permission): that rect only matters for a panel sitting flush against
  the Dock's icons, which Port, anchored bottom-left (mirror of
  Starboard's bottom-right) at a fixed width, never is — see "No
  Accessibility permission" below. Live-tracked at a flat 1s.
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

Set `PORT_DEBUG=1` in the environment to log the resolved panel frame and
bucketed session names to stderr on every poll/retrack — added
specifically because both bugs above were silent without it.

## No Accessibility permission

Port requests no permissions at all — confirmed by removing the one
Accessibility read it used to make (`DockTracker.dockIconTrayFrame`, an
`AXUIElement` read of the Dock's icon-tray rect) and finding nothing else
depended on it. That rect was only ever used for two things, both
now gone from `DockTracking.swift`:

- A ±5pt correction on top of the Dock's reserved-strip height
  (`dockTopCorrection`/`dockBottomCorrection`), compensating for the
  AXList bounding box overshooting the Dock's actual painted chrome.
  `NSScreen.visibleFrame`'s reserved strip (still used, permission-free)
  is within that same margin of the true value on its own.
- Nothing else — Port never used the tray rect's *x*/width the way
  Starboard's `gluedFrame` does (`x = host.frame.maxX - width`, derived
  from `tray.maxX`, to sit flush against the Dock's icons without
  overlapping them). Port's panel width and x-position
  (`host.frame.minX`) are constants unrelated to the Dock's icon layout
  in both the old AX-read path and the current permission-free one, so
  removing the AX path changed nothing about horizontal placement.

Net effect of dropping it: Port never shows a permission prompt, at the
cost of the panel's height sometimes landing a few pixels off the Dock's
exact painted edge instead of matching it pixel-for-pixel — acceptable
for a v1 that's explicitly display-only. This is a real difference from
Starboard, where the equivalent AX read is load-bearing (needed for
horizontal layout, not just refinement) and can't be dropped the same
way — see Starboard's own `CLAUDE.md`.

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

## Distribution

Started as a close mirror of Starboard's setup (sibling project, same
author), but diverges on signing: Starboard's `install.sh` needs a
local, self-signed certificate to give its `launchd`-launched instance a
stable TCC identity for Accessibility permission across rebuilds (ad-hoc
signing pins trust to the binary's content hash, which changes every
rebuild). Port requests no permission at all (see "No Accessibility
permission" above), so that entire certificate dance has nothing to
stabilize — `scripts/install.sh` ad-hoc signs, same as `scripts/
package.sh`, and there's no equivalent of Starboard's `tccutil reset`
step anywhere in Port's scripts or cask. Other differences from
Starboard: no third-party dependency (`scripts/package.sh` still does
two single-arch `swift build` + `lipo` rather than one multi-arch
invocation, purely because `--arch arm64 --arch x86_64` together hands
the universal-binary step to xcbuild, which needs a full Xcode install —
run concurrently, not sequentially, since the two builds share no
state), and no app icon yet — `package.sh`/`install.sh` both skip
`CFBundleIconFile` and the icon copy when `assets/AppIcon.icns` doesn't
exist, so packaging doesn't fail without one.

- `scripts/_bundle.sh` — sourced (not run directly) by both `package.sh`
  and `install.sh`: writes the icon (if present) and `Info.plist` for a
  `Port.app` bundle, so the two build paths can't drift into producing
  different bundle metadata the way they once did.
- `scripts/package.sh` — builds the universal release `.app`, ad-hoc signs
  it (`codesign --sign -`), zips it with `ditto` (preserves the signature's
  extended attributes; plain `zip` can drop them). What `.github/workflows/
  release.yml` runs on a `v*.*.*` tag push, and what a manual/Homebrew
  download runs too. Builds into `.build/release-dist/`, never
  `.build/release/` — that path is also where `install.sh`'s LaunchAgent
  points, so running `package.sh` against it would clobber whatever
  `install.sh` last built there.
- `scripts/install.sh` — for build-from-source use: packages a `.app` at
  `.build/release/Port.app`, ad-hoc signs it, and registers it as a
  `~/Library/LaunchAgents/com.port.app.plist` LaunchAgent.
- `Casks/port.rb` makes this repo a self-hosted Homebrew tap (`brew tap
  palamim/port https://github.com/palamim/port`) rather than a submission
  to the official `homebrew/cask` repo, which now requires notarized
  casks — Port is ad-hoc signed only. `.github/workflows/release.yml`
  rewrites the cask's `version`/`sha256` and pushes straight to `main` on
  every release tag, computing the checksum from the `Port.zip` already
  sitting in the runner's workspace (not the GitHub Releases API, whose
  asset digests aren't guaranteed ready yet) and skipping the commit
  entirely if the cask is already at that version. `checkout` uses
  `fetch-depth: 0` in that job specifically because a tag build's default
  shallow clone doesn't have `main`'s history to push onto.
