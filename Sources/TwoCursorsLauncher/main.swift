import AppKit
import Darwin
import Foundation
import TwoCursorsCore

@main
enum TwoCursorsLauncherMain {
    static let delegate = LauncherDelegate()

    static func main() {
        let info = Bundle.main.infoDictionary ?? [:]
        let recipeID = info["TwoCursorsRecipeID"] as? String ?? ""
        // Old-style wrappers for a cloning recipe convert themselves on first launch.
        if info[BundleCloner.realExecutableKey] is String
            || RecipeRegistry.recipe(id: recipeID)?.clonesAppBundle == true {
            do {
                try execClonedBundle()
            } catch {
                FileHandle.standardError.write(Data("Lots of Agents launcher: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        applyWrapperIcon()
        IconComposer.removeCustomIconOverride(from: Bundle.main.bundleURL)
        WrapperAppBuilder.refreshLaunchServices(for: Bundle.main.bundleURL)
        app.delegate = delegate
        app.activate(ignoringOtherApps: true)
        app.run()
    }

    static func applyWrapperIcon() {
        let candidates = [
            Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/AppIcon.icns"),
        ]
        for url in candidates {
            guard let url, FileManager.default.fileExists(atPath: url.path),
                  let image = NSImage(contentsOf: url) else { continue }
            NSApplication.shared.applicationIconImage = image
            return
        }
    }

    static func launchProfile() throws -> Int32 {
        let (profile, store, recipe) = try loadProfile()

        let detector = InstalledAppDetector()
        let status = recipe.detect(using: detector)
        guard let executable = status.executableURL, status.isInstalled else {
            throw TwoCursorsError.appNotInstalled(recipe.displayName)
        }

        try store.prepareDirectories(for: profile)
        try CloneLaunchEnvironment.seedIfNeeded(recipe: recipe, profile: profile, store: store)

        let env = try CloneLaunchEnvironment.make(profile: profile, store: store, recipe: recipe)
        let extra = recipe.launchArguments(
            userData: store.userDataURL(for: profile),
            extensions: store.extensionsURL(for: profile)
        ) + Array(CommandLine.arguments.dropFirst())

        return spawnAndWait(executable: executable.path, arguments: extra, environment: env)
    }

    /// Cloned bundle (see `BundleCloner`): rebuild from the official app if it has updated, then
    /// execve the bundle's own copy of the real binary. Same PID and same bundle path, so Launch
    /// Services keeps showing the clone's name and icon — there is no second "ChatGPT" process.
    static func execClonedBundle() throws -> Never {
        let (profile, store, recipe) = try loadProfile()
        var bundle = Bundle.main.bundleURL

        let status = recipe.detect(using: InstalledAppDetector())
        if status.isInstalled, let source = status.appURL,
           !BundleCloner.isCurrent(wrapper: bundle, source: source),
           let launcher = Bundle.main.executableURL {
            do {
                bundle = try WrapperAppBuilder().install(profile: profile, store: store, launcherBinary: launcher)
            } catch {
                // Keep running the copy we have rather than refusing to open.
                FileHandle.standardError.write(Data("Lots of Agents: clone refresh failed: \(error.localizedDescription)\n".utf8))
            }
        }

        guard let info = NSDictionary(contentsOf: bundle.appendingPathComponent("Contents/Info.plist")),
              let real = info[BundleCloner.realExecutableKey] as? String else {
            throw TwoCursorsError.launchFailed("Clone bundle is missing its real executable.")
        }
        let executable = bundle.appendingPathComponent("Contents/MacOS").appendingPathComponent(real).path

        try store.prepareDirectories(for: profile)
        try CloneLaunchEnvironment.seedIfNeeded(recipe: recipe, profile: profile, store: store)
        let env = try CloneLaunchEnvironment.make(profile: profile, store: store, recipe: recipe)
        // The re-signed clone is a different code identity, so the shared "Safe Storage" keychain
        // item would trigger a keychain prompt on every launch and after every rebuild.
        let arguments = recipe.launchArguments(
            userData: store.userDataURL(for: profile),
            extensions: store.extensionsURL(for: profile)
        ) + ["--use-mock-keychain"] + Array(CommandLine.arguments.dropFirst())

        var argv = ([executable] + arguments).map { strdup($0) } + [nil]
        var envp = env.map { strdup("\($0.key)=\($0.value)") } + [nil]
        execve(executable, &argv, &envp)
        throw TwoCursorsError.launchFailed("execve failed: \(String(cString: strerror(errno)))")
    }

    static func loadProfile() throws -> (Profile, ProfileStore, any AppRecipe) {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let profileIDString = info["TwoCursorsProfileID"] as? String,
              let profileID = UUID(uuidString: profileIDString) else {
            throw TwoCursorsError.launchFailed("Wrapper is missing TwoCursorsProfileID.")
        }
        let catalogPath = (info["TwoCursorsCatalog"] as? String)
            ?? TwoCursorsPaths.profilesJSON().path
        let store = try ProfileStore(root: URL(fileURLWithPath: catalogPath).deletingLastPathComponent())
        guard let profile = store.profile(id: profileID) else {
            throw TwoCursorsError.profileNotFound(profileID)
        }
        guard let recipe = RecipeRegistry.recipe(id: profile.recipeID) else {
            throw TwoCursorsError.launchFailed("Unknown recipe \(profile.recipeID).")
        }
        return (profile, store, recipe)
    }

    /// Launch the official app binary as a child process and wait for it to complete.
    ///
    /// Unlike `execve`, this approach preserves the wrapper's Launch Services identity.
    /// The wrapper stays alive (maintaining its CFBundleIdentifier, icon, and name in Cmd-Tab),
    /// while the child process runs the actual Grok Bot / Cursor / Claude / ChatGPT binary.
    ///
    /// We do NOT copy the full .app bundle (which would break helpers, file pickers, updates,
    /// and code signing). We launch the one official binary with custom args/env.
    static func spawnAndWait(executable: String, arguments: [String], environment: [String: String]) -> Int32 {
        var pid: pid_t = 0
        var argv = ([executable] + arguments).map { strdup($0) } + [nil]
        var envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]

        let status = posix_spawn(&pid, executable, nil, nil, &argv, &envp)

        argv.forEach { free($0) }
        envp.forEach { free($0) }

        guard status == 0 else {
            FileHandle.standardError.write(Data("posix_spawn failed: \(String(cString: strerror(status)))\n".utf8))
            return 127
        }

        var childStatus: Int32 = 0
        waitpid(pid, &childStatus, 0)
        return exitCode(fromWaitStatus: childStatus)
    }

    /// Darwin `sys/wait.h` macros (`WIFEXITED`, …) are not imported into Swift.
    private static func exitCode(fromWaitStatus status: Int32) -> Int32 {
        let wstatus = status & 0o177
        if wstatus == 0 {
            return (status >> 8) & 0xff
        }
        if wstatus != 0o177 {
            return 128 + wstatus
        }
        return 1
    }
}

final class LauncherDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let code = try TwoCursorsLauncherMain.launchProfile()
                DispatchQueue.main.async { exit(code) }
            } catch {
                FileHandle.standardError.write(Data("Lots of Agents launcher: \(error.localizedDescription)\n".utf8))
                DispatchQueue.main.async { exit(1) }
            }
        }
    }
}
