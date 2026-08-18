# Port

[![Latest release](https://img.shields.io/github/v/release/palamim/port)](https://github.com/palamim/port/releases/latest)

A small always-on-top macOS panel, glued to the bottom-left corner of the
screen at the same height as your Dock (sibling to Starboard, which sits
bottom-right glued to the Dock itself). It shows the live state of your
Claude Code agent sessions — interactive terminals and background/fleet
jobs — in three independently-scrollable columns: **Working**, **Needs
input**, **Completed**.

v1 is read-only: display only, no clicking, no focusing terminals, no actions.

## Download

### Homebrew

```
brew tap palamim/port https://github.com/palamim/port
brew install --cask palamim/port/port
```

The tap lives in this repo, so `brew tap` needs the full URL — the short
form only works for repos named `homebrew-*`. (Port can't go in the
official `homebrew/cask` tap, which now requires notarized builds.)

Homebrew saves you the download, the `mv`, and the updates — `brew
upgrade` picks up each new release. It doesn't skip the approval steps
below, though: a `brew`-installed copy hits Gatekeeper like any other
download.

### Manual

Grab the latest build from [Releases](https://github.com/palamim/port/releases/latest), then:

```
unzip Port.zip
mv Port.app /Applications/
open /Applications/Port.app
```

Once it's in `/Applications`, it also shows up in Launchpad and Spotlight
like any other app.

### First launch

However you installed it, the build is ad-hoc signed and not notarized,
so the first launch takes a few extra clicks:

1. Opening it is blocked outright ("Port" Not Opened) — click Done.
2. System Settings → Privacy & Security → **Open Anyway** next to the
   Port entry.
3. Confirm **Open Anyway** again, then enter your password.

That's the only approval Port ever asks for — no other permission
prompt follows, on first launch or on any later update.

To have it launch automatically at login: **System Settings → General →
Login Items & Extensions → + → select Port.app**. That's it — no script
needed for either install above.

## Build & run

```
swift build
swift run
```

Run at login (packages and code-signs a `.app`, registers it as a
LaunchAgent):

```
scripts/install.sh
```

Stop / start / remove:

```
launchctl unload ~/Library/LaunchAgents/com.port.app.plist   # stop
launchctl load ~/Library/LaunchAgents/com.port.app.plist     # start
scripts/uninstall.sh                                          # remove entirely
```

## No permissions required

Port requests nothing beyond the Gatekeeper approval above — no
Accessibility, no other system permission. It sizes and positions itself
off the strip macOS reserves for the Dock and the Dock's own window
bounds, both readable with no special permission at all. See `CLAUDE.md`
for why that's enough and what it trades off against reading the Dock's
exact geometry the way Starboard does.

## Debugging

Set `PORT_DEBUG=1` in the environment to log the panel's resolved frame
and the sessions bucketed into each column to stderr on every
poll/retrack.

## Security & trust

Port makes no network requests and collects no data — it only runs
`claude agents --json --all` locally to poll agent session state and
reads the Dock's on-screen position via public, no-permission APIs.
Nothing leaves the machine.

## License

MIT — see `LICENSE`.
