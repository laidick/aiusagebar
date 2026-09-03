// Deliberately no `import Foundation` here — see Support.swift.
import Testing
@testable import AIUsageBarCore

@Test func severityThresholds() {
    #expect(Severity.forPercent(0) == .low)
    #expect(Severity.forPercent(49.9) == .low)
    #expect(Severity.forPercent(50) == .mid)
    #expect(Severity.forPercent(74.9) == .mid)
    #expect(Severity.forPercent(75) == .high)
    #expect(Severity.forPercent(89.9) == .high)
    #expect(Severity.forPercent(90) == .critical)
    #expect(Severity.forPercent(100) == .critical)
}

@Test func severityTakesMaxOfComputedAndBackend() {
    #expect(Severity.resolve(percent: 10, backend: "critical") == .critical)
    #expect(Severity.resolve(percent: 95, backend: "low") == .critical)
    #expect(Severity.resolve(percent: 10, backend: nil) == .low)
    #expect(Severity.resolve(percent: 10, backend: "nonsense") == .low)
}

@Test func resetFormatterShapes() {
    #expect(ResetFormatter.string(seconds: 6 * 86_400 + 10 * 3_600 + 11 * 60) == "6d 10h")
    #expect(ResetFormatter.string(seconds: 4 * 3_600 + 21 * 60 + 38) == "4h 21m")
    #expect(ResetFormatter.string(seconds: 45 * 60) == "45m")
    #expect(ResetFormatter.string(seconds: 59) == "now")
    #expect(ResetFormatter.string(seconds: 0) == "now")
    #expect(ResetFormatter.string(seconds: -500) == "now")
}

@Test func resetFormatterUsesInjectedNow() {
    let now = Fixture.date("2026-09-03T07:48:22Z")
    let reset = Fixture.date("2026-09-03T08:33:22Z")
    #expect(ResetFormatter.string(until: reset, now: now) == "45m")
}

@Test func iso8601HandlesNineDigitFractions() {
    #expect(ISO8601.parse("2026-09-03T07:48:22.266766481Z") != nil)
    #expect(ISO8601.parse("2026-09-03T08:38:38Z") != nil)
    #expect(ISO8601.parse("2026-09-03T12:10:00.097293Z") != nil)
    #expect(ISO8601.normaliseFraction("2026-09-03T07:48:22.266766481Z") == "2026-09-03T07:48:22.266Z")
}

@Test func authErrorsGetALoginAffordance() {
    func lanes(_ error: String?) -> VendorLanes {
        VendorLanes(id: "x", title: "X", plan: nil, error: error, stale: false, rows: [])
    }
    #expect(lanes("HTTP 401 Unauthorized").needsLogin)
    #expect(lanes("Keychain item missing").needsLogin)
    #expect(lanes("please run login").needsLogin)
    #expect(lanes("no credentials found").needsLogin)
    #expect(!lanes("connection reset by peer").needsLogin)
    #expect(!lanes(nil).needsLogin)
}
