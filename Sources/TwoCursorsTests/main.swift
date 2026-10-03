import AppKit
import Foundation
import TwoCursorsCore

@main
enum TwoCursorsTests {
    static var failures = 0

    static func main() {
        if let index = CommandLine.arguments.firstIndex(of: "--refresh-wrappers"),
           CommandLine.arguments.indices.contains(index + 1) {
            refreshInstalledWrappers(launcher: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            return
        }
        detectFixture()
        detectFixtureGrok()
        ignoreWrongBundleID()
        ignoreWrongGrokBundleID()
        runningPID()
        liveCursor()
        liveGrok()
        liveClaude()
        liveChatGPT()
        grokRecipe()
        claudeRecipe()
        chatGPTRecipe()
        detectFixtureClaude()
        detectFixtureChatGPT()
        storeRoundTrip()
        chatGPTForcesFullIsolation()
        wrapperNameDoesNotDoublePrefix()
        uniqueSlugs()
        seedMarketplace()
        seedGrokNoGallery()
        mergeSettings()
        homeOverlay()
        homeOverlayHealsCodexSymlink()
        homeOverlayIsolatesChatGPTSupport()
        rasterizedOfficialIcons()
        chatGPTLaunchEnvironment()
        chatGPTClonesBundle()
        parseFlags()
        ownProcessArgs()
        writeICNS()
        grokMissing()
        slugs()
        if failures == 0 {
            print("All tests passed.")
        } else {
            print("\(failures) test(s) failed.")
            exit(1)
        }
    }

    static func chatGPTClonesBundle() {
        check(ChatGPTRecipe().clonesAppBundle, "ChatGPT clones get their own app bundle")
        check(ClaudeRecipe().clonesAppBundle, "Claude clones get their own app bundle")
        check(GrokRecipe().clonesAppBundle, "Grok clones get their own app bundle")
        check(CursorRecipe().clonesAppBundle, "Cursor clones get their own app bundle")
        check(BundleCloner.isTeamBoundEntitlement("keychain-access-groups"), "drops keychain groups")
        check(BundleCloner.isTeamBoundEntitlement("com.apple.developer.team-identifier"), "drops team ID")
        check(!BundleCloner.isTeamBoundEntitlement("com.apple.security.virtualization"), "keeps virtualization")
        let source: [String: Any] = [
            "CFBundleIdentifier": "com.openai.codex",
            "CFBundleExecutable": "ChatGPT",
            "CFBundleName": "ChatGPT",
            "CFBundleIconName": "Icon",
            "CFBundleIconFile": "electron.icns",
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["codex"]]],
            "SUPublicEDKey": "key",
        ]
        let plist = BundleCloner.cloneInfoPlist(
            source: source,
            bundleIdentifier: "app.lotsofagents.clone.chatgpt.work",
            displayName: "ChatGPT Work",
            extra: ["TwoCursorsProfileID": "x"]
        )
        check(plist["CFBundleIdentifier"] as? String == "app.lotsofagents.clone.chatgpt.work", "clone bundle ID")
        check(plist["CFBundleName"] as? String == "ChatGPT Work", "clone name")
        check(plist["CFBundleExecutable"] as? String == "TwoCursorsLauncher", "launcher is main executable")
        check(plist[BundleCloner.realExecutableKey] as? String == "ChatGPT", "remembers real executable")
        check(plist["CFBundleIconName"] == nil, "asset-catalog icon removed so AppIcon.icns wins")
        check(plist["CFBundleIconFile"] as? String == "AppIcon", "clone icon file")
        check(plist["CFBundleURLTypes"] != nil, "clone keeps URL schemes for the sign-in handoff")
        check(plist["SUEnableAutomaticChecks"] as? Bool == false, "clone does not self-update")
        check(plist["TwoCursorsProfileID"] as? String == "x", "extra keys merged")

        let electron = BundleCloner.cloneInfoPlist(
            source: ["CFBundleName": "Claude", "CFBundleExecutable": "Claude"],
            bundleIdentifier: "app.lotsofagents.clone.claude.personal",
            displayName: "Claude Personal",
            keepsBundleName: true,
            extra: [:]
        )
        check(electron["CFBundleName"] as? String == "Claude", "Electron helper lookup keeps CFBundleName")
        check(electron["CFBundleDisplayName"] as? String == "Claude Personal", "display name still changes")

        let profile = Profile(name: "Work", slug: "work", recipeID: "chatgpt")
        check(profile.wrapperDisplayName == "ChatGPT Work", "display name: \(profile.wrapperDisplayName)")
    }

    static func check(_ condition: Bool, _ message: String, file: String = #fileID, line: Int = #line) {
        if !condition {
            failures += 1
            print("FAIL \(file):\(line) \(message)")
        }
    }

    static func detectFixture() {
        do {
            let root = try makeFixtureCursor()
            let detector = InstalledAppDetector(searchRoots: [root], running: StaticRunningApps([]))
            let status = CursorDetector(detector: detector).status()
            check(status.isInstalled, "fixture should be installed")
            check(status.bundleIdentifier == CursorRecipe.bundleIdentifier, "bundle id")
            check(status.shortVersion == "9.9.9", "short version")
            check(status.buildVersion == "42", "build")
            check(status.isExecutable, "executable")
            check(!status.isRunning, "not running")
        } catch {
            check(false, "detectFixture \(error)")
        }
    }

    static func ignoreWrongBundleID() {
        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("tc-wrong-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root.appendingPathComponent("Cursor.app/Contents/MacOS"), withIntermediateDirectories: true)
            try writePlist([
                "CFBundleIdentifier": "com.example.notcursor",
                "CFBundleShortVersionString": "1.0",
                "CFBundleVersion": "1",
            ], to: root.appendingPathComponent("Cursor.app/Contents/Info.plist"))
            try writeExecutable(root.appendingPathComponent("Cursor.app/Contents/MacOS/Cursor"))
            let detector = InstalledAppDetector(searchRoots: [root], running: StaticRunningApps([]))
            let status = CursorDetector(detector: detector).status()
            check(!status.isInstalled, "wrong bundle id must not match")
        } catch {
            check(false, "ignoreWrongBundleID \(error)")
        }
    }

    static func runningPID() {
        do {
            let root = try makeFixtureCursor()
            let running = StaticRunningApps([
                RunningApplicationInfo(
                    bundleIdentifier: CursorRecipe.bundleIdentifier,
                    processIdentifier: 4242,
                    isActive: true,
                    localizedName: "Cursor"
                ),
            ])
            let detector = InstalledAppDetector(searchRoots: [root], running: running)
            let status = CursorDetector(detector: detector).status()
            check(status.isRunning, "should be running")
            check(status.processIdentifier == 4242, "pid")
        } catch {
            check(false, "runningPID \(error)")
        }
    }

    static func liveCursor() {
        let status = CursorDetector.live()
        if !status.isInstalled {
            print("SKIP liveCursor — Cursor is not installed")
            return
        }
        check(status.bundleIdentifier == CursorRecipe.bundleIdentifier, "live bundle id")
        check(status.isExecutable, "live executable")
        let reallyRunning = WorkspaceRunningApps().runningApplications().contains {
            $0.bundleIdentifier == CursorRecipe.bundleIdentifier
        }
        check(status.isRunning == reallyRunning, "live running flag \(status.isRunning) vs \(reallyRunning)")
        print("LIVE Cursor \(status.versionLabel) installed=\(status.isInstalled) running=\(status.isRunning) path=\(status.appURL?.path ?? "?")")
    }

    static func storeRoundTrip() {
        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("tc-store-\(UUID().uuidString)")
            let store = try ProfileStore(root: root)
            let profile = try store.create(name: "Work", icon: IconSpec(tintHex: "#FF453A", badge: "WORK"))
            check(profile.slug == "work", "slug")
            check(FileManager.default.fileExists(atPath: store.userDataURL(for: profile).path), "user-data dir")
            let reloaded = try ProfileStore(root: root)
            check(reloaded.profiles.first?.name == "Work", "reload name")
            check(reloaded.profiles.first?.icon.badge == "WORK", "reload badge")
            check(reloaded.profiles.first?.icon.showsBadge == true, "badge on when text was set")
            check(reloaded.profiles.first?.recipeID == "grok", "default recipe is grok")
        } catch {
            check(false, "storeRoundTrip \(error)")
        }
    }

    static func chatGPTForcesFullIsolation() {
        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("tc-forced-\(UUID().uuidString)")
            let store = try ProfileStore(root: root)
            let requestedUserDataDir = try store.create(name: "Work", recipeID: "chatgpt", isolation: .userDataDir)
            check(requestedUserDataDir.isolation == .fullHomeOverlay, "create() forces full overlay for chatgpt")

            // Simulate a pre-fix profile written to disk with the broken isolation mode.
            var stale = requestedUserDataDir
            stale.isolation = .userDataDir
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(ProfileCatalog(profiles: [stale]))
            try data.write(to: root.appendingPathComponent("profiles.json"), options: .atomic)

            let reloaded = try ProfileStore(root: root)
            check(reloaded.profiles.first?.isolation == .fullHomeOverlay, "store self-heals stale userDataDir chatgpt profile on load")
        } catch {
            check(false, "chatGPTForcesFullIsolation \(error)")
        }
    }

    static func wrapperNameDoesNotDoublePrefix() {
        let alreadyPrefixed = Profile(name: "ChatGPT Work", recipeID: "chatgpt")
        check(alreadyPrefixed.wrapperFileName == "ChatGPT Work.app", "does not double-prefix: \(alreadyPrefixed.wrapperFileName)")

        let plain = Profile(name: "Personal", recipeID: "grok")
        check(plain.wrapperFileName == "Grok Bot Personal.app", "still prefixes plain names: \(plain.wrapperFileName)")
    }

    static func uniqueSlugs() {
        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("tc-slug-\(UUID().uuidString)")
            let store = try ProfileStore(root: root)
            let a = try store.create(name: "Work")
            let b = try store.create(name: "Work")
            check(a.slug == "work", "first slug")
            check(b.slug.hasPrefix("work-"), "second slug prefix")
            check(a.slug != b.slug, "slugs differ")
        } catch {
            check(false, "uniqueSlugs \(error)")
        }
    }

    static func seedMarketplace() {
        do {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tc-seed-\(UUID().uuidString)")
            try ProfileSeeder.seedUserData(at: dir, icon: IconSpec(tintHex: "#5B8DEF"))
            let object = try JSONSerialization.jsonObject(
                with: Data(contentsOf: dir.appendingPathComponent("User/settings.json"))
            ) as! [String: Any]
            let gallery = object["extensions.gallery"] as! [String: Any]
            check(gallery["serviceUrl"] as? String == ProfileSeeder.marketplaceServiceURL, "marketplace url")
            check(object["update.mode"] as? String == "none", "update.mode none")
        } catch {
            check(false, "seedMarketplace \(error)")
        }
    }

    static func mergeSettings() {
        do {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tc-seed2-\(UUID().uuidString)")
            let user = dir.appendingPathComponent("User", isDirectory: true)
            try FileManager.default.createDirectory(at: user, withIntermediateDirectories: true)
            try #"{ "editor.fontSize": 18 }"#.write(
                to: user.appendingPathComponent("settings.json"),
                atomically: true,
                encoding: .utf8
            )
            try ProfileSeeder.seedUserData(at: dir, icon: IconSpec())
            let object = try JSONSerialization.jsonObject(
                with: Data(contentsOf: user.appendingPathComponent("settings.json"))
            ) as! [String: Any]
            check((object["editor.fontSize"] as? NSNumber)?.intValue == 18, "preserve fontSize")
            check(object["extensions.gallery"] != nil, "fill gallery")
        } catch {
            check(false, "mergeSettings \(error)")
        }
    }

    static func homeOverlay() {
        do {
            let fm = FileManager.default
            let real = fm.temporaryDirectory.appendingPathComponent("tc-real-\(UUID().uuidString)")
            let overlay = fm.temporaryDirectory.appendingPathComponent("tc-over-\(UUID().uuidString)")
            try fm.createDirectory(at: real, withIntermediateDirectories: true)
            try "host=github.com".write(to: real.appendingPathComponent(".gitconfig"), atomically: true, encoding: .utf8)
            try fm.createDirectory(at: real.appendingPathComponent(".ssh"), withIntermediateDirectories: true)
            try fm.createDirectory(at: real.appendingPathComponent(".cursor"), withIntermediateDirectories: true)
            try "global".write(to: real.appendingPathComponent(".cursor/mcp.json"), atomically: true, encoding: .utf8)
            try fm.createDirectory(at: real.appendingPathComponent(".codex"), withIntermediateDirectories: true)
            try "real-login".write(to: real.appendingPathComponent(".codex/auth.json"), atomically: true, encoding: .utf8)
            try HomeOverlay.prepare(overlayRoot: overlay, realHome: real)
            check(HomeOverlay.isFullOverlay(overlayRoot: overlay, realHome: real), "is full overlay")
            let cursor = overlay.appendingPathComponent(".cursor")
            check(!((try cursor.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink ?? false), ".cursor is real")
            check(!fm.fileExists(atPath: cursor.appendingPathComponent("mcp.json").path), "does not copy global mcp")
            let codex = overlay.appendingPathComponent(".codex")
            check(!((try codex.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink ?? false), ".codex is real")
            check(!fm.fileExists(atPath: codex.appendingPathComponent("auth.json").path), "does not share real ChatGPT login")
            check(try String(contentsOf: overlay.appendingPathComponent(".gitconfig")) == "host=github.com", "gitconfig visible")
        } catch {
            check(false, "homeOverlay \(error)")
        }
    }

    static func homeOverlayHealsCodexSymlink() {
        do {
            let fm = FileManager.default
            let real = fm.temporaryDirectory.appendingPathComponent("tc-heal-real-\(UUID().uuidString)")
            let overlay = fm.temporaryDirectory.appendingPathComponent("tc-heal-over-\(UUID().uuidString)")
            try fm.createDirectory(at: real.appendingPathComponent(".codex"), withIntermediateDirectories: true)
            try "real-login".write(to: real.appendingPathComponent(".codex/auth.json"), atomically: true, encoding: .utf8)
            try fm.createDirectory(at: overlay, withIntermediateDirectories: true)
            try fm.createSymbolicLink(
                at: overlay.appendingPathComponent(".codex"),
                withDestinationURL: real.appendingPathComponent(".codex")
            )
            try HomeOverlay.prepare(overlayRoot: overlay, realHome: real)
            let codex = overlay.appendingPathComponent(".codex")
            check(!((try codex.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink ?? false), "healed .codex is real")
            check(!fm.fileExists(atPath: codex.appendingPathComponent("auth.json").path), "does not copy real login when healing")
        } catch {
            check(false, "homeOverlayHealsCodexSymlink \(error)")
        }
    }

    static func homeOverlayIsolatesChatGPTSupport() {
        do {
            let fm = FileManager.default
            let real = fm.temporaryDirectory.appendingPathComponent("tc-gpt-real-\(UUID().uuidString)")
            let overlay = fm.temporaryDirectory.appendingPathComponent("tc-gpt-over-\(UUID().uuidString)")
            let support = real.appendingPathComponent("Library/Application Support", isDirectory: true)
            try fm.createDirectory(at: support.appendingPathComponent("OpenAI/Codex"), withIntermediateDirectories: true)
            try "shared".write(to: support.appendingPathComponent("OpenAI/session"), atomically: true, encoding: .utf8)
            try fm.createDirectory(at: real.appendingPathComponent("Library/Preferences"), withIntermediateDirectories: true)
            try fm.createDirectory(at: real.appendingPathComponent(".codex"), withIntermediateDirectories: true)
            try HomeOverlay.prepare(overlayRoot: overlay, realHome: real, recipeID: ChatGPTRecipe().id)
            check(HomeOverlay.isFullOverlay(overlayRoot: overlay, realHome: real, recipeID: ChatGPTRecipe().id), "chatgpt overlay complete")

            let isolated = overlay.appendingPathComponent("Library/Application Support/OpenAI")
            check(!((try isolated.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink ?? false), "OpenAI support is real")
            check(!fm.fileExists(atPath: isolated.appendingPathComponent("session").path), "does not share official OpenAI session")

            let prefs = overlay.appendingPathComponent("Library/Preferences")
            check((try prefs.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink == true, "Library/Preferences stays a symlink")

            let library = overlay.appendingPathComponent("Library")
            check(!((try library.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink ?? false), "Library is a real split dir")
        } catch {
            check(false, "homeOverlayIsolatesChatGPTSupport \(error)")
        }
    }

    static func rasterizedOfficialIcons() {
        for recipeID in ["grok", "chatgpt", "claude", "cursor"] {
            let app = IconComposer.officialAppURL(for: recipeID)
            guard FileManager.default.fileExists(atPath: app.path) else { continue }
            guard let icon = IconComposer.rasterizedAppIcon(from: app) else {
                check(false, "\(recipeID) rasterized icon missing")
                continue
            }
            check(IconComposer.isUsableIcon(icon), "\(recipeID) rasterized icon is usable")
        }
    }

    static func chatGPTLaunchEnvironment() {
        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("tc-env-\(UUID().uuidString)")
            let store = try ProfileStore(root: root)
            let profile = try store.create(name: "Work", recipeID: "chatgpt")
            let env = try CloneLaunchEnvironment.make(
                profile: profile,
                store: store,
                recipe: ChatGPTRecipe(),
                base: ["ELECTRON_RUN_AS_NODE": "1", "PATH": "/usr/bin"]
            )
            check(env["ELECTRON_RUN_AS_NODE"] == nil, "strips ELECTRON_RUN_AS_NODE")
            check(env["CODEX_HOME"] == store.overlayHomeURL(for: profile).appendingPathComponent(".codex").path, "CODEX_HOME")
            check(env["CODEX_ELECTRON_USER_DATA_PATH"] == store.userDataURL(for: profile).path, "CODEX_ELECTRON_USER_DATA_PATH")
            check(env["HOME"] == store.overlayHomeURL(for: profile).path, "HOME is overlay")
        } catch {
            check(false, "chatGPTLaunchEnvironment \(error)")
        }
    }

    static func parseFlags() {
        check(ProcessArguments.userDataDir(from: ["Cursor", "--user-data-dir=/tmp/a"]) == "/tmp/a", "equals form")
        check(ProcessArguments.userDataDir(from: ["Cursor", "--user-data-dir", "/tmp/b"]) == "/tmp/b", "split form")
        check(ProcessArguments.userDataDir(from: ["Cursor"]) == nil, "missing")
    }

    static func ownProcessArgs() {
        let args = ProcessArguments.arguments(for: ProcessInfo.processInfo.processIdentifier)
        check(!args.isEmpty, "KERN_PROCARGS2 should return argv")
    }

    static func writeICNS() {
        do {
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent("tc-icon-\(UUID().uuidString).icns")
            try IconComposer.writeICNS(spec: IconSpec(tintHex: "#34C759", badge: "WORK"), to: dest)
            let size = (try FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?.intValue ?? 0
            check(size > 100, "icns size \(size)")
        } catch {
            check(false, "writeICNS \(error)")
        }
    }

    static func grokMissing() {
        let detector = InstalledAppDetector(
            searchRoots: [FileManager.default.temporaryDirectory.appendingPathComponent("empty-\(UUID().uuidString)")],
            running: StaticRunningApps([])
        )
        let status = GrokRecipe().detect(using: detector)
        check(status.recipeID == "grok", "recipe id")
        check(!status.isInstalled, "not installed")
    }

    static func detectFixtureGrok() {
        do {
            let root = try makeFixtureGrok()
            let detector = InstalledAppDetector(searchRoots: [root], running: StaticRunningApps([]))
            let status = GrokDetector(detector: detector).status()
            check(status.isInstalled, "fixture Grok Bot should be installed")
            check(status.bundleIdentifier == GrokRecipe.bundleIdentifier, "grok bundle id")
            check(status.bundleIdentifier == "com.anysphere.sand", "must match sand, not display name")
            check(status.shortVersion == "0.16.0", "short version")
            check(status.isExecutable, "executable")
            check(!status.isRunning, "not running")
        } catch {
            check(false, "detectFixtureGrok \(error)")
        }
    }

    static func ignoreWrongGrokBundleID() {
        do {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("tc-wrong-grok-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root.appendingPathComponent("Grok Bot.app/Contents/MacOS"), withIntermediateDirectories: true)
            try writePlist([
                "CFBundleIdentifier": "com.example.notsand",
                "CFBundleShortVersionString": "1.0",
                "CFBundleVersion": "1",
            ], to: root.appendingPathComponent("Grok Bot.app/Contents/Info.plist"))
            try writeExecutable(root.appendingPathComponent("Grok Bot.app/Contents/MacOS/Grok Bot"))
            let detector = InstalledAppDetector(searchRoots: [root], running: StaticRunningApps([]))
            let status = GrokDetector(detector: detector).status()
            check(!status.isInstalled, "wrong Grok bundle id must not match")
        } catch {
            check(false, "ignoreWrongGrokBundleID \(error)")
        }
    }

    static func liveGrok() {
        let status = GrokDetector.live()
        if !status.isInstalled {
            print("SKIP liveGrok — Grok Bot is not installed")
            return
        }
        check(status.bundleIdentifier == GrokRecipe.bundleIdentifier, "live grok bundle id")
        check(status.bundleIdentifier == "com.anysphere.sand", "live sand id")
        check(status.isExecutable, "live grok executable")
        let reallyRunning = WorkspaceRunningApps().runningApplications().contains {
            $0.bundleIdentifier == GrokRecipe.bundleIdentifier
        }
        check(status.isRunning == reallyRunning, "live grok running flag \(status.isRunning) vs \(reallyRunning)")
        print("LIVE Grok Bot \(status.versionLabel) installed=\(status.isInstalled) running=\(status.isRunning) path=\(status.appURL?.path ?? "?")")
    }

    static func grokRecipe() {
        let recipe = GrokRecipe()
        check(recipe.id == "grok", "id")
        check(recipe.requiredBundleIDs == ["com.anysphere.sand"], "bundle ids")
        check(recipe.appFileNames == ["Grok Bot.app"], "app file")
        check(recipe.executableName == "Grok Bot", "exec")
        check(recipe.urlSchemes == ["sand"], "scheme")
        check(!recipe.seedsMarketplace, "no marketplace")
        check(recipe.seedsUpdateDisabled, "grok may seed update.mode")
        check(recipe.supportsUserDataDir, "electron flags")
        check(RecipeRegistry.all.first?.id == "grok", "grok is primary recipe")
        check(RecipeRegistry.all.contains { $0.id == "cursor" }, "cursor still registered")
        check(RecipeRegistry.all.contains { $0.id == "claude" }, "claude registered")
        check(RecipeRegistry.all.contains { $0.id == "chatgpt" }, "chatgpt registered")
    }

    static func chatGPTRecipe() {
        let recipe = ChatGPTRecipe()
        check(recipe.id == "chatgpt", "id")
        check(recipe.requiredBundleIDs == ["com.openai.codex"], "bundle ids")
        check(recipe.appFileNames == ["ChatGPT.app"], "app file")
        check(recipe.executableName == "ChatGPT", "exec")
        check(recipe.urlSchemes == ["codex"], "scheme")
        check(!recipe.seedsMarketplace, "no marketplace")
        check(!recipe.seedsUpdateDisabled, "chatgpt does not get vscode settings")
        check(recipe.supportsUserDataDir, "electron flags")
        check(recipe.forcesFullHomeOverlay, "forces overlay")
    }

    static func detectFixtureChatGPT() {
        do {
            let root = try makeFixtureChatGPT()
            let detector = InstalledAppDetector(searchRoots: [root], running: StaticRunningApps([]))
            let status = ChatGPTDetector(detector: detector).status()
            check(status.isInstalled, "fixture ChatGPT should be installed")
            check(status.bundleIdentifier == ChatGPTRecipe.bundleIdentifier, "chatgpt bundle id")
            check(status.isExecutable, "executable")
        } catch {
            check(false, "detectFixtureChatGPT \(error)")
        }
    }

    static func liveChatGPT() {
        let status = ChatGPTDetector.live()
        if !status.isInstalled {
            print("SKIP liveChatGPT — ChatGPT is not installed")
            return
        }
        check(status.bundleIdentifier == ChatGPTRecipe.bundleIdentifier, "live chatgpt bundle id")
        check(status.bundleIdentifier == "com.openai.codex", "live codex id")
        check(status.isExecutable, "live chatgpt executable")
        let reallyRunning = WorkspaceRunningApps().runningApplications().contains {
            $0.bundleIdentifier == ChatGPTRecipe.bundleIdentifier
        }
        check(status.isRunning == reallyRunning, "live chatgpt running flag \(status.isRunning) vs \(reallyRunning)")
        print("LIVE ChatGPT \(status.versionLabel) installed=\(status.isInstalled) running=\(status.isRunning) path=\(status.appURL?.path ?? "?")")
    }

    static func claudeRecipe() {
        let recipe = ClaudeRecipe()
        check(recipe.id == "claude", "id")
        check(recipe.requiredBundleIDs == ["com.anthropic.claudefordesktop"], "bundle ids")
        check(recipe.appFileNames == ["Claude.app"], "app file")
        check(recipe.executableName == "Claude", "exec")
        check(recipe.urlSchemes == ["claude"], "scheme")
        check(!recipe.seedsMarketplace, "no marketplace")
        check(!recipe.seedsUpdateDisabled, "claude does not get vscode settings")
        check(recipe.supportsUserDataDir, "electron flags")
    }

    static func detectFixtureClaude() {
        do {
            let root = try makeFixtureClaude()
            let detector = InstalledAppDetector(searchRoots: [root], running: StaticRunningApps([]))
            let status = ClaudeDetector(detector: detector).status()
            check(status.isInstalled, "fixture Claude should be installed")
            check(status.bundleIdentifier == ClaudeRecipe.bundleIdentifier, "claude bundle id")
            check(status.isExecutable, "executable")
        } catch {
            check(false, "detectFixtureClaude \(error)")
        }
    }

    static func liveClaude() {
        let status = ClaudeDetector.live()
        if !status.isInstalled {
            print("SKIP liveClaude — Claude is not installed")
            return
        }
        check(status.bundleIdentifier == ClaudeRecipe.bundleIdentifier, "live claude bundle id")
        check(status.isExecutable, "live claude executable")
        let reallyRunning = WorkspaceRunningApps().runningApplications().contains {
            $0.bundleIdentifier == ClaudeRecipe.bundleIdentifier
        }
        check(status.isRunning == reallyRunning, "live claude running flag \(status.isRunning) vs \(reallyRunning)")
        print("LIVE Claude \(status.versionLabel) installed=\(status.isInstalled) running=\(status.isRunning) path=\(status.appURL?.path ?? "?")")
    }

    static func seedGrokNoGallery() {
        do {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tc-grok-seed-\(UUID().uuidString)")
            try ProfileSeeder.seedUpdateDisabled(at: dir)
            let object = try JSONSerialization.jsonObject(
                with: Data(contentsOf: dir.appendingPathComponent("User/settings.json"))
            ) as! [String: Any]
            check(object["update.mode"] as? String == "none", "update.mode none")
            check(object["extensions.gallery"] == nil, "no gallery for grok")
        } catch {
            check(false, "seedGrokNoGallery \(error)")
        }
    }

    static func slugs() {
        check(Profile.makeSlug("Work") == "work", "work")
        check(Profile.makeSlug("Client A") == "client-a", "client")
        check(Profile.makeSlug("!!!") == "clone", "fallback")
    }

    static func refreshInstalledWrappers(launcher: URL) {
        do {
            let store = try ProfileStore()
            let builder = WrapperAppBuilder()
            for profile in store.profiles {
                try store.prepareDirectories(for: profile)
                let image = IconComposer.image(from: profile.icon, base: IconComposer.baseIcon(for: profile.recipeID))
                let dest = try builder.install(profile: profile, store: store, launcherBinary: launcher, iconImage: image)
                print("Refreshed \(dest.path)")
            }
            print("Refreshed \(store.profiles.count) wrapper(s).")
        } catch {
            FileHandle.standardError.write(Data("refresh failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}

struct StaticRunningApps: RunningApplicationSource {
    let apps: [RunningApplicationInfo]
    init(_ apps: [RunningApplicationInfo]) { self.apps = apps }
    func runningApplications() -> [RunningApplicationInfo] { apps }
}

private func makeFixtureCursor() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("tc-cursor-\(UUID().uuidString)")
    let macos = root.appendingPathComponent("Cursor.app/Contents/MacOS")
    try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
    try writePlist([
        "CFBundleIdentifier": CursorRecipe.bundleIdentifier,
        "CFBundleShortVersionString": "9.9.9",
        "CFBundleVersion": "42",
    ], to: root.appendingPathComponent("Cursor.app/Contents/Info.plist"))
    try writeExecutable(macos.appendingPathComponent("Cursor"))
    return root
}

private func makeFixtureGrok() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("tc-grok-\(UUID().uuidString)")
    let macos = root.appendingPathComponent("Grok Bot.app/Contents/MacOS")
    try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
    try writePlist([
        "CFBundleIdentifier": GrokRecipe.bundleIdentifier,
        "CFBundleShortVersionString": "0.16.0",
        "CFBundleVersion": "16",
    ], to: root.appendingPathComponent("Grok Bot.app/Contents/Info.plist"))
    try writeExecutable(macos.appendingPathComponent("Grok Bot"))
    return root
}

private func makeFixtureClaude() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("tc-claude-\(UUID().uuidString)")
    let macos = root.appendingPathComponent("Claude.app/Contents/MacOS")
    try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
    try writePlist([
        "CFBundleIdentifier": ClaudeRecipe.bundleIdentifier,
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": "1",
    ], to: root.appendingPathComponent("Claude.app/Contents/Info.plist"))
    try writeExecutable(macos.appendingPathComponent("Claude"))
    return root
}

private func makeFixtureChatGPT() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("tc-chatgpt-\(UUID().uuidString)")
    let macos = root.appendingPathComponent("ChatGPT.app/Contents/MacOS")
    try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
    try writePlist([
        "CFBundleIdentifier": ChatGPTRecipe.bundleIdentifier,
        "CFBundleShortVersionString": "26.0.0",
        "CFBundleVersion": "26",
    ], to: root.appendingPathComponent("ChatGPT.app/Contents/Info.plist"))
    try writeExecutable(macos.appendingPathComponent("ChatGPT"))
    return root
}

private func writePlist(_ plist: [String: Any], to url: URL) throws {
    try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: url)
}

private func writeExecutable(_ url: URL) throws {
    try "#!/bin/sh\nexit 0\n".write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
}
