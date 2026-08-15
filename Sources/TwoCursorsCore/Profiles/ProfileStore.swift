import Foundation

public final class ProfileStore {
    public private(set) var profiles: [Profile]
    public let fileManager: FileManager
    public let root: URL
    public let catalogURL: URL

    public init(
        fileManager: FileManager = .default,
        root: URL? = nil
    ) throws {
        self.fileManager = fileManager
        self.root = root ?? TwoCursorsPaths.applicationSupport(fileManager: fileManager)
        self.catalogURL = self.root.appendingPathComponent("profiles.json")
        if root == nil {
            Self.migrateFromEnvironmentHomeIfNeeded(to: self.root, fileManager: fileManager)
        }
        try fileManager.createDirectory(at: self.root, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: catalogURL.path) {
            let data = try Data(contentsOf: catalogURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let catalog = try decoder.decode(ProfileCatalog.self, from: data)
            self.profiles = catalog.profiles
        } else {
            self.profiles = []
            try persist()
        }
    }

    public func profile(id: UUID) -> Profile? {
        profiles.first { $0.id == id }
    }

    @discardableResult
    public func create(
        name: String,
        recipeID: String = GrokRecipe().id,
        icon: IconSpec = IconSpec(),
        isolation: IsolationMode = .userDataDir,
        installCLIShim: Bool = false,
        adoptsDefaultData: Bool = false
    ) throws -> Profile {
        var slug = Profile.makeSlug(name)
        if profiles.contains(where: { $0.slug == slug && $0.recipeID == recipeID }) {
            slug += "-\(UUID().uuidString.prefix(4).lowercased())"
        }
        var profile = Profile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            slug: slug,
            recipeID: recipeID,
            icon: icon,
            isolation: isolation,
            installCLIShim: installCLIShim,
            adoptsDefaultData: adoptsDefaultData
        )
        if profile.name.isEmpty {
            profile.name = "Untitled"
            profile.slug = Profile.makeSlug(profile.name) + "-\(UUID().uuidString.prefix(4).lowercased())"
        }
        try prepareDirectories(for: profile)
        profiles.append(profile)
        try persist()
        return profile
    }

    public func update(_ profile: Profile) throws {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            throw TwoCursorsError.profileNotFound(profile.id)
        }
        profiles[index] = profile
        try persist()
    }

    public func delete(_ id: UUID, removeData: Bool = true) throws {
        guard let profile = profile(id: id) else {
            throw TwoCursorsError.profileNotFound(id)
        }
        profiles.removeAll { $0.id == id }
        try persist()
        if removeData {
            let dir = profileRoot(for: profile)
            if fileManager.fileExists(atPath: dir.path) {
                try fileManager.removeItem(at: dir)
            }
        }
    }

    public func persist() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(ProfileCatalog(profiles: profiles))
        try data.write(to: catalogURL, options: .atomic)
    }

    public func profileRoot(for profile: Profile) -> URL {
        root.appendingPathComponent("Profiles", isDirectory: true)
            .appendingPathComponent(profile.id.uuidString, isDirectory: true)
    }

    public func userDataURL(for profile: Profile) -> URL {
        if profile.adoptsDefaultData {
            return TwoCursorsPaths.accountHome(fileManager: fileManager)
                .appendingPathComponent("Library/Application Support/Cursor", isDirectory: true)
        }
        return profileRoot(for: profile).appendingPathComponent("user-data", isDirectory: true)
    }

    public func extensionsURL(for profile: Profile) -> URL {
        profileRoot(for: profile).appendingPathComponent("extensions", isDirectory: true)
    }

    public func overlayHomeURL(for profile: Profile) -> URL {
        profileRoot(for: profile).appendingPathComponent("home", isDirectory: true)
    }

    public func iconURL(for profile: Profile) -> URL {
        profileRoot(for: profile).appendingPathComponent("icon.icns")
    }

    public func prepareDirectories(for profile: Profile) throws {
        let rootDir = profileRoot(for: profile)
        try fileManager.createDirectory(at: userDataURL(for: profile), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: extensionsURL(for: profile), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: rootDir, withIntermediateDirectories: true)
        if profile.isolation == .fullHomeOverlay {
            try HomeOverlay.prepare(
                overlayRoot: overlayHomeURL(for: profile),
                realHome: TwoCursorsPaths.accountHome(fileManager: fileManager),
                fileManager: fileManager
            )
        }
    }

    /// If an earlier launch ran inside a fake `$HOME` (Parall), pull that catalog into the real account home.
    /// Runs when the real catalog is missing or empty but the environment-home catalog has clones.
    private static func migrateFromEnvironmentHomeIfNeeded(to canonical: URL, fileManager: FileManager) {
        let misplaced = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/LotsOfAgents", isDirectory: true)
        guard misplaced.standardizedFileURL != canonical.standardizedFileURL else { return }
        let sourceCatalog = misplaced.appendingPathComponent("profiles.json")
        guard fileManager.fileExists(atPath: sourceCatalog.path) else { return }

        let destCatalog = canonical.appendingPathComponent("profiles.json")
        let destNeedsImport: Bool = {
            guard fileManager.fileExists(atPath: destCatalog.path),
                  let data = try? Data(contentsOf: destCatalog),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let profiles = object["profiles"] as? [Any] else {
                return true
            }
            return profiles.isEmpty
        }()
        guard destNeedsImport else { return }

        let sourceHasProfiles: Bool = {
            guard let data = try? Data(contentsOf: sourceCatalog),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let profiles = object["profiles"] as? [Any] else { return false }
            return !profiles.isEmpty
        }()
        guard sourceHasProfiles else { return }

        try? fileManager.createDirectory(at: canonical, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: destCatalog)
        try? fileManager.copyItem(at: sourceCatalog, to: destCatalog)

        let sourceProfiles = misplaced.appendingPathComponent("Profiles", isDirectory: true)
        let destProfiles = canonical.appendingPathComponent("Profiles", isDirectory: true)
        guard fileManager.fileExists(atPath: sourceProfiles.path) else { return }
        try? fileManager.createDirectory(at: destProfiles, withIntermediateDirectories: true)
        if let children = try? fileManager.contentsOfDirectory(at: sourceProfiles, includingPropertiesForKeys: nil) {
            for child in children {
                let dest = destProfiles.appendingPathComponent(child.lastPathComponent)
                if fileManager.fileExists(atPath: dest.path) { try? fileManager.removeItem(at: dest) }
                try? fileManager.copyItem(at: child, to: dest)
            }
        }
    }
}
