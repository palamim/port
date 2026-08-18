import SwiftUI

struct ColumnView: View {
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
                // `.primary` rather than a fixed `.white` for the glow-less
                // case so the border stays visible against a light theme's
                // bright background, not just a dark one.
                .strokeBorder(glow?.opacity(0.25) ?? Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: (glow ?? .clear).opacity(glow == nil ? 0 : 0.55), radius: 5)
        .padding(.vertical, 2)
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
