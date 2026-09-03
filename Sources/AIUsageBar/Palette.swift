import AppKit
import SwiftUI
import AIUsageBarCore

/// High-contrast palette shared by the menu bar icon and the popover.
enum Palette {
    static func hex(_ value: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    static func severityColor(_ severity: Severity) -> NSColor {
        switch severity {
        case .low: return hex(0x3F_B9_50)
        case .mid: return hex(0xE3_B3_41)
        case .high: return hex(0xF0_88_3E)
        case .critical: return hex(0xF8_51_49)
        }
    }

    /// Brand dot next to each vendor name.
    static func vendorColor(_ id: String) -> NSColor {
        switch id {
        case "anthropic": return hex(0xD9_77_57)
        case "openai": return hex(0x10_A3_7F)
        case "antigravity": return hex(0x42_85_F4)
        case "opencode-go": return hex(0xA7_8B_FA)
        default: return .secondaryLabelColor
        }
    }

    static let neutral = NSColor.secondaryLabelColor
    static let danger = hex(0xF8_51_49)
}

extension Color {
    init(_ nsColor: NSColor) { self.init(nsColor: nsColor) }

    static func severity(_ severity: Severity) -> Color { Color(Palette.severityColor(severity)) }
    static func vendor(_ id: String) -> Color { Color(Palette.vendorColor(id)) }
}
