import SwiftUI

/// Port's pixel-art mascot. Same species as agent-patterns' `mascot.tsx`
/// (and Starboard's AppKit port of it, `MascotView.swift`) — same 16x13
/// grid, same walk/blink/look mechanics — but not a copy: recolored yellow,
/// a bent antenna instead of a straight stem, a default gaze to the
/// bottom-left instead of bottom-right, a vent/mouth slit neither original
/// has, and a pixel-wider leg stance. Colors are deliberately hardcoded,
/// not var(--token)-style theme colors: the mascot is a fixed-identity
/// character, not a themed diagram — it should look identical in light and
/// dark mode rather than inverting with the panel.
struct Mascot: View {
    enum Look: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        var offset: (CGFloat, CGFloat) {
            switch self {
            case .topLeft: return (0, 0)
            case .topRight: return (1, 0)
            case .bottomLeft: return (0, 1)
            case .bottomRight: return (1, 1)
            }
        }
    }

    /// Static frame (no leg cycle, no blink/look scheduling) — used to
    /// render the source art for the app icon, where a single frozen frame
    /// is wanted, not a live-animating view.
    var animated: Bool = true

    private static let body = Color(red: 0xf5 / 255, green: 0xb7 / 255, blue: 0x00 / 255)
    private static let eyeWhite = Color(red: 0xf8 / 255, green: 0xf3 / 255, blue: 0xe8 / 255)
    private static let pupil = Color(red: 0x18 / 255, green: 0x14 / 255, blue: 0x0f / 255)

    private static let gridWidth: CGFloat = 16
    private static let gridHeight: CGFloat = 13
    static let aspectRatio: CGFloat = gridWidth / gridHeight

    private static let legInterval: TimeInterval = 0.34

    @State private var blinking = false
    @State private var look: Look = .bottomLeft
    @State private var blinkTask: Task<Void, Never>?
    @State private var lookTask: Task<Void, Never>?

    var body: some View {
        Group {
            if animated {
                TimelineView(.periodic(from: .now, by: Self.legInterval)) { context in
                    let tick = Int(context.date.timeIntervalSinceReferenceDate / Self.legInterval)
                    frame(legFrameA: tick % 2 == 0)
                }
                .onAppear {
                    scheduleBlink()
                    scheduleLook()
                }
                .onDisappear {
                    blinkTask?.cancel()
                    lookTask?.cancel()
                }
            } else {
                frame(legFrameA: true)
            }
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
    }

    private func frame(legFrameA: Bool) -> some View {
        Canvas { context, size in
            draw(in: &context, size: size, legFrameA: legFrameA)
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, legFrameA: Bool) {
        let unit = size.width / Self.gridWidth

        func fill(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
            let rect = CGRect(x: x * unit, y: y * unit, width: w * unit, height: h * unit)
            context.fill(Path(rect), with: .color(color))
        }

        // bent antenna
        fill(8, 0, 1, 1, Self.body)
        fill(7, 1, 1, 1, Self.body)

        // head / body
        fill(5, 2, 6, 1, Self.body)
        fill(3, 3, 10, 1, Self.body)
        fill(2, 4, 12, 5, Self.body)
        fill(3, 9, 10, 1, Self.body)

        // eyes
        if blinking {
            fill(5, 6, 2, 1, Self.pupil)
            fill(9, 6, 2, 1, Self.pupil)
        } else {
            fill(5, 5, 2, 2, Self.eyeWhite)
            fill(9, 5, 2, 2, Self.eyeWhite)
            let (lookX, lookY) = look.offset
            fill(5 + lookX, 5 + lookY, 1, 1, Self.pupil)
            fill(9 + lookX, 5 + lookY, 1, 1, Self.pupil)
        }

        // vent / mouth slit
        fill(7, 7, 2, 1, Self.pupil)

        // legs — alternate height to fake a walk cycle, stance a pixel
        // wider on each side than agent-patterns'/Starboard's
        let leftLeg: CGFloat = legFrameA ? 2 : 1
        let rightLeg: CGFloat = legFrameA ? 1 : 2
        fill(4, 10, 2, leftLeg, Self.body)
        fill(10, 10, 2, rightLeg, Self.body)
    }

    private func scheduleBlink() {
        blinkTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4.2 + Double.random(in: 0...2.0)))
                guard !Task.isCancelled else { return }
                blinking = true
                try? await Task.sleep(for: .seconds(0.15))
                guard !Task.isCancelled else { return }
                blinking = false
            }
        }
    }

    private func scheduleLook() {
        lookTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5 + Double.random(in: 0...3.5)))
                guard !Task.isCancelled else { return }
                let options = Look.allCases.filter { $0 != look }
                look = options.randomElement() ?? look
            }
        }
    }
}
