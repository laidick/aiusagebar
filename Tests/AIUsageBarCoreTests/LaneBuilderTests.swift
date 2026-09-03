// Deliberately no `import Foundation` here — see Support.swift.
import Testing
@testable import AIUsageBarCore

@Test func decodesFixture() throws {
    let snapshot = try Fixture.snapshot()
    #expect(snapshot.entries.count == 3)
    #expect(snapshot.entries.map(\.id) == ["anthropic", "openai", "antigravity"])
    #expect(snapshot.entries[0].metrics.count == 3)
    #expect(snapshot.entries[0].fetchedDate != nil)
}

@Test func classifiesLaneKinds() {
    #expect(LaneBuilder.kind(of: "Session (5h)") == .session)
    #expect(LaneBuilder.kind(of: "Codex 5h") == .session)
    #expect(LaneBuilder.kind(of: "Weekly (7d)") == .weekly)
    #expect(LaneBuilder.kind(of: "Fable (7d)") == .weekly)
    #expect(LaneBuilder.kind(of: "Codex weekly") == .weekly)
    #expect(LaneBuilder.kind(of: "Gemini") == .unknown)
    #expect(LaneBuilder.kind(of: "Claude & GPT OSS") == .unknown)
}

@Test func derivesKeys() throws {
    let entries = try Fixture.snapshot().entries
    let anthropic = entries[0], openai = entries[1], antigravity = entries[2]
    #expect(LaneBuilder.key(of: "Session (5h)", entry: anthropic) == "")
    #expect(LaneBuilder.key(of: "Weekly (7d)", entry: anthropic) == "")
    #expect(LaneBuilder.key(of: "Fable (7d)", entry: anthropic) == "Fable")
    #expect(LaneBuilder.key(of: "Codex 5h", entry: openai) == "")
    #expect(LaneBuilder.key(of: "Codex weekly", entry: openai) == "")
    #expect(LaneBuilder.key(of: "Gemini", entry: antigravity) == "Gemini")
    #expect(LaneBuilder.key(of: "Claude & GPT OSS", entry: antigravity) == "Claude & GPT OSS")
}

@Test func stripsVendorWordFromPlan() throws {
    let entries = try Fixture.snapshot().entries
    #expect(LaneBuilder.planLabel(for: entries[0]) == "Max 20x")
    #expect(LaneBuilder.planLabel(for: entries[1]) == "ChatGPT Plus")
    #expect(LaneBuilder.planLabel(for: entries[2]) == "Google AI Pro")
}

@Test func buildsExpectedRowsFromFixture() throws {
    let table = LaneBuilder.build(try Fixture.snapshot())
    #expect(table.vendors.map(\.title) == ["Claude", "Codex", "Gemini"])

    let claude = table.vendors[0]
    #expect(claude.plan == "Max 20x")
    #expect(claude.rows.count == 2)
    #expect(claude.rows[0].isPrimary)
    #expect(claude.rows[0].session?.percent == 7)
    #expect(claude.rows[0].weekly?.percent == 8)
    #expect(claude.rows[1].title == "Fable")
    #expect(claude.rows[1].session == nil)
    #expect(claude.rows[1].weekly?.percent == 2)

    let codex = table.vendors[1]
    #expect(codex.plan == "ChatGPT Plus")
    #expect(codex.rows.count == 1)
    #expect(codex.rows[0].session?.percent == 5)
    #expect(codex.rows[0].weekly?.percent == 45)

    let gemini = table.vendors[2]
    #expect(gemini.plan == "Google AI Pro")
    // "Claude & GPT OSS" is 0%/0% and not primary, so it is hidden.
    #expect(gemini.rows.count == 1)
    #expect(gemini.rows[0].title == "Gemini")
    #expect(gemini.rows[0].session?.percent == 35)
    #expect(gemini.rows[0].weekly?.percent == 19)
}

@Test func resetTimesRenderCompactly() throws {
    let table = LaneBuilder.build(try Fixture.snapshot())
    let now = Fixture.date("2026-09-03T07:48:22Z")
    let primary = table.vendors[0].rows[0]
    #expect(ResetFormatter.string(until: primary.session!.resetAt!, now: now) == "4h 21m")
    #expect(ResetFormatter.string(until: primary.weekly!.resetAt!, now: now) == "6d 10h")
}

@Test func paceComesFromTheDetailStringWhenPresent() throws {
    let table = LaneBuilder.build(try Fixture.snapshot(), now: Synthetic.now)
    let claude = table.vendors[0].rows[0]
    #expect(claude.weekly?.elapsedFraction == 0.08)
    #expect(claude.session?.elapsedFraction == 0.12)
    #expect(table.vendors[1].rows[0].session?.elapsedFraction == 0.83)
}

@Test func paceFallsBackToTheResetWindow() {
    let weekly = LaneBuilder.elapsedFraction(
        for: Synthetic.metric(label: "Gemini", resetInSeconds: 3.5 * 86_400),
        slot: .weekly, now: Synthetic.now
    )
    #expect(weekly == 0.5)

    let session = LaneBuilder.elapsedFraction(
        for: Synthetic.metric(label: "Gemini", resetInSeconds: 3_600),
        slot: .session, now: Synthetic.now
    )
    #expect(session == 0.8)
}

@Test func paceIsNilWithoutDetailOrReset() {
    let none = LaneBuilder.elapsedFraction(
        for: Synthetic.bare(label: "Gemini"), slot: .session, now: Synthetic.now
    )
    #expect(none == nil)
}

@Test func paceFromWindowIsClampedToUnitRange() {
    let past = LaneBuilder.elapsedFraction(
        for: Synthetic.metric(label: "Gemini", resetInSeconds: -3_600),
        slot: .session, now: Synthetic.now
    )
    #expect(past == 1)

    let far = LaneBuilder.elapsedFraction(
        for: Synthetic.metric(label: "Gemini", resetInSeconds: 30 * 86_400),
        slot: .weekly, now: Synthetic.now
    )
    #expect(far == 0)
}

@Test func overallSeverityIsLowForFixture() throws {
    let table = LaneBuilder.build(try Fixture.snapshot())
    #expect(table.severity == .low)
}
