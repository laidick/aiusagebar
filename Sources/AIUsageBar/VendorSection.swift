import SwiftUI
import AIUsageBarCore

/// One vendor: primary row, optional sub-rows, optional error line.
struct VendorSection: View {
    let vendor: VendorLanes
    let now: Date
    let onLogin: (String) -> Void
    let onSetKey: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(vendor.rows) { row in
                HStack(alignment: .top, spacing: 10) {
                    label(for: row)
                        .frame(width: 132, alignment: .leading)
                    LaneCell(lane: row.session, now: now).frame(width: 88)
                    LaneCell(lane: row.weekly, now: now).frame(width: 88)
                }
            }
            if let error = vendor.error, !error.isEmpty {
                errorLine(error)
            }
        }
    }

    @ViewBuilder
    private func label(for row: UsageRow) -> some View {
        if row.isPrimary {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.vendor(vendor.id))
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(row.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                        if vendor.stale {
                            Text("STALE")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.18), in: RoundedRectangle(cornerRadius: 3))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(vendor.plan ?? "—")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } else {
            Text(row.title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.leading, 13)
        }
    }

    private var isKeyVendor: Bool { LoginActions.keyVendor(id: vendor.id) != nil }

    private func errorLine(_ error: String) -> some View {
        HStack(spacing: 6) {
            Text(error)
                .font(.system(size: 10))
                .foregroundStyle(Color(Palette.danger))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            if isKeyVendor, vendor.needsAPIKey {
                Button("Set key") { onSetKey(vendor.id) }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10, weight: .semibold))
            } else if vendor.needsLogin {
                Button("Log in") { onLogin(vendor.id) }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .padding(.leading, 13)
    }
}
