import SwiftUI

/// Three independently-scrollable columns — Working, Needs input, Completed —
/// styled after Claude Code's own terminal agent view: a status glyph plus a
/// short task description per row.
struct ContentView: View {
    @ObservedObject var poller: AgentPoller

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 1) {
                ColumnView(title: "Working", tint: .working, sessions: poller.working)
                ColumnView(title: "Needs input", tint: .needsInput, sessions: poller.needsInput)
                ColumnView(title: "Completed", tint: .completed, sessions: poller.completed)
            }
        }
        .background(Color.black.opacity(0.001))  // keeps the whole area hit-testable for scroll
    }
}

private struct ColumnView: View {
    let title: String
    let tint: Color
    let sessions: [AgentSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            if sessions.isEmpty {
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(sessions) { session in
                            SessionRow(session: session)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct SessionRow: View {
    let session: AgentSession

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            StatusGlyph(bucket: session.bucket)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.name)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(session.projectName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let detail = session.detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .help("\(session.name) — \(session.projectName)\(session.detail.map { " (\($0))" } ?? "")")
    }
}

/// Green dot for completed, yellow for needs-input, an animated pulsing dot
/// while working. `bucket` is nil only for undocumented states this app
/// deliberately doesn't render (see `AgentSession.bucket`), so `SessionRow`
/// never actually reaches that case in practice.
private struct StatusGlyph: View {
    let bucket: AgentSession.Bucket?
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .scaleEffect(bucket == .working && isPulsing ? 1.5 : 1.0)
            .opacity(bucket == .working && isPulsing ? 0.4 : 1.0)
            .animation(
                bucket == .working
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default,
                value: isPulsing
            )
            .onAppear { isPulsing = true }
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
}
