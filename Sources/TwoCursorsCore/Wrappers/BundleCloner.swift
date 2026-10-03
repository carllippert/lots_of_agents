import Foundation

/// Builds a per-clone copy of the official app bundle with its own Launch Services identity.
///
/// The copy is an APFS clone (`cp -c`), so it costs almost no disk space. Only `Info.plist`,
/// the icon, the launcher, and the re-signed main executable diverge from the source.
///
/// Layout of a cloned wrapper:
/// ```
/// ChatGPT Work.app/Contents/
///   Info.plist                 # clone bundle ID / name / icon, CFBundleExecutable = TwoCursorsLauncher
///   MacOS/TwoCursorsLauncher   # sets up HOME overlay, then execve's the real binary below
///   MacOS/ChatGPT              # official binary, ad-hoc re-signed (the seal no longer matches)
///   Resources/AppIcon.icns     # tinted clone icon
///   Frameworks/...             # untouched clones of the official frameworks
/// ```
///
/// Because the launcher execve's (same PID, same bundle path), macOS sees exactly one app per
/// clone: Spotlight, Dock, Cmd-Tab, and the menu bar all show the clone's name and icon.
///
/// Updates: the clone's own Sparkle updater is disabled (it would overwrite the clone with the
/// stock app). The official app in /Applications keeps updating itself; the launcher rebuilds the
/// clone from it whenever the source version changes.
public struct BundleCloner {
    public static let sourceAppKey = "TwoCursorsSourceApp"
    public static let sourceVersionKey = "TwoCursorsSourceVersion"
    public static let realExecutableKey = "TwoCursorsRealExecutable"

    public var fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Version stamp of an app bundle, used to detect when the source app has updated.
    public static func versionStamp(of appURL: URL) -> String? {
        guard let info = NSDictionary(contentsOf: appURL.appendingPathComponent("Contents/Info.plist")) else {
            return nil
        }
        let short = info["CFBundleShortVersionString"] as? String ?? ""
        let build = info["CFBundleVersion"] as? String ?? ""
        return "\(short) (\(build))"
    }

    /// True when `wrapper` is a cloned bundle built from the current version of `source`.
    public static func isCurrent(wrapper: URL, source: URL) -> Bool {
        guard let info = NSDictionary(contentsOf: wrapper.appendingPathComponent("Contents/Info.plist")),
              let stamp = info[sourceVersionKey] as? String,
              let real = info[realExecutableKey] as? String else {
            return false
        }
        let exec = wrapper.appendingPathComponent("Contents/MacOS").appendingPathComponent(real)
        return stamp == versionStamp(of: source) && FileManager.default.isExecutableFile(atPath: exec.path)
    }

    /// Rewrites the official Info.plist into the clone's identity.
    public static func cloneInfoPlist(
        source: [String: Any],
        bundleIdentifier: String,
        displayName: String,
        extra: [String: Any]
    ) -> [String: Any] {
        var plist = source
        let realExecutable = source["CFBundleExecutable"] as? String ?? ""
        plist["CFBundleIdentifier"] = bundleIdentifier
        plist["CFBundleName"] = displayName
        plist["CFBundleDisplayName"] = displayName
        plist["CFBundleExecutable"] = "TwoCursorsLauncher"
        plist["CFBundleIconFile"] = "AppIcon"
        // CFBundleIconName points at the official Assets.car icon and wins over CFBundleIconFile.
        plist.removeValue(forKey: "CFBundleIconName")
        // Leave codex:// links to the official app; clones would otherwise race for them.
        plist.removeValue(forKey: "CFBundleURLTypes")
        plist["SUEnableAutomaticChecks"] = false
        plist["SUAutomaticallyUpdate"] = false
        plist["SUAllowsAutomaticUpdates"] = false
        plist[realExecutableKey] = realExecutable
        for (key, value) in extra {
            plist[key] = value
        }
        return plist
    }

    /// Builds the clone at `dest`, replacing whatever is there.
    public func build(
        source: URL,
        dest: URL,
        bundleIdentifier: String,
        displayName: String,
        launcherBinary: URL,
        writeIcon: (URL) throws -> Void,
        extraInfo: [String: Any]
    ) throws {
        let parent = dest.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".\(dest.lastPathComponent).building-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: staging) }

        try run("/bin/cp", ["-c", "-R", source.path, staging.path])

        let contents = staging.appendingPathComponent("Contents")
        let macos = contents.appendingPathComponent("MacOS")
        let plistURL = contents.appendingPathComponent("Info.plist")
        guard let sourceInfo = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let realExecutable = sourceInfo["CFBundleExecutable"] as? String else {
            throw TwoCursorsError.wrapperFailed("Could not read \(source.lastPathComponent) Info.plist")
        }

        var extra = extraInfo
        extra[Self.sourceAppKey] = source.path
        extra[Self.sourceVersionKey] = Self.versionStamp(of: source) ?? ""
        let plist = Self.cloneInfoPlist(
            source: sourceInfo,
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            extra: extra
        )
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)

        try writeIcon(contents.appendingPathComponent("Resources/AppIcon.icns"))

        // Sparkle replaces the host bundle in place; in a clone that would install the stock app
        // over the clone. Strip the installer pieces from the clone only (source stays intact).
        let sparkle = contents.appendingPathComponent("Frameworks/Sparkle.framework/Versions/Current")
        for name in ["Autoupdate", "Updater.app", "XPCServices/Installer.xpc"] {
            try? fileManager.removeItem(at: sparkle.appendingPathComponent(name))
        }

        let launcherDest = macos.appendingPathComponent("TwoCursorsLauncher")
        try? fileManager.removeItem(at: launcherDest)
        try fileManager.copyItem(at: launcherBinary, to: launcherDest)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: launcherDest.path)

        // The official signature seals Info.plist, so the edited copy will not launch under it.
        // Ad-hoc re-sign the main executable without hardened runtime (no library validation, so
        // the untouched, officially signed frameworks still load).
        try run("/usr/bin/codesign", ["--force", "--sign", "-", macos.appendingPathComponent(realExecutable).path])
        try run("/usr/bin/codesign", ["--force", "--sign", "-", launcherDest.path])

        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        try fileManager.moveItem(at: staging, to: dest)
    }

    private func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let err = Pipe()
        process.standardOutput = Pipe()
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw TwoCursorsError.wrapperFailed("\(tool) failed: \(message)")
        }
    }
}
