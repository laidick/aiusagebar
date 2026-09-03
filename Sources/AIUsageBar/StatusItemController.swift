import AppKit
import SwiftUI
import Combine
import AIUsageBarCore

/// Owns the status item, its icon, the popover, and the right-click menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let store: UsageStore
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []

    init(store: UsageStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(rootView: PopoverView(store: store))

        if let button = statusItem.button {
            button.image = StatusIcon.image(for: .loading)
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.scheduleIconUpdate() }
            .store(in: &cancellables)
    }

    private func scheduleIconUpdate() {
        // objectWillChange fires before the value lands; update on the next hop.
        Task { @MainActor in self.updateIcon() }
    }

    func updateIcon() {
        statusItem.button?.image = StatusIcon.image(for: store.iconState)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if isRightClick {
            showMenu(from: sender)
        } else {
            togglePopover(from: sender)
        }
    }

    private func togglePopover(from button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        store.refreshIfStale()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.delegate = self

        let refresh = NSMenuItem(title: "Refresh", action: #selector(menuRefresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let login = NSMenuItem(title: "Log in", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for vendor in LoginActions.vendors {
            let item = NSMenuItem(title: vendor.title, action: #selector(menuLogin(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = vendor.id
            submenu.addItem(item)
        }
        login.submenu = submenu
        menu.addItem(login)

        for vendor in LoginActions.keyVendors {
            let item = NSMenuItem(
                title: vendor.actionTitle, action: #selector(menuSetKey(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = vendor.id
            menu.addItem(item)
        }

        if LaunchAtLogin.isAvailable {
            let toggle = NSMenuItem(title: "Launch at login", action: #selector(menuToggleLaunch), keyEquivalent: "")
            toggle.target = self
            toggle.state = LaunchAtLogin.isEnabled ? .on : .off
            menu.addItem(toggle)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        button.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        // Detach so the next left click reaches our action again.
        statusItem.menu = nil
    }

    @objc private func menuRefresh() { store.refresh() }

    @objc private func menuLogin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        LoginActions.login(vendorID: id)
    }

    @objc private func menuSetKey(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        LoginActions.promptForKey(vendorID: id) { store.refresh() }
    }

    @objc private func menuToggleLaunch() {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
    }

    @objc private func menuQuit() { NSApp.terminate(nil) }
}
