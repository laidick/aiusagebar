import AppKit
import AIUsageBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private var controller: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        EditMenu.install()
        controller = StatusItemController(store: store)
        store.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
    }
}
