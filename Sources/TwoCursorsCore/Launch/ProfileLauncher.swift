import AppKit
import Combine
import Foundation

public struct ProfileLauncher {
    public var fileManager: FileManager
    public var workspace: NSWorkspace

    public init(fileManager: FileManager = .default, workspace: NSWorkspace = .shared) {
        self.fileManager = fileManager
        self.workspace = workspace
    }

    public func launch(
        _ profile: Profile,
        store: ProfileStore,
        recipe: any AppRecipe,
        status: AppStatus,
        preferWrapper: Bool = true
    ) throws {
        guard status.isInstalled, let appURL = status.appURL, let executable = status.executableURL else {
            throw TwoCursorsError.appNotInstalled(recipe.displayName)
        }
        guard status.isExecutable || fileManager.isExecutableFile(atPath: executable.path) else {
            throw TwoCursorsError.executableMissing(executable)
        }

        try store.prepareDirectories(for: profile)
        if recipe.seedsMarketplace {
            try ProfileSeeder.seedUserData(
                at: store.userDataURL(for: profile),
                icon: profile.icon,
                fileManager: fileManager
            )
        } else if recipe.supportsUserDataDir {
            try ProfileSeeder.seedUpdateDisabled(
                at: store.userDataURL(for: profile),
                fileManager: fileManager
            )
        }

        let wrapperURL = TwoCursorsPaths.wrappersDirectory(fileManager: fileManager)
            .appendingPathComponent(profile.wrapperFileName)
        if preferWrapper, fileManager.fileExists(atPath: wrapperURL.path) {
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            config.activates = true
            workspace.openApplication(at: wrapperURL, configuration: config) { _, error in
                if let error {
                    NSLog("TwoCursors wrapper launch failed: \(error.localizedDescription)")
                }
            }
            return
        }

        try launchExecutable(executable, appURL: appURL, profile: profile, store: store, recipe: recipe)
    }

    public func launchExecutable(
        _ executable: URL,
        appURL: URL,
        profile: Profile,
        store: ProfileStore,
        recipe: any AppRecipe
    ) throws {
        let userData = store.userDataURL(for: profile)
        let extensions = store.extensionsURL(for: profile)
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "ELECTRON_RUN_AS_NODE")
        if profile.isolation == .fullHomeOverlay {
            let overlay = store.overlayHomeURL(for: profile)
            try HomeOverlay.prepare(
                overlayRoot: overlay,
                realHome: fileManager.homeDirectoryForCurrentUser,
                fileManager: fileManager
            )
            env["HOME"] = overlay.path
            env["CURSOR_DATA_DIR"] = overlay.appendingPathComponent(".cursor").path
        }

        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.activates = true
        config.arguments = recipe.launchArguments(userData: userData, extensions: extensions)
        config.environment = env
        workspace.openApplication(at: appURL, configuration: config) { _, error in
            if let error {
                NSLog("TwoCursors launch failed: \(error.localizedDescription)")
            }
        }
        _ = executable
    }

    public func quit(profile: Profile, store: ProfileStore) {
        let userData = store.userDataURL(for: profile).path
        let running = NSWorkspace.shared.runningApplications
        for app in running {
            let args = ProcessArguments.arguments(for: app.processIdentifier)
            guard let dir = ProcessArguments.userDataDir(from: args) else { continue }
            if URL(fileURLWithPath: dir).standardizedFileURL
                == URL(fileURLWithPath: userData).standardizedFileURL {
                app.terminate()
            }
        }
    }

    public func openOfficialAppForUpdate(status: AppStatus) throws {
        guard let appURL = status.appURL else {
            throw TwoCursorsError.appNotInstalled(status.displayName)
        }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = false
        config.activates = true
        workspace.openApplication(at: appURL, configuration: config)
    }
}

public enum RunningCloneDetector {
    public static func runningProfileIDs(
        profiles: [Profile],
        store: ProfileStore,
        applications: [RunningApplicationInfo]? = nil
    ) -> Set<UUID> {
        let apps = applications ?? WorkspaceRunningApps().runningApplications()
        var live: Set<UUID> = []
        for app in apps {
            let args = ProcessArguments.arguments(for: app.processIdentifier)
            guard let dir = ProcessArguments.userDataDir(from: args) else { continue }
            let standardized = URL(fileURLWithPath: dir).standardizedFileURL
            for profile in profiles {
                let expected = store.userDataURL(for: profile).standardizedFileURL
                if expected == standardized {
                    live.insert(profile.id)
                }
            }
        }
        return live
    }
}

@MainActor
public final class SignInCoordinator: ObservableObject {
    @Published public private(set) var isSigningIn = false
    @Published public private(set) var profileID: UUID?
    @Published public private(set) var pausedIDs: [UUID] = []
    @Published public private(set) var displayName = "Grok Bot"
    @Published public private(set) var urlScheme = "sand"

    public init() {}

    public func begin(
        profile: Profile,
        store: ProfileStore,
        launcher: ProfileLauncher,
        recipe: any AppRecipe,
        status: AppStatus
    ) throws {
        let live = RunningCloneDetector.runningProfileIDs(profiles: store.profiles, store: store)
        pausedIDs = live.filter { id in
            id != profile.id && store.profile(id: id)?.recipeID == profile.recipeID
        }.sorted { $0.uuidString < $1.uuidString }
        for id in pausedIDs {
            if let other = store.profile(id: id) {
                launcher.quit(profile: other, store: store)
            }
        }
        displayName = recipe.displayName
        urlScheme = recipe.urlSchemes.first ?? "app"
        isSigningIn = true
        profileID = profile.id
        try launcher.launch(profile, store: store, recipe: recipe, status: status)
    }

    public func finish(store: ProfileStore, launcher: ProfileLauncher, detector: InstalledAppDetector) {
        for id in pausedIDs {
            if let other = store.profile(id: id),
               let otherRecipe = RecipeRegistry.recipe(id: other.recipeID) {
                let status = otherRecipe.detect(using: detector)
                try? launcher.launch(other, store: store, recipe: otherRecipe, status: status)
            }
        }
        pausedIDs = []
        isSigningIn = false
        profileID = nil
    }

    public func cancel() {
        pausedIDs = []
        isSigningIn = false
        profileID = nil
    }
}
