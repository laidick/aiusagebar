import Foundation

/// Decodable mirror of `ai-usagebar usage --json`.
public struct UsageSnapshot: Decodable, Sendable, Equatable {
    public let entries: [VendorEntry]

    public init(entries: [VendorEntry]) {
        self.entries = entries
    }

    public static func decode(_ data: Data) throws -> UsageSnapshot {
        try JSONDecoder().decode(UsageSnapshot.self, from: data)
    }
}

public struct VendorEntry: Decodable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let displayName: String
    public let shortName: String
    public let plan: String?
    public let status: String?
    public let error: String?
    public let stale: Bool
    public let fetchedAt: String?
    public let metrics: [UsageMetric]

    enum CodingKeys: String, CodingKey {
        case id, name, plan, status, error, stale, metrics
        case displayName = "display_name"
        case shortName = "short_name"
        case fetchedAt = "fetched_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? id
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? name
        shortName = try c.decodeIfPresent(String.self, forKey: .shortName) ?? ""
        plan = try c.decodeIfPresent(String.self, forKey: .plan)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        stale = try c.decodeIfPresent(Bool.self, forKey: .stale) ?? false
        fetchedAt = try c.decodeIfPresent(String.self, forKey: .fetchedAt)
        metrics = try c.decodeIfPresent([UsageMetric].self, forKey: .metrics) ?? []
    }

    public init(
        id: String, name: String, displayName: String, shortName: String,
        plan: String?, status: String?, error: String?, stale: Bool,
        fetchedAt: String?, metrics: [UsageMetric]
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.shortName = shortName
        self.plan = plan
        self.status = status
        self.error = error
        self.stale = stale
        self.fetchedAt = fetchedAt
        self.metrics = metrics
    }

    public var fetchedDate: Date? { fetchedAt.flatMap(ISO8601.parse) }
}

public struct UsageMetric: Decodable, Sendable, Equatable {
    public let label: String
    public let percent: Double
    public let value: String?
    public let detail: String?
    public let resetAt: String?
    public let severity: String?

    enum CodingKeys: String, CodingKey {
        case label, percent, value, detail, severity
        case resetAt = "reset_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        percent = try c.decodeIfPresent(Double.self, forKey: .percent) ?? 0
        value = try c.decodeIfPresent(String.self, forKey: .value)
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
        resetAt = try c.decodeIfPresent(String.self, forKey: .resetAt)
        severity = try c.decodeIfPresent(String.self, forKey: .severity)
    }

    public init(
        label: String, percent: Double, value: String? = nil,
        detail: String? = nil, resetAt: String? = nil, severity: String? = nil
    ) {
        self.label = label
        self.percent = percent
        self.value = value
        self.detail = detail
        self.resetAt = resetAt
        self.severity = severity
    }

    public var resetDate: Date? { resetAt.flatMap(ISO8601.parse) }
}
