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

    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(Color.severity(lane?.severity ?? .low))
                    .frame(width: max(fill * geo.size.width, lane == nil ? 0 : 2))
            }
        }
        .frame(height: 5)
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
