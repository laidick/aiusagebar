import Foundation
import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp`, which only works from a real bundle.
enum LaunchAtLogin {
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    static var isEnabled: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        guard isAvailable else { return false }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("AIUsageBar: launch-at-login toggle failed: \(error.localizedDescription)")
            return false
        }
    }
}
