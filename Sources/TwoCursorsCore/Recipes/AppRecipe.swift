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

public struct ClaudeRecipe: AppRecipe {
    public static let bundleIdentifier = "com.anthropic.claudefordesktop"

    public let id = "claude"
    public let displayName = "Claude"
    public let appFileNames = ["Claude.app"]
    public let requiredBundleIDs = [ClaudeRecipe.bundleIdentifier]
    public let executableName = "Claude"
    public let defaultUserDataFolderName = "Claude"
    public let urlSchemes = ["claude"]
    public let seedsMarketplace = false
    public let supportsUserDataDir = true
    public let downloadURL = URL(string: "https://claude.ai/download")!

    public init() {}
}

public struct ChatGPTRecipe: AppRecipe {
    /// Desktop ChatGPT ships as Codex under this bundle ID.
    public static let bundleIdentifier = "com.openai.codex"

    public let id = "chatgpt"
    public let displayName = "ChatGPT"
    public let appFileNames = ["ChatGPT.app"]
    public let requiredBundleIDs = [ChatGPTRecipe.bundleIdentifier]
    public let executableName = "ChatGPT"
    public let defaultUserDataFolderName = "ChatGPT"
    public let urlSchemes = ["codex"]
    public let seedsMarketplace = false
    public let supportsUserDataDir = true
    public let downloadURL = URL(string: "https://chatgpt.com/desktop")!

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
    public static let claude = ClaudeRecipe()
    public static let chatgpt = ChatGPTRecipe()

    /// Agent apps only: Grok Bot, Cursor, Claude, ChatGPT/Codex.
    public static var all: [any AppRecipe] { [grok, cursor, claude, chatgpt] }

    public static func recipe(id: String) -> (any AppRecipe)? {
        all.first { $0.id == id }
    }
}
