import Foundation

/// Opens a login flow for one vendor in Terminal.app.
enum LoginActions {
    struct Vendor: Sendable {
        let id: String
        let title: String
        let command: String
    }

    static let vendors: [Vendor] = [
        Vendor(id: "anthropic", title: "Claude", command: "claude auth login --claudeai"),
        Vendor(id: "openai", title: "Codex", command: "codex login"),
        Vendor(id: "antigravity", title: "Gemini", command: "agy"),
    ]

    static func vendor(id: String) -> Vendor? {
        vendors.first { $0.id == id }
    }

    static func login(vendorID: String) {
        guard let vendor = vendor(id: vendorID) else { return }
        runInTerminal(
            """
            export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:$PATH"
            \(vendor.command)
            echo
            read -p "Press Enter to close..."
            """
        )
    }

    /// Writes the script to a temp file so we avoid AppleScript quoting hell.
    static func runInTerminal(_ script: String) {
        let path = NSTemporaryDirectory() + "aiusagebar-login-\(UUID().uuidString).sh"
        guard (try? script.write(toFile: path, atomically: true, encoding: .utf8)) != nil else { return }
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path)
        let osa = """
        tell application "Terminal" to do script "bash '\(path)'; rm -f '\(path)'"
        tell application "Terminal" to activate
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", osa]
        try? process.run()
    }
}
