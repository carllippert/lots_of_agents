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
        let image = iconImage ?? IconComposer.image(from: profile.icon, base: IconComposer.baseIcon(for: profile.recipeID))
        try IconComposer.writeICNS(spec: profile.icon, to: icns, base: IconComposer.baseIcon(for: profile.recipeID))
        try IconComposer.writeICNS(spec: profile.icon, to: store.iconURL(for: profile), base: IconComposer.baseIcon(for: profile.recipeID))

        let plist: [String: Any] = [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleExecutable": "TwoCursorsLauncher",
            "CFBundleIconFile": "AppIcon",
            "CFBundleIdentifier": profile.wrapperBundleIdentifier,
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": "\(RecipeRegistry.recipe(id: profile.recipeID)?.displayName ?? "App") \(profile.name)",
            "CFBundleDisplayName": "\(RecipeRegistry.recipe(id: profile.recipeID)?.displayName ?? "App") \(profile.name)",
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

        _ = IconComposer.applyFinderIcon(image: image, to: dest)
        adHocSign(dest)
        touch(dest)
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
