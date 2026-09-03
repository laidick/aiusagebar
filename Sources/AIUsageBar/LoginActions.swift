import AppKit
import Foundation
import AIUsageBarCore

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

    /// Vendors with no CLI login: the key is pasted into a prompt and stored in config.toml.
    struct KeyVendor: Sendable {
        let id: String
        let title: String
        /// Menu/footer wording, e.g. `OpenCode Go key…`.
        var actionTitle: String { "\(title) key…" }
    }

    static let keyVendors: [KeyVendor] = [
        KeyVendor(id: "opencode-go", title: "OpenCode Go"),
    ]

    static func vendor(id: String) -> Vendor? {
        vendors.first { $0.id == id }
    }

    static func keyVendor(id: String) -> KeyVendor? {
        keyVendors.first { $0.id == id }
    }

    /// Asks for the API key, writes it into `~/.config/ai-usagebar/config.toml`, then refreshes.
    @MainActor
    static func promptForKey(vendorID: String, onSaved: () -> Void) {
        guard let vendor = keyVendor(id: vendorID) else { return }

        let alert = NSAlert()
        alert.messageText = "\(vendor.title) API key"
        alert.informativeText = """
        Stored in ~/.config/ai-usagebar/config.toml under [\(vendor.id)].
        """
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "OPENCODE_GO_API_KEY"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        do {
            try ConfigEditor.writeOpenCodeGoKey(key)
            onSaved()
        } catch {
            let failure = NSAlert()
            failure.messageText = "Could not save the key"
            failure.informativeText = error.localizedDescription
            failure.runModal()
        }
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
