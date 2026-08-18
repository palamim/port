# Port

A small always-on-top macOS panel, glued to the bottom-left corner of the
screen at the same height as your Dock (sibling to Starboard, which sits
bottom-right glued to the Dock itself). It shows the live state of your
Claude Code agent sessions — interactive terminals and background/fleet
jobs — in three independently-scrollable columns: **Working**, **Needs
input**, **Completed**.

v1 is read-only: display only, no clicking, no focusing terminals, no actions.

## Build & run

```
swift build
swift run
```

## Accessibility permission

Port reads the Dock's exact on-screen height/position via the Accessibility
API to size and position itself pixel-for-pixel against it, live-tracking
Dock resizes. macOS will prompt for Accessibility permission on first launch
(System Settings → Privacy & Security → Accessibility) — grant it for exact
tracking. Without it, Port still works, falling back to the height macOS
reserves for the Dock (slightly less precise, but not broken).

## Debugging

Set `PORT_DEBUG=1` in the environment to log the panel's resolved frame,
Accessibility-trust state, and the sessions bucketed into each column to
stderr on every poll/retrack.
