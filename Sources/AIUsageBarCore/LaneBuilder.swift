import Foundation

/// Turns the backend's flat `metrics[]` into a Vendor | Plan | Session | Weekly table.
public enum LaneBuilder {
    /// Display names we prefer over the backend's own labels.
    static let displayNames: [String: String] = [
        "anthropic": "Claude",
        "openai": "Codex",
        "antigravity": "Gemini",
    ]

    private static let sessionTokens = ["5h", "session"]
    private static let weeklyTokens = ["weekly", "7d"]

    public static func build(_ snapshot: UsageSnapshot) -> LaneTable {
        LaneTable(vendors: snapshot.entries.map(vendorLanes(for:)))
    }

    public static func displayName(for entry: VendorEntry) -> String {
        displayNames[entry.id] ?? entry.displayName
    }

    /// `Claude Max 20x` -> `Max 20x`; `ChatGPT Plus` and `Google AI Pro` are left alone.
    public static func planLabel(for entry: VendorEntry) -> String? {
        guard let plan = entry.plan?.trimmingCharacters(in: .whitespaces), !plan.isEmpty else {
            return nil
        }
        var words = plan.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let vendorWords = Set(
            [displayName(for: entry), entry.displayName, entry.name]
                .map { $0.lowercased() }
        )
        if let first = words.first, vendorWords.contains(first.lowercased()), words.count > 1 {
            words.removeFirst()
        }
        return words.joined(separator: " ")
    }

    static func kind(of label: String) -> LaneKind {
        let lower = label.lowercased()
        if sessionTokens.contains(where: { lower.contains($0) }) { return .session }
        if weeklyTokens.contains(where: { lower.contains($0) }) { return .weekly }
        return .unknown
    }

    /// Strips parenthesised suffixes, lane tokens and the vendor's own names.
    static func key(of label: String, entry: VendorEntry) -> String {
        var stripped = ""
        var depth = 0
        for ch in label {
            if ch == "(" { depth += 1; continue }
            if ch == ")" { depth = max(0, depth - 1); continue }
            if depth == 0 { stripped.append(ch) }
        }
        let noise = Set(sessionTokens + weeklyTokens + [entry.displayName.lowercased(), entry.shortName.lowercased()])
            .filter { !$0.isEmpty }
        let words = stripped
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map(String.init)
            .filter { !noise.contains($0.lowercased()) }
        return words.joined(separator: " ")
    }

    private static func vendorLanes(for entry: VendorEntry) -> VendorLanes {
        var order: [String] = []
        var sessions: [String: Lane] = [:]
        var weeklies: [String: Lane] = [:]

        for metric in entry.metrics {
            let k = key(of: metric.label, entry: entry)
            if !order.contains(k) { order.append(k) }
            let lane = Lane(metric: metric)
            switch kind(of: metric.label) {
            case .session:
                sessions[k] = lane
            case .weekly:
                weeklies[k] = lane
            case .unknown:
                // First sighting of a repeated key is the session lane, second the weekly one.
                if sessions[k] == nil { sessions[k] = lane } else if weeklies[k] == nil { weeklies[k] = lane }
            }
        }

        let title = displayName(for: entry)
        let primaryKey = order.contains("") ? "" : (order.first ?? "")
        let primary = UsageRow(
            id: "\(entry.id)/primary",
            title: title,
            isPrimary: true,
            session: sessions[primaryKey],
            weekly: weeklies[primaryKey]
        )
        let subRows = order
            .filter { $0 != primaryKey }
            .map { k in
                UsageRow(
                    id: "\(entry.id)/\(k)",
                    title: k,
                    isPrimary: false,
                    session: sessions[k],
                    weekly: weeklies[k]
                )
            }
            .filter { !$0.isEmpty }

        return VendorLanes(
            id: entry.id,
            title: title,
            plan: planLabel(for: entry),
            error: entry.error,
            stale: entry.stale,
            rows: [primary] + subRows
        )
    }
}
