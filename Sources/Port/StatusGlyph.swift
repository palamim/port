import SwiftUI

/// A bold asterisk per row, colored by bucket. A working session cycles
/// through dot → asterisk → bold asterisk → asterisk → back to dot — a
/// "breathing" flicker (small → big → small) instead of a static mark, so
/// the eye can tell "in progress" apart from "waiting"/"done" at a glance
/// without reading the column header. `bucket` is nil only for
/// undocumented states this app deliberately doesn't render (see
/// `AgentSession.bucket`), so `SessionRow` never actually reaches that case
/// in practice.
struct StatusGlyph: View {
    let bucket: AgentSession.Bucket?

    private static let frameInterval: TimeInterval = 0.5

    var body: some View {
        Group {
            if bucket == .working {
                TimelineView(.periodic(from: .now, by: Self.frameInterval)) { context in
                    let phase =
                        Int(context.date.timeIntervalSinceReferenceDate / Self.frameInterval) % 4
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
            .offset(y: verticalOffset(phase: phase))
    }

    /// Phase 0: `.`. Phases 1 and 3: regular-weight `*`. Phase 2: bold
    /// `*` — the peak of the breath — then back to phase 0.
    private func symbol(phase: Int) -> String {
        guard bucket == .working else { return "*" }
        return phase == 0 ? "." : "*"
    }

    private func weight(phase: Int) -> Font.Weight {
        guard bucket == .working else { return .bold }
        return phase == 2 ? .bold : .regular
    }

    /// Neither symbol's ink sits at the row's visual center by default:
    /// `*` renders up near cap height (level with a `t`'s crossbar, per
    /// pixel measurements against the row's own text), and `.` sits even
    /// lower, hugging the baseline. Centering the *frame* doesn't fix
    /// either — both need their ink nudged onto the x-height center that
    /// the adjacent row text reads as "the middle of the line".
    private func verticalOffset(phase: Int) -> CGFloat {
        symbol(phase: phase) == "." ? -2.5 : 2.75
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
