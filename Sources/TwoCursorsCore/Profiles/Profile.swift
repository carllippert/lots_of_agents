import Foundation

public enum IsolationMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// `--user-data-dir` + `--extensions-dir` only. Real HOME. Git/ssh/shell stay yours.
    case userDataDir
    /// Full-home overlay: every real-home top-level item is a symlink; a small set of
    /// app-specific folders (`~/.cursor`, `~/.codex`) are real, private per-clone directories.
    /// Never Parall's incomplete fake home.
    case fullHomeOverlay

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .userDataDir: return "Account & chats (recommended)"
        case .fullHomeOverlay: return "Full isolation (required for ChatGPT)"
        }
    }

    public var subtitle: String {
        switch self {
        case .userDataDir:
            return "Separate login, chats, settings, and extensions. Git, SSH, and your shell keep using your real home."
        case .fullHomeOverlay:
            return "Same as above, plus a private ~/.cursor and ~/.codex per clone. Needed for apps like ChatGPT that store login/session outside the profile dir — otherwise every clone shares one login. Your real home is fully symlinked in otherwise."
        }
    }

    /// ChatGPT (Codex) keeps its session/login in ~/.codex, outside `--user-data-dir` — clones
    /// need a private ~/.codex or they all share (and log each other out of) one account.
    public static func recommended(for recipeID: String) -> IsolationMode {
        recipeID == ChatGPTRecipe().id ? .fullHomeOverlay : .userDataDir
    }
}

public struct IconSpec: Codable, Equatable, Sendable {
    public var tintHex: String
    public var badge: String
    public var showsBadge: Bool
    public var customImagePNG: Data?

    public init(
        tintHex: String = "#5B8DEF",
        badge: String = "",
        showsBadge: Bool? = nil,
        customImagePNG: Data? = nil
    ) {
        self.tintHex = tintHex
        self.badge = badge
        self.showsBadge = showsBadge ?? !badge.isEmpty
        self.customImagePNG = customImagePNG
    }

    enum CodingKeys: String, CodingKey {
        case tintHex, badge, showsBadge, customImagePNG
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tintHex = try container.decodeIfPresent(String.self, forKey: .tintHex) ?? "#5B8DEF"
        badge = try container.decodeIfPresent(String.self, forKey: .badge) ?? ""
        customImagePNG = try container.decodeIfPresent(Data.self, forKey: .customImagePNG)
        showsBadge = try container.decodeIfPresent(Bool.self, forKey: .showsBadge) ?? !badge.isEmpty
    }

    public static let palette: [String] = [
        "#5B8DEF",
        "#34C759",
        "#FF9F0A",
        "#FF453A",
        "#BF5AF2",
        "#64D2FF",
        "#FF375F",
        "#AC8E68",
    ]
}

public struct Profile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var slug: String
    public var recipeID: String
    public var createdAt: Date
    public var icon: IconSpec
    public var isolation: IsolationMode
    public var installCLIShim: Bool
    public var adoptsDefaultData: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        slug: String? = nil,
        recipeID: String = GrokRecipe().id,
        createdAt: Date = Date(),
        icon: IconSpec = IconSpec(),
        isolation: IsolationMode = .userDataDir,
        installCLIShim: Bool = false,
        adoptsDefaultData: Bool = false
    ) {
        self.id = id
        self.name = name
        self.slug = slug ?? Profile.makeSlug(name)
        self.recipeID = recipeID
        self.createdAt = createdAt
        self.icon = icon
        self.isolation = isolation
        self.installCLIShim = installCLIShim
        self.adoptsDefaultData = adoptsDefaultData
    }

    /// The name you type is the whole Dock app name. We only prefix the app's display name
    /// (e.g. "Grok Bot Personal.app") when you haven't already included it yourself — so
    /// naming a clone "ChatGPT Work" gives you "ChatGPT Work.app", not "ChatGPT ChatGPT Work.app".
    public var wrapperFileName: String {
        let recipe = RecipeRegistry.recipe(id: recipeID)?.displayName ?? "App"
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix(recipe.lowercased()) {
            return "\(trimmed).app"
        }
        return "\(recipe) \(trimmed).app"
    }

    public var wrapperBundleIdentifier: String {
        "\(TwoCursorsPaths.wrapperBundlePrefix).\(recipeID).\(slug)"
    }

    public var cliShimName: String {
        "\(recipeID)-\(slug)"
    }

    public static func makeSlug(_ name: String) -> String {
        let lowered = name.lowercased()
        let mapped = lowered.map { ch -> Character in
            ch.isLetter || ch.isNumber ? ch : "-"
        }
        let collapsed = String(mapped)
            .split(separator: "-")
            .joined(separator: "-")
        return collapsed.isEmpty ? "clone" : collapsed
    }
}

public struct ProfileCatalog: Codable, Equatable, Sendable {
    public var profiles: [Profile]

    public init(profiles: [Profile] = []) {
        self.profiles = profiles
    }
}
