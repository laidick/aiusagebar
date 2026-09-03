// NOTE: this file must NOT `import Testing`. Command Line Tools ships the
// `Testing` framework but not the `_Testing_Foundation` cross-import overlay's
// swiftmodule, so `import Testing` and `import Foundation` in the same file
// fail to build. All Foundation use is confined here.
import Foundation
@testable import AIUsageBarCore

enum Fixture {
    static func snapshot(file: StaticString = #filePath) throws -> UsageSnapshot {
        let root = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent() // AIUsageBarCoreTests
            .deletingLastPathComponent() // Tests
        let url = root.appendingPathComponent("Fixtures/usage.json")
        return try UsageSnapshot.decode(Data(contentsOf: url))
    }

    static func date(_ iso: String) -> Date {
        guard let date = ISO8601.parse(iso) else {
            fatalError("fixture: unparseable date \(iso)")
        }
        return date
    }
}

/// Metrics built relative to a fixed `now`, for pace-marker tests.
enum Synthetic {
    static let now = Fixture.date("2026-09-03T00:00:00Z")

    /// A metric with no `detail`, resetting `seconds` after `now`.
    static func metric(label: String, resetInSeconds seconds: Double) -> UsageMetric {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return UsageMetric(
            label: label, percent: 0, value: "0%",
            resetAt: formatter.string(from: now.addingTimeInterval(seconds)), severity: "low"
        )
    }

    static func bare(label: String) -> UsageMetric {
        UsageMetric(label: label, percent: 0, value: "0%")
    }
}

/// The `opencode-go` backend's shape: Rolling / Weekly / Monthly.
enum OpenCodeGo {
    static func entry(rolling: Double, weekly: Double, monthly: Double) -> VendorEntry {
        VendorEntry(
            id: "opencode-go", name: "opencode-go", displayName: "OpenCode Go",
            shortName: "ocg", plan: nil, status: nil, error: nil, stale: false,
            fetchedAt: nil,
            metrics: [
                UsageMetric(label: "Rolling", percent: rolling),
                UsageMetric(label: "Weekly", percent: weekly),
                UsageMetric(label: "Monthly", percent: monthly),
            ]
        )
    }
}
