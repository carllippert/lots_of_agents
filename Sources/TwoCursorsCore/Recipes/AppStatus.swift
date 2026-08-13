import Foundation

public struct AppStatus: Equatable, Sendable {
    public var recipeID: String
    public var displayName: String
    public var isInstalled: Bool
    public var appURL: URL?
    public var executableURL: URL?
    public var bundleIdentifier: String?
    public var shortVersion: String?
    public var buildVersion: String?
    public var isExecutable: Bool
    public var isRunning: Bool
    public var processIdentifier: Int32?
    public var isActive: Bool
    public var localizedName: String?

    public init(
        recipeID: String,
        displayName: String,
        isInstalled: Bool = false,
        appURL: URL? = nil,
        executableURL: URL? = nil,
        bundleIdentifier: String? = nil,
        shortVersion: String? = nil,
        buildVersion: String? = nil,
        isExecutable: Bool = false,
        isRunning: Bool = false,
        processIdentifier: Int32? = nil,
        isActive: Bool = false,
        localizedName: String? = nil
    ) {
        self.recipeID = recipeID
        self.displayName = displayName
        self.isInstalled = isInstalled
        self.appURL = appURL
        self.executableURL = executableURL
        self.bundleIdentifier = bundleIdentifier
        self.shortVersion = shortVersion
        self.buildVersion = buildVersion
        self.isExecutable = isExecutable
        self.isRunning = isRunning
        self.processIdentifier = processIdentifier
        self.isActive = isActive
        self.localizedName = localizedName
    }

    public var versionLabel: String {
        if let shortVersion, let buildVersion {
            return "\(shortVersion) (\(buildVersion))"
        }
        return shortVersion ?? buildVersion ?? "Unknown"
    }
}

public struct RunningApplicationInfo: Equatable, Sendable {
    public var bundleIdentifier: String?
    public var processIdentifier: Int32
    public var isActive: Bool
    public var localizedName: String?
    public var bundleURL: URL?

    public init(
        bundleIdentifier: String?,
        processIdentifier: Int32,
        isActive: Bool,
        localizedName: String?,
        bundleURL: URL? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.isActive = isActive
        self.localizedName = localizedName
        self.bundleURL = bundleURL
    }
}

public protocol RunningApplicationSource {
    func runningApplications() -> [RunningApplicationInfo]
}
