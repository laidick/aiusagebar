import AppKit
import AIUsageBarCore

/// Draws the menu bar glyph: a compact gauge ring tinted by overall severity.
enum StatusIcon {
    static let size = NSSize(width: 17, height: 17)

    enum State {
        case loading
        case error
        case ready(Severity, fraction: Double)
    }

    static func image(for state: State) -> NSImage {
        let tint: NSColor
        let fraction: Double
        var showErrorDot = false

        switch state {
        case .loading:
            tint = .tertiaryLabelColor
            fraction = 0
        case .error:
            tint = .tertiaryLabelColor
            fraction = 0
            showErrorDot = true
        case let .ready(severity, value):
            tint = Palette.severityColor(severity)
            fraction = min(max(value, 0), 1)
        }

        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return true }
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = rect.width / 2 - 3.0
            let lineWidth: CGFloat = 2.6

            ctx.setLineCap(.round)

            // Subtle dark outline so the ring reads on light *and* dark menu bars.
            ctx.setLineWidth(lineWidth + 1.4)
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.28).cgColor)
            ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.strokePath()

            // Track.
            ctx.setLineWidth(lineWidth)
            ctx.setStrokeColor(tint.withAlphaComponent(0.25).cgColor)
            ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.strokePath()

            // Progress arc, clockwise from 12 o'clock.
            if fraction > 0 {
                let start = CGFloat.pi / 2
                let end = start - CGFloat(fraction) * .pi * 2
                ctx.setLineWidth(lineWidth)
                ctx.setStrokeColor(tint.cgColor)
                ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
                ctx.strokePath()
            } else {
                // Nothing to show yet: a small centre pip keeps the glyph legible.
                ctx.setFillColor(tint.cgColor)
                ctx.fillEllipse(in: CGRect(x: center.x - 1.6, y: center.y - 1.6, width: 3.2, height: 3.2))
            }

            if showErrorDot {
                let dot = CGRect(x: rect.maxX - 4.6, y: rect.maxY - 4.6, width: 4.2, height: 4.2)
                ctx.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
                ctx.fillEllipse(in: dot.insetBy(dx: -0.7, dy: -0.7))
                ctx.setFillColor(Palette.danger.cgColor)
                ctx.fillEllipse(in: dot)
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
