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

        spawnAndWait(executable: executable.path, arguments: extra, environment: env)
    }

    /// Launch the official app binary as a child process and wait for it to complete.
    ///
    /// Unlike `execve`, this approach preserves the wrapper's Launch Services identity.
    /// The wrapper stays alive (maintaining its CFBundleIdentifier, icon, and name in Cmd-Tab),
    /// while the child process runs the actual Grok Bot / Cursor / Claude / ChatGPT binary.
    ///
    /// This ensures:
    /// - The Cmd-Tab switcher shows the wrapper's custom icon and name (e.g. "Grok Bot Personal")
    /// - Multiple clones appear as separate apps in the switcher
    /// - The wrapper's bundle ID (e.g. app.lotsofagents.clone.grok.personal) is preserved
    /// - All user-data-dir isolation and profile behavior continues to work
    ///
    /// We do NOT copy the full .app bundle (which would break helpers, file pickers, updates,
    /// and code signing). We launch the one official binary with custom args/env.
    static func spawnAndWait(executable: String, arguments: [String], environment: [String: String]) -> Never {
        var pid: pid_t = 0
        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        
        var attrs: posix_spawnattr_t?
        posix_spawnattr_init(&attrs)
        defer { 
            if let attrs = attrs {
                posix_spawnattr_destroy(&attrs)
            }
        }
        
        let status = posix_spawn(&pid, executable, nil, attrs, argv, envp)
        
        argv.forEach { free($0) }
        envp.forEach { free($0) }
        
        guard status == 0 else {
            FileHandle.standardError.write(Data("posix_spawn failed: \(String(cString: strerror(status)))\n".utf8))
            exit(127)
        }
        
        var childStatus: Int32 = 0
        waitpid(pid, &childStatus, 0)
        
        if WIFEXITED(childStatus) {
            exit(WEXITSTATUS(childStatus))
        } else if WIFSIGNALED(childStatus) {
            exit(128 + WTERMSIG(childStatus))
        } else {
            exit(1)
        }
    }
}
