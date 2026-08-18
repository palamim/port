import SwiftUI

/// Three independently-scrollable columns — Working, Needs input, Completed —
/// styled after Claude Code's own terminal agent view: a status glyph plus a
/// short task description per row. Rows are single-line: the panel is
/// Dock-height (see `DockTracker`), not full-screen, so there's rarely room
/// for more than a header and a couple of rows before a column needs to
/// scroll — project/detail move into the row's tooltip instead of a second
/// line.
struct ContentView: View {
    @ObservedObject var poller: AgentPoller
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 0) {
            ColumnView(title: "Working", sessions: poller.working)
            ColumnView(title: "Needs input", sessions: poller.needsInput)
            ColumnView(title: "Completed", sessions: poller.completed)
            ThemeToggleColumn(themeManager: themeManager)
        }
        .background(Color.black.opacity(0.001))  // keeps the whole area hit-testable for scroll
    }
}
