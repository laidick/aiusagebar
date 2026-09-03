import Foundation

/// Lenient ISO8601 parser. The Rust backend emits up to 9 fractional-second
/// digits, which `ISO8601DateFormatter` rejects, so we normalise to 3 first.
///
/// Formatters are created per call: `ISO8601DateFormatter` is not `Sendable`,
/// and we parse only a handful of timestamps per refresh.
public enum ISO8601 {
    public static func parse(_ raw: String) -> Date? {
        let normalised = normaliseFraction(raw)
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: normalised) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: normalised)
    }

    /// Truncates a fractional-seconds run to at most three digits.
    static func normaliseFraction(_ raw: String) -> String {
        guard let dot = raw.firstIndex(of: ".") else { return raw }
        var digits = raw.index(after: dot)
        while digits < raw.endIndex, raw[digits].isNumber {
            digits = raw.index(after: digits)
        }
        let fraction = raw[raw.index(after: dot)..<digits]
        guard fraction.count > 3 else { return raw }
        return String(raw[raw.startIndex...dot]) + fraction.prefix(3) + String(raw[digits...])
    }
}
