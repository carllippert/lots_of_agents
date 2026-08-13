import Foundation

public struct GrokRecipe: AppRecipe {
    public static let bundleIdentifier = "com.anysphere.sand"

    public let id = "grok"
    public let displayName = "Grok Bot"
    public let appFileNames = ["Grok Bot.app"]
    public let requiredBundleIDs = [GrokRecipe.bundleIdentifier]
    public let executableName = "Grok Bot"
    public let defaultUserDataFolderName = "Grok Bot"
    public let urlSchemes = ["sand"]
    public let seedsMarketplace = false
    public let supportsUserDataDir = true
    public let downloadURL = URL(string: "https://cursor.com/bot/onboarding")!

    public init() {}
}

public struct CursorRecipe: AppRecipe {
    public static let bundleIdentifier = "com.todesktop.230313mzl4w4u92"

    public let id = "cursor"
    public let displayName = "Cursor"
    public let appFileNames = ["Cursor.app"]
    public let requiredBundleIDs = [CursorRecipe.bundleIdentifier]
    public let executableName = "Cursor"
    public let defaultUserDataFolderName = "Cursor"
    public let urlSchemes = ["cursor"]
    public let seedsMarketplace = true
    public let supportsUserDataDir = true
    public let downloadURL = URL(string: "https://cursor.com")!

    public init() {}
}

public protocol AppRecipe {
    var id: String { get }
    var displayName: String { get }
    var appFileNames: [String] { get }
    var requiredBundleIDs: [String] { get }
    var executableName: String { get }
    var defaultUserDataFolderName: String { get }
    var urlSchemes: [String] { get }
    var seedsMarketplace: Bool { get }
    var supportsUserDataDir: Bool { get }
    var downloadURL: URL { get }

    func detect(using detector: InstalledAppDetector) -> AppStatus
    func launchArguments(userData: URL, extensions: URL) -> [String]
}

public extension AppRecipe {
    func detect(using detector: InstalledAppDetector) -> AppStatus {
        detector.detect(
            recipeID: id,
            displayName: displayName,
            appFileNames: appFileNames,
            requiredBundleIDs: requiredBundleIDs,
            executableName: executableName
        )
    }

    func launchArguments(userData: URL, extensions: URL) -> [String] {
        guard supportsUserDataDir else { return [] }
        return [
            "--user-data-dir=\(userData.path)",
            "--extensions-dir=\(extensions.path)",
        ]
    }
}

public enum RecipeRegistry {
    public static let grok = GrokRecipe()
    public static let cursor = CursorRecipe()

    /// Grok is the launch product; Cursor is the second recipe.
    public static var all: [any AppRecipe] { [grok, cursor] }

    public static func recipe(id: String) -> (any AppRecipe)? {
        all.first { $0.id == id }
    }
}
