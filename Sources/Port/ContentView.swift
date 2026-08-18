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

    var body: some View {
        HStack(spacing: 4) {
            ColumnView(title: "Working", sessions: poller.working)
            ColumnView(title: "Needs input", sessions: poller.needsInput)
            ColumnView(title: "Completed", sessions: poller.completed)
        }
        .background(Color.black.opacity(0.001))  // keeps the whole area hit-testable for scroll
    }
}

private struct ColumnView: View {
    let title: String
    let sessions: [AgentSession]

    /// Pastel glow for a column that has something to show off — amber for
    /// a session waiting on the user, mint for one that finished. Working
    /// never glows: it's the expected steady state, not a thing to flag.
    private var glow: Color? {
        guard !sessions.isEmpty else { return nil }
        switch title {
        case "Needs input": return .needsInputGlow
        case "Completed": return .completedGlow
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.3)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)

            if sessions.isEmpty {
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sessions) { session in
                            SessionRow(session: session)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill((glow ?? .clear).opacity(glow == nil ? 0 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder((glow ?? .white).opacity(glow == nil ? 0.05 : 0.25), lineWidth: 1)
        )
        .shadow(color: (glow ?? .clear).opacity(glow == nil ? 0 : 0.55), radius: 5)
        .padding(2)
    }
}

private struct SessionRow: View {
    let session: AgentSession

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            StatusGlyph(bucket: session.bucket)
            Text(session.name)
                .font(.system(size: 10))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 2)
        .help("\(session.name) — \(session.projectName)\(session.detail.map { " (\($0))" } ?? "")")
    }
}

/// A bold asterisk per row, colored by bucket. A working session cycles
/// through bold asterisk → plain asterisk → dot → back to bold asterisk —
/// a little "thinking" flicker instead of a static mark, so the eye can
/// tell "in progress" apart from "waiting"/"done" at a glance without
/// reading the column header. `bucket` is nil only for undocumented states
/// this app deliberately doesn't render (see `AgentSession.bucket`), so
/// `SessionRow` never actually reaches that case in practice.
private struct StatusGlyph: View {
    let bucket: AgentSession.Bucket?

    private static let frameInterval: TimeInterval = 0.5

    var body: some View {
        Group {
            if bucket == .working {
                TimelineView(.periodic(from: .now, by: Self.frameInterval)) { context in
                    let phase =
                        Int(context.date.timeIntervalSinceReferenceDate / Self.frameInterval) % 3
                    glyph(phase: phase)
                }
            } else {
                glyph(phase: 0)
            }
        }
    }

    private func glyph(phase: Int) -> some View {
        Text(symbol(phase: phase))
            .font(.system(size: 11, weight: weight(phase: phase), design: .rounded))
            .foregroundColor(color)
            .frame(width: 8, alignment: .center)
    }

    /// Phase 0: bold `*`. Phase 1: regular-weight `*`. Phase 2: `.` — then
    /// back to phase 0.
    private func symbol(phase: Int) -> String {
        guard bucket == .working else { return "*" }
        return phase == 2 ? "." : "*"
    }

    private func weight(phase: Int) -> Font.Weight {
        guard bucket == .working else { return .bold }
        return phase == 0 ? .bold : .regular
    }

    private var color: Color {
        switch bucket {
        case .working: return .working
        case .needsInput: return .needsInput
        case .completed: return .completed
        case nil: return .secondary
        }
    }
}

extension Color {
    static let working = Color(red: 0.35, green: 0.68, blue: 0.98)
    static let needsInput = Color(red: 0.95, green: 0.75, blue: 0.25)
    static let completed = Color(red: 0.35, green: 0.78, blue: 0.45)

    /// Softer, lower-saturation variants used only for the column glow —
    /// the dot colors above read fine at 6pt but are too saturated for a
    /// background wash across a whole column.
    static let needsInputGlow = Color(red: 1.0, green: 0.91, blue: 0.62)
    static let completedGlow = Color(red: 0.68, green: 0.94, blue: 0.76)
}
