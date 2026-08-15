import AppKit
import Foundation

public enum IconComposer {
    public static func image(from spec: IconSpec, base: NSImage? = nil, size: CGFloat = 1024) -> NSImage {
        let canvas = NSImage(size: NSSize(width: size, height: size))
        canvas.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        defer { canvas.unlockFocus() }

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let radius = size * 0.22
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: radius, yRadius: radius)

        if let custom = pngImage(spec.customImagePNG) {
            path.addClip()
            custom.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        } else if let base {
            path.addClip()
            base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        } else {
            (NSColor(hex: spec.tintHex) ?? .systemBlue).setFill()
            path.fill()
            NSColor.white.withAlphaComponent(0.12).setFill()
            NSBezierPath(ovalIn: NSRect(x: size * 0.15, y: size * 0.45, width: size * 0.7, height: size * 0.5)).fill()
        }

        if spec.customImagePNG == nil, base != nil, let tint = NSColor(hex: spec.tintHex) {
            tint.withAlphaComponent(0.38).setFill()
            path.fill()
        }

        let badge = spec.badge.trimmingCharacters(in: .whitespacesAndNewlines)
        if spec.showsBadge, !badge.isEmpty {
            drawTextBadge(badge, size: size)
        }

        return canvas
    }

    public static func writeICNS(
        spec: IconSpec,
        to destination: URL,
        base: NSImage? = nil,
        fileManager: FileManager = .default
    ) throws {
        let image = image(from: spec, base: base)
        let temp = fileManager.temporaryDirectory.appendingPathComponent("twocursors-icon-\(UUID().uuidString)", isDirectory: true)
        let iconset = temp.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temp) }

        let sizes: [(Int, Int)] = [
            (16, 1), (16, 2),
            (32, 1), (32, 2),
            (128, 1), (128, 2),
            (256, 1), (256, 2),
            (512, 1), (512, 2),
        ]
        for (baseSize, scale) in sizes {
            let pixel = baseSize * scale
            let name = scale == 1 ? "icon_\(baseSize)x\(baseSize).png" : "icon_\(baseSize)x\(baseSize)@2x.png"
            guard let png = pngDataPreservingAlpha(image, pixels: pixel) else {
                throw TwoCursorsError.iconFailed("Could not encode PNG at \(pixel)px.")
            }
            try png.write(to: iconset.appendingPathComponent(name))
        }

        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconset.path, "-o", destination.path]
        let err = Pipe()
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw TwoCursorsError.iconFailed(message.isEmpty ? "iconutil failed" : message)
        }
    }

    public static func applyFinderIcon(image: NSImage, to fileURL: URL) -> Bool {
        NSWorkspace.shared.setIcon(image, forFile: fileURL.path, options: [])
    }

    public static func baseIcon(for recipeID: String) -> NSImage? {
        let path: String
        switch recipeID {
        case GrokRecipe().id:
            path = "/Applications/Grok Bot.app"
        case CursorRecipe().id:
            path = "/Applications/Cursor.app"
        case ClaudeRecipe().id:
            path = "/Applications/Claude.app"
        case ChatGPTRecipe().id:
            path = "/Applications/ChatGPT.app"
        default:
            path = "/Applications/Grok Bot.app"
        }
        let app = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: app.path) else { return nil }
        return NSWorkspace.shared.icon(forFile: app.path)
    }

    public static func cursorBaseIcon() -> NSImage? {
        baseIcon(for: CursorRecipe().id)
    }

    /// Build a PNG iconset from an existing image that already has transparency.
    public static func writeICNS(from image: NSImage, to destination: URL, fileManager: FileManager = .default) throws {
        let temp = fileManager.temporaryDirectory.appendingPathComponent("twocursors-icon-\(UUID().uuidString)", isDirectory: true)
        let iconset = temp.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temp) }

        let sizes: [(Int, Int)] = [
            (16, 1), (16, 2),
            (32, 1), (32, 2),
            (128, 1), (128, 2),
            (256, 1), (256, 2),
            (512, 1), (512, 2),
        ]
        for (baseSize, scale) in sizes {
            let pixel = baseSize * scale
            let name = scale == 1 ? "icon_\(baseSize)x\(baseSize).png" : "icon_\(baseSize)x\(baseSize)@2x.png"
            guard let png = pngDataPreservingAlpha(image, pixels: pixel) else {
                throw TwoCursorsError.iconFailed("Could not encode PNG at \(pixel)px.")
            }
            try png.write(to: iconset.appendingPathComponent(name))
        }

        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconset.path, "-o", destination.path]
        let err = Pipe()
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw TwoCursorsError.iconFailed(message.isEmpty ? "iconutil failed" : message)
        }
    }

    private static func drawTextBadge(_ badge: String, size: CGFloat) {
        let fontSize = size * 0.14
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let text = NSAttributedString(string: String(badge.prefix(8)).uppercased(), attributes: attributes)
        let textSize = text.size()
        let padding = size * 0.05
        let badgeRect = NSRect(
            x: (size - textSize.width) / 2 - padding,
            y: size * 0.08,
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 0.55
        )
        NSColor.black.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: size * 0.04, yRadius: size * 0.04).fill()
        let textOrigin = NSPoint(
            x: badgeRect.midX - textSize.width / 2,
            y: badgeRect.midY - textSize.height / 2
        )
        text.draw(at: textOrigin)
    }

    private static func pngImage(_ data: Data?) -> NSImage? {
        guard let data, let image = NSImage(data: data) else { return nil }
        return image
    }

    /// Resize with an explicit RGBA bitmap so Dock/Finder keep transparent corners.
    private static func pngDataPreservingAlpha(_ image: NSImage, pixels: Int) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = NSSize(width: pixels, height: pixels)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()
        image.draw(
            in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }
}

public extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let int = Int(value, radix: 16) else { return nil }
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(calibratedRed: r, green: g, blue: b, alpha: 1)
    }
}
