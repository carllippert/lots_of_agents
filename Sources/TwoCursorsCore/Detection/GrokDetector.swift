import Foundation

/// Matches Grok Bot by `com.anysphere.sand` — display name alone is not enough.
public struct GrokDetector {
    public var detector: InstalledAppDetector

    public init(detector: InstalledAppDetector = InstalledAppDetector()) {
        self.detector = detector
    }

    public func status() -> AppStatus {
        GrokRecipe().detect(using: detector)
    }

    public static func live() -> AppStatus {
        GrokDetector().status()
    }
}

/// Matches Cursor by `com.todesktop.230313mzl4w4u92` — name alone is not enough.
public struct CursorDetector {
    public var detector: InstalledAppDetector

    public init(detector: InstalledAppDetector = InstalledAppDetector()) {
        self.detector = detector
    }

    public func status() -> AppStatus {
        CursorRecipe().detect(using: detector)
    }

    public static func live() -> AppStatus {
        CursorDetector().status()
    }
}
