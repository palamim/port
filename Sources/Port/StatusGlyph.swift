import SwiftUI

/// A bold asterisk per row, colored by bucket. A working session cycles
/// through bold asterisk → plain asterisk → dot → back to bold asterisk —
/// a little "thinking" flicker instead of a static mark, so the eye can
/// tell "in progress" apart from "waiting"/"done" at a glance without
/// reading the column header. `bucket` is nil only for undocumented states
/// this app deliberately doesn't render (see `AgentSession.bucket`), so
/// `SessionRow` never actually reaches that case in practice.
struct StatusGlyph: View {
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
