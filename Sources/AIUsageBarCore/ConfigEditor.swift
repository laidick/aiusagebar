import Foundation

/// Line-preserving edits to `~/.config/ai-usagebar/config.toml`.
///
/// The parsing is deliberately shallow: we only need to find one table header
/// and set two keys inside it, leaving every other byte of the file untouched.
public enum ConfigEditor {
    public static let openCodeGoSection = "opencode-go"

    public static var defaultURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/ai-usagebar/config.toml")
    }

    /// Sets `api_key` and `enabled = true` inside `[opencode-go]`, appending the
    /// section when it is absent. Everything else is preserved verbatim.
    public static func setOpenCodeGoKey(in text: String, key: String) -> String {
        let apiKeyLine = "api_key = \"\(escape(key))\""
        let enabledLine = "enabled = true"

        var lines = text.components(separatedBy: "\n")
        guard let header = lines.firstIndex(where: { isHeader($0, named: openCodeGoSection) }) else {
            var out = text
            if !out.isEmpty {
                if !out.hasSuffix("\n") { out += "\n" }
                out += "\n"
            }
            return out + "[\(openCodeGoSection)]\n\(enabledLine)\n\(apiKeyLine)\n"
        }

        setValue(&lines, sectionHeader: header, key: "api_key", line: apiKeyLine)
        setValue(&lines, sectionHeader: header, key: "enabled", line: enabledLine)
        return lines.joined(separator: "\n")
    }

    /// Reads the file (or starts from empty), applies the key, writes atomically at 0600.
    public static func writeOpenCodeGoKey(_ key: String, to url: URL = defaultURL) throws {
        let manager = FileManager.default
        try manager.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try setOpenCodeGoKey(in: existing, key: key)
            .write(to: url, atomically: true, encoding: .utf8)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// TOML basic-string escaping for the value we write.
    static func escape(_ value: String) -> String {
        var out = ""
        for ch in value {
            switch ch {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default: out.append(ch)
            }
        }
        return out
    }

    /// Replaces the assignment for `key` inside the section, or inserts it just below the header.
    private static func setValue(
        _ lines: inout [String], sectionHeader header: Int, key: String, line: String
    ) {
        var index = header + 1
        while index < lines.count, !isAnyHeader(lines[index]) {
            if assigns(lines[index], key: key) {
                lines[index] = line
                return
            }
            index += 1
        }
        lines.insert(line, at: header + 1)
    }

    private static func isHeader(_ line: String, named name: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces) == "[\(name)]"
    }

    private static func isAnyHeader(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("[")
    }

    /// `  api_key = "x"` assigns `api_key`; `# api_key = "x"` and `api_key_env = …` do not.
    private static func assigns(_ line: String, key: String) -> Bool {
        var rest = Substring(line.trimmingCharacters(in: .whitespaces))
        guard rest.hasPrefix(key) else { return false }
        rest = rest.dropFirst(key.count)
        while rest.first == " " || rest.first == "\t" { rest = rest.dropFirst() }
        return rest.first == "="
    }
}
