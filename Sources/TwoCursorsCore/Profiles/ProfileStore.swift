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
            return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Cursor", isDirectory: true)
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
                realHome: fileManager.homeDirectoryForCurrentUser,
                fileManager: fileManager
            )
        }
    }
}
