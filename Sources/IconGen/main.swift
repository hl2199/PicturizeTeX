import AppKit
import LatexRender

// Generates the app icon: a hand-built monoline pi -- one even stroke, round
// ends, straight bar and legs, and a quarter-circle foot on the right -- in
// the app's accent viridian on the warm dotted paper of the desk.
// Run with the output directory as the only argument; writes AppIcon.iconset.
@MainActor
final class IconDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
            let master = Self.compose()

            // Emit the iconset. macOS wants each size and its @2x pair.
            let iconset = outDir.appendingPathComponent("AppIcon.iconset")
            try? FileManager.default.removeItem(at: iconset)
            try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
            for base in [16, 32, 128, 256, 512] {
                try Self.writePNG(master, pixels: base,
                                  to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
                try Self.writePNG(master, pixels: base * 2,
                                  to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
            }
            print("ICONSET: \(iconset.path)")
            exit(0)
        } catch {
            print("FAILED: \(error)")
            exit(1)
        }
    }

    /// Draws the 1024-pt master: paper squircle, dot grid, centred glyph.
    static func compose() -> NSImage {
        let canvas = NSImage(size: NSSize(width: 1024, height: 1024))
        canvas.lockFocus()

        // Standard Big Sur icon grid: an 824-pt squircle centred on the canvas.
        let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
        let squircle = NSBezierPath(roundedRect: rect, xRadius: 186, yRadius: 186)

        // Soft drop shadow, as macOS icons carry their own.
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.shadowBlurRadius = 24
        shadow.set()
        NSColor(srgbRed: 0.992, green: 0.988, blue: 0.976, alpha: 1).setFill()
        squircle.fill()
        NSGraphicsContext.restoreGraphicsState()

        // A whisper of a gradient so the paper reads as material.
        NSGradient(colors: [
            NSColor(srgbRed: 1.0, green: 0.997, blue: 0.99, alpha: 1),
            NSColor(srgbRed: 0.975, green: 0.968, blue: 0.95, alpha: 1),
        ])?.draw(in: squircle, angle: -90)

        // The desk's dot grid, clipped to the sheet.
        NSGraphicsContext.saveGraphicsState()
        squircle.setClip()
        NSColor(srgbRed: 0.1, green: 0.1, blue: 0.12, alpha: 0.055).setFill()
        let step: CGFloat = 64
        var y = rect.minY + step / 2
        while y < rect.maxY {
            var x = rect.minX + step / 2
            while x < rect.maxX {
                NSBezierPath(ovalIn: NSRect(x: x - 4, y: y - 4, width: 8, height: 8)).fill()
                x += step
            }
            y += step
        }
        NSGraphicsContext.restoreGraphicsState()

        drawGlyph(in: rect)

        canvas.unlockFocus()
        return canvas
    }

    /// The pi, stroked at one width with round caps so every end is soft.
    /// Optically centred: a touch above the sheet's geometric centre.
    static func drawGlyph(in rect: NSRect) {
        // The bar overhangs the left leg less than the right, so shift the
        // glyph to centre its overall width on the sheet.
        let legX: CGFloat = 92, leftBar: CGFloat = 190, rightBar: CGFloat = 225
        let cx = rect.midX + (leftBar - rightBar) / 2, cy = rect.midY + 6
        let top = cy + 165, bottom = cy - 185
        let footRadius: CGFloat = 78

        let bar = NSBezierPath()
        bar.move(to: NSPoint(x: cx - leftBar, y: top))
        bar.line(to: NSPoint(x: cx + rightBar, y: top))

        let left = NSBezierPath()
        left.move(to: NSPoint(x: cx - legX, y: top))
        left.line(to: NSPoint(x: cx - legX, y: bottom))

        // Right leg: straight down into a quarter-circle foot that turns right.
        let right = NSBezierPath()
        right.move(to: NSPoint(x: cx + legX, y: top))
        right.line(to: NSPoint(x: cx + legX, y: bottom + footRadius))
        right.appendArc(withCenter: NSPoint(x: cx + legX + footRadius, y: bottom + footRadius),
                        radius: footRadius, startAngle: 180, endAngle: 270)
        right.line(to: NSPoint(x: cx + legX + footRadius + 20, y: bottom))

        // Scale the whole glyph, stroke included, about the sheet's centre.
        let scale: CGFloat = 1.06
        NSGraphicsContext.saveGraphicsState()
        let t = NSAffineTransform()
        t.translateX(by: rect.midX, yBy: rect.midY)
        t.scale(by: scale)
        t.translateX(by: -rect.midX, yBy: -rect.midY)
        t.concat()

        NSColor(srgbRed: 0.180, green: 0.431, blue: 0.369, alpha: 1).setStroke()
        for stroke in [bar, left, right] {
            stroke.lineWidth = 84
            stroke.lineCapStyle = .round
            stroke.lineJoinStyle = .round
            stroke.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    static func writePNG(_ image: NSImage, pixels: Int, to url: URL) throws {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else {
            throw RenderError.engineFailure("bitmap alloc failed")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw RenderError.engineFailure("png encode failed")
        }
        try data.write(to: url)
    }
}

let app = NSApplication.shared
let delegate = IconDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
