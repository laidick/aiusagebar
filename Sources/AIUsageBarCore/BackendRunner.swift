import Foundation

public enum BackendError: Error, LocalizedError, Sendable {
    case binaryNotFound
    case failed(status: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "ai-usagebar not found in ~/.cargo/bin, /opt/homebrew/bin or PATH"
        case let .failed(status, message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "ai-usagebar exited with status \(status)" : trimmed
        }
    }
}

public protocol BackendRunner: Sendable {
    func fetch() async throws -> UsageSnapshot
}

/// Runs `ai-usagebar usage --json` and decodes its output.
public struct ProcessBackendRunner: BackendRunner {
    public let searchPaths: [String]

    public init(searchPaths: [String]? = nil) {
        self.searchPaths = searchPaths ?? [
            NSHomeDirectory() + "/.cargo/bin/ai-usagebar",
            "/opt/homebrew/bin/ai-usagebar",
            "/usr/local/bin/ai-usagebar",
        ]
    }

    public func locateBinary() -> String? {
        let fm = FileManager.default
        if let direct = searchPaths.first(where: { fm.isExecutableFile(atPath: $0) }) { return direct }
        let env = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/local/bin"
        for dir in env.split(separator: ":") {
            let candidate = String(dir) + "/ai-usagebar"
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    public func fetch() async throws -> UsageSnapshot {
        try fetchSync()
    }

    /// Blocking variant, used by `--dump` where there is no run loop to yield to.
    public func fetchSync() throws -> UsageSnapshot {
        guard let binary = locateBinary() else { throw BackendError.binaryNotFound }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["usage", "--json"]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw BackendError.failed(
                status: process.terminationStatus,
                message: String(data: errData, encoding: .utf8) ?? ""
            )
        }
        return try UsageSnapshot.decode(data)
    }
}
