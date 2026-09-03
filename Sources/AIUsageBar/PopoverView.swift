import AppKit
import SwiftUI
import AIUsageBarCore

struct PopoverView: View {
    @ObservedObject var store: UsageStore
    @State private var now = Date()
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.5)
            content
            Divider().opacity(0.5)
            footer
        }
        .frame(width: 360)
        .onReceive(tick) { now = $0 }
        .onAppear {
            now = Date()
            launchAtLogin = LaunchAtLogin.isEnabled
            store.refreshIfStale()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            caption("VENDOR · PLAN").frame(width: 132, alignment: .leading)
            caption("SESSION").frame(width: 88, alignment: .leading)
            caption("WEEKLY").frame(width: 88, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private var content: some View {
        if let table = store.table, !table.vendors.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(table.vendors) { vendor in
                    VendorSection(vendor: vendor, now: now, onLogin: LoginActions.login(vendorID:))
                }
                if let error = store.lastError {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(Palette.danger))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.lastError ?? (store.isLoading ? "Loading…" : "No data"))
                    .font(.system(size: 11))
                    .foregroundStyle(store.lastError == nil ? .secondary : Color(Palette.danger))
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(updatedText)
                    .font(.system(size: 9.5))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("r", modifiers: .command)

                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10, weight: .semibold))
                    .keyboardShortcut("q", modifiers: .command)
            }

            HStack(spacing: 8) {
                Text("LOG IN")
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)
                ForEach(LoginActions.vendors, id: \.id) { vendor in
                    Button(vendor.title) { LoginActions.login(vendorID: vendor.id) }
                        .buttonStyle(.borderless)
                        .font(.system(size: 10))
                }
                Spacer(minLength: 0)
            }

            if LaunchAtLogin.isAvailable {
                Toggle(isOn: $launchAtLogin) {
                    Text("Launch at login").font(.system(size: 10))
                }
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, value in
                    if !LaunchAtLogin.set(value) { launchAtLogin = LaunchAtLogin.isEnabled }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var updatedText: String {
        guard let updatedAt = store.updatedAt else { return "Never updated" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Updated \(formatter.string(from: updatedAt)) · every \(Int(UsageStore.refreshInterval))s"
    }
}
