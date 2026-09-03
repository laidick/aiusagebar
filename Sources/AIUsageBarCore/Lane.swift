import Foundation

public enum LaneKind: String, Sendable {
    case session
    case weekly
    case unknown
}

/// One cell of the Session / Weekly grid.
public struct Lane: Sendable, Equatable {
    public let percent: Double
    public let value: String
    public let resetAt: Date?
    public let severity: Severity
    /// How far through the reset window we are, 0...1. `nil` when unknown.
    public let elapsedFraction: Double?

    public init(
        percent: Double, value: String, resetAt: Date?, severity: Severity,
        elapsedFraction: Double? = nil
    ) {
        self.percent = percent
        self.value = value
        self.resetAt = resetAt
        self.severity = severity
        self.elapsedFraction = elapsedFraction
    }

    public init(metric: UsageMetric, elapsedFraction: Double? = nil) {
        self.percent = metric.percent
        self.value = metric.value ?? "\(Int(metric.percent.rounded()))%"
        self.resetAt = metric.resetDate
        self.severity = Severity.resolve(percent: metric.percent, backend: metric.severity)
        self.elapsedFraction = elapsedFraction
    }
}

/// A table row: either a vendor's primary row or an indented sub-row.
public struct UsageRow: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let isPrimary: Bool
    public let session: Lane?
    public let weekly: Lane?

    public init(id: String, title: String, isPrimary: Bool, session: Lane?, weekly: Lane?) {
        self.id = id
        self.title = title
        self.isPrimary = isPrimary
        self.session = session
        self.weekly = weekly
    }

    public var isEmpty: Bool {
        (session?.percent ?? 0) == 0 && (weekly?.percent ?? 0) == 0
    }

    public var severity: Severity {
        max(session?.severity ?? .low, weekly?.severity ?? .low)
    }
}

/// All rows for one vendor, plus its header metadata.
public struct VendorLanes: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let plan: String?
    public let error: String?
    public let stale: Bool
    public let rows: [UsageRow]

    public init(id: String, title: String, plan: String?, error: String?, stale: Bool, rows: [UsageRow]) {
        self.id = id
        self.title = title
        self.plan = plan
        self.error = error
        self.stale = stale
        self.rows = rows
    }

    public var severity: Severity {
        rows.map(\.severity).max() ?? .low
    }

    /// Auth-shaped failures get a "Log in" affordance.
    public var needsLogin: Bool {
        guard let error else { return false }
        let needles = ["login", "credential", "401", "unauthor", "keychain"]
        let haystack = error.lowercased()
        return needles.contains { haystack.contains($0) }
    }

    /// Missing-API-key failures get a "Set key" affordance instead.
    public var needsAPIKey: Bool {
        guard let error else { return false }
        let needles = ["api_key", "api key", "key"]
        let haystack = error.lowercased()
        return needles.contains { haystack.contains($0) }
    }
}

public struct LaneTable: Sendable, Equatable {
    public let vendors: [VendorLanes]

    public init(vendors: [VendorLanes]) {
        self.vendors = vendors
    }

    public var severity: Severity {
        vendors.map(\.severity).max() ?? .low
    }
}
