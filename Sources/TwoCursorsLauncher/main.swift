import Darwin
import Foundation
import TwoCursorsCore

@main
enum TwoCursorsLauncherMain {
    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("Lots of Agents launcher: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    static func run() throws {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let profileIDString = info["TwoCursorsProfileID"] as? String,
              let profileID = UUID(uuidString: profileIDString) else {
            throw TwoCursorsError.launchFailed("Wrapper is missing TwoCursorsProfileID.")
        }

        let catalogPath = (info["TwoCursorsCatalog"] as? String)
            ?? TwoCursorsPaths.profilesJSON().path
        let catalogURL = URL(fileURLWithPath: catalogPath)
        let storeRoot = catalogURL.deletingLastPathComponent()
        let store = try ProfileStore(root: storeRoot)
        guard let profile = store.profile(id: profileID) else {
            throw TwoCursorsError.profileNotFound(profileID)
        }
        guard let recipe = RecipeRegistry.recipe(id: profile.recipeID) else {
            throw TwoCursorsError.launchFailed("Unknown recipe \(profile.recipeID).")
        }

        let detector = InstalledAppDetector()
        let status = recipe.detect(using: detector)
        guard let executable = status.executableURL, status.isInstalled else {
            throw TwoCursorsError.appNotInstalled(recipe.displayName)
        }

        try store.prepareDirectories(for: profile)
        if recipe.seedsMarketplace {
            try ProfileSeeder.seedUserData(at: store.userDataURL(for: profile), icon: profile.icon)
        } else if recipe.supportsUserDataDir {
            try ProfileSeeder.seedUpdateDisabled(at: store.userDataURL(for: profile))
        }

        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "ELECTRON_RUN_AS_NODE")
        if profile.isolation == .fullHomeOverlay {
            let overlay = store.overlayHomeURL(for: profile)
            try HomeOverlay.prepare(overlayRoot: overlay, realHome: TwoCursorsPaths.accountHome())
            env["HOME"] = overlay.path
            env["CURSOR_DATA_DIR"] = overlay.appendingPathComponent(".cursor").path
        }

        let extra = recipe.launchArguments(
            userData: store.userDataURL(for: profile),
            extensions: store.extensionsURL(for: profile)
        ) + Array(CommandLine.arguments.dropFirst())

        exec(executable: executable.path, arguments: extra, environment: env)
    }

    static func exec(executable: String, arguments: [String], environment: [String: String]) -> Never {
        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        execve(executable, argv, envp)
        perror("execve")
        exit(127)
    }
}
