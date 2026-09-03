import SwiftUI
import AIUsageBarCore

/// One Session/Weekly cell: capsule bar, bold percentage, reset countdown.
struct LaneCell: View {
    let lane: Lane?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                bar
                Text(lane?.value ?? "—")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(lane == nil ? Color.secondary : Color.primary)
                    .frame(width: 32, alignment: .trailing)
            }
            Text(resetText)
                .font(.system(size: 9))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private static let barHeight: Double = 5
    private static let tickWidth: Double = 2
    private static let tickHeight: Double = barHeight * 1.6

    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(Color.severity(lane?.severity ?? .low))
                    .frame(width: max(fill * geo.size.width, lane == nil ? 0 : 2))
                if let pace = lane?.elapsedFraction {
                    paceTick(in: geo.size.width, at: pace)
                }
            }
        }
        .frame(height: Self.barHeight)
    }

    /// Thin red tick showing where usage would be if spent evenly over the window.
    private func paceTick(in width: Double, at fraction: Double) -> some View {
        let w = Self.tickWidth
        let centre = min(max(fraction, 0), 1) * width
        let x = min(max(centre - w / 2, 0), max(width - w, 0))
        return Capsule()
            .fill(Color(Palette.danger))
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.35), lineWidth: 0.5))
            .frame(width: w, height: Self.tickHeight)
            .offset(x: x)
    }

    private var fill: Double {
        guard let lane else { return 0 }
        return min(max(lane.percent / 100, 0), 1)
    }

    private var resetText: String {
        guard let reset = lane?.resetAt else { return " " }
        return "↻ " + ResetFormatter.string(until: reset, now: now)
    }
}
