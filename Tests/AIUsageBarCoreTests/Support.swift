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
