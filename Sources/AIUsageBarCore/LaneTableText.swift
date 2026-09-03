import Foundation

/// Plain-text rendering of the lane table, used by the `--dump` CLI flag.
public enum LaneTableText {
    public static func render(_ table: LaneTable, now: Date = Date()) -> String {
        var lines: [String] = []
        lines.append(pad("VENDOR", 22) + pad("PLAN", 16) + pad("SESSION", 26) + "WEEKLY")
        lines.append(String(repeating: "-", count: 88))
        for vendor in table.vendors {
            for row in vendor.rows {
                let name = row.isPrimary ? row.title : "  " + row.title
                let plan = row.isPrimary ? (vendor.plan ?? "-") : ""
                lines.append(pad(name, 22) + pad(plan, 16) + pad(cell(row.session, now), 26) + cell(row.weekly, now))
            }
            if let error = vendor.error, !error.isEmpty {
                lines.append("  ! " + error)
            }
            if vendor.stale { lines.append("  (stale)") }
        }
        lines.append("")
        lines.append("overall severity: \(table.severity.rawValue)")
        return lines.joined(separator: "\n")
    }

    private static func cell(_ lane: Lane?, _ now: Date) -> String {
        guard let lane else { return "-" }
        var text = lane.value
        if let reset = lane.resetAt {
            text += " (\(ResetFormatter.string(until: reset, now: now)))"
        }
        if let pace = lane.elapsedFraction {
            text += " ▏pace \(Int((pace * 100).rounded()))%"
        }
        return text
    }

    private static func pad(_ s: String, _ width: Int) -> String {
        s.count >= width ? s + " " : s + String(repeating: " ", count: width - s.count)
    }
}
