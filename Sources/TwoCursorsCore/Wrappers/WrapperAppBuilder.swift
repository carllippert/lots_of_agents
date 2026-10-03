import AppKit
import Foundation

public struct WrapperAppBuilder {
    public var fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func wrapperURL(for profile: Profile) -> URL {
        TwoCursorsPaths.wrappersDirectory(fileManager: fileManager)
            .appendingPathComponent(profile.wrapperFileName)
    }

    public func install(
        profile: Profile,
        store: ProfileStore,
        launcherBinary: URL,
        iconImage: NSImage? = nil
    ) throws -> URL {
        let apps = TwoCursorsPaths.wrappersDirectory(fileManager: fileManager)
        try fileManager.createDirectory(at: apps, withIntermediateDirectories: true)
        let dest = wrapperURL(for: profile)
        if fileManager.fileExists(atPath: dest.path) {
            try refresh(profile: profile, store: store, at: dest, launcherBinary: launcherBinary, iconImage: iconImage)
            return dest
        }
        try writeBundle(profile: profile, store: store, at: dest, launcherBinary: launcherBinary, iconImage: iconImage)
        return dest
    }

    public func refresh(
        profile: Profile,
        store: ProfileStore,
        at dest: URL,
        launcherBinary: URL,
        iconImage: NSImage?
    ) throws {
        try writeBundle(profile: profile, store: store, at: dest, launcherBinary: launcherBinary, iconImage: iconImage)
    }

    public func remove(profile: Profile) throws {
        let dest = wrapperURL(for: profile)
        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
    }

    public func rename(from old: Profile, to new: Profile, store: ProfileStore, launcherBinary: URL, iconImage: NSImage?) throws {
        let oldURL = wrapperURL(for: old)
        let newURL = wrapperURL(for: new)
        if oldURL != newURL, fileManager.fileExists(atPath: oldURL.path) {
            try? fileManager.removeItem(at: oldURL)
        }
        try writeBundle(profile: new, store: store, at: newURL, launcherBinary: launcherBinary, iconImage: iconImage)
    }

    private func writeBundle(
        profile: Profile,
        store: ProfileStore,
        at dest: URL,
        launcherBinary: URL,
        iconImage: NSImage?
    ) throws {
        guard fileManager.isExecutableFile(atPath: launcherBinary.path) else {
            throw TwoCursorsError.wrapperFailed("Launcher binary missing at \(launcherBinary.path)")
        }

        if let recipe = RecipeRegistry.recipe(id: profile.recipeID), recipe.clonesAppBundle {
            try writeClonedBundle(profile: profile, store: store, recipe: recipe, at: dest, launcherBinary: launcherBinary)
            return
        }

        let contents = dest.appendingPathComponent("Contents")
        let macos = contents.appendingPathComponent("MacOS")
        let resources = contents.appendingPathComponent("Resources")
        try fileManager.createDirectory(at: macos, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)

        let execDest = macos.appendingPathComponent("TwoCursorsLauncher")
        if fileManager.fileExists(atPath: execDest.path) {
            try fileManager.removeItem(at: execDest)
        }
        try fileManager.copyItem(at: launcherBinary, to: execDest)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: execDest.path)

        let icns = resources.appendingPathComponent("AppIcon.icns")
        let base = IconComposer.baseIcon(for: profile.recipeID)
        try IconComposer.writeICNS(spec: profile.icon, to: icns, base: base)
        try IconComposer.writeICNS(spec: profile.icon, to: store.iconURL(for: profile), base: base)

        let plist: [String: Any] = [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleExecutable": "TwoCursorsLauncher",
            "CFBundleIconFile": "AppIcon",
            "CFBundleIconName": "AppIcon",
            "CFBundleIdentifier": profile.wrapperBundleIdentifier,
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": profile.wrapperDisplayName,
            "CFBundleDisplayName": profile.wrapperDisplayName,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "LSMinimumSystemVersion": "14.0",
            "NSHighResolutionCapable": true,
            "LSUIElement": false,
            "TwoCursorsProfileID": profile.id.uuidString,
            "TwoCursorsRecipeID": profile.recipeID,
            "TwoCursorsCatalog": store.catalogURL.path,
        ]
        let plistURL = contents.appendingPathComponent("Info.plist")
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)

        IconComposer.removeCustomIconOverride(from: dest, fileManager: fileManager)
        adHocSign(dest)
        touch(dest)
        Self.refreshLaunchServices(for: dest)
    }

    private func writeClonedBundle(
        profile: Profile,
        store: ProfileStore,
        recipe: any AppRecipe,
        at dest: URL,
        launcherBinary: URL
    ) throws {
        // Never swap the bundle out from under a running clone; it picks up changes next launch.
        if fileManager.fileExists(atPath: dest.path),
           NSRunningApplication.runningApplications(withBundleIdentifier: profile.wrapperBundleIdentifier)
               .contains(where: { $0.processIdentifier != getpid() }) {
            return
        }
        let status = recipe.detect(using: InstalledAppDetector())
        guard status.isInstalled, let source = status.appURL else {
            throw TwoCursorsError.appNotInstalled(recipe.displayName)
        }
        let base = IconComposer.baseIcon(for: profile.recipeID)
        try IconComposer.writeICNS(spec: profile.icon, to: store.iconURL(for: profile), base: base)
        try BundleCloner(fileManager: fileManager).build(
            source: source,
            dest: dest,
            bundleIdentifier: profile.wrapperBundleIdentifier,
            displayName: profile.wrapperDisplayName,
            launcherBinary: launcherBinary,
            writeIcon: { try IconComposer.writeICNS(spec: profile.icon, to: $0, base: base) },
            extraInfo: [
                "TwoCursorsProfileID": profile.id.uuidString,
                "TwoCursorsRecipeID": profile.recipeID,
                "TwoCursorsCatalog": store.catalogURL.path,
            ]
        )
        IconComposer.removeCustomIconOverride(from: dest, fileManager: fileManager)
        touch(dest)
        Self.refreshLaunchServices(for: dest)
    }

    public static func refreshLaunchServices(for appURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister")
        process.arguments = ["-f", "-R", appURL.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }

    public static func locateLauncherBinary() -> URL? {
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/TwoCursorsLauncher")
        if FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        if let sibling = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("TwoCursorsLauncher"),
           FileManager.default.isExecutableFile(atPath: sibling.path) {
            return sibling
        }
        return nil
    }

    private func adHocSign(_ app: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--sign", "-", "--deep", app.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }

    private func touch(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/touch")
        process.arguments = [url.path]
        try? process.run()
        process.waitUntilExit()
    }
}
