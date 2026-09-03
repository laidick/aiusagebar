import Foundation

/// Usage pressure level for a single lane or for the app as a whole.
public enum Severity: String, Sendable, CaseIterable, Comparable {
    case low
    case mid
    case high
    case critical

    public var rank: Int {
        switch self {
        case .low: return 0
        case .mid: return 1
        case .high: return 2
        case .critical: return 3
        }
    }

    public static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rank < rhs.rank }

    /// Thresholds used when the backend does not supply a severity.
    public static func forPercent(_ percent: Double) -> Severity {
        if percent >= 90 { return .critical }
        if percent >= 75 { return .high }
        if percent >= 50 { return .mid }
        return .low
    }

    /// Backend severity is trusted, but never allowed to under-report the percentage.
    public static func resolve(percent: Double, backend: String?) -> Severity {
        let computed = forPercent(percent)
        guard let raw = backend?.lowercased(), let reported = Severity(rawValue: raw) else {
            return computed
        }
        return max(computed, reported)
    }
}
