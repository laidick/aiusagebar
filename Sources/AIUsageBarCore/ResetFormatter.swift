import Foundation

/// Renders "time until reset" as a compact, monospace-friendly string.
public enum ResetFormatter {
    /// `6d 10h`, `4h 21m`, `45m`, or `now`.
    public static func string(until reset: Date, now: Date) -> String {
        let seconds = Int(reset.timeIntervalSince(now))
        return string(seconds: seconds)
    }

    public static func string(seconds total: Int) -> String {
        guard total >= 60 else { return "now" }
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
