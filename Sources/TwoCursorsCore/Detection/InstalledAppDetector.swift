import AppKit
import Foundation

public struct WorkspaceRunningApps: RunningApplicationSource {
    public init() {}

    public func runningApplications() -> [RunningApplicationInfo] {
        NSWorkspace.shared.runningApplications.map { app in
            RunningApplicationInfo(
                bundleIdentifier: app.bundleIdentifier,
                processIdentifier: app.processIdentifier,
                isActive: app.isActive,
                localizedName: app.localizedName,
                bundleURL: app.bundleURL
            )
        }
    }
}

public struct InstalledAppDetector {
    public var searchRoots: [URL]
    public var fileManager: FileManager
    public var running: RunningApplicationSource

    public init(
        searchRoots: [URL]? = nil,
        fileManager: FileManager = .default,
        running: RunningApplicationSource = WorkspaceRunningApps()
    ) {
        self.searchRoots = searchRoots ?? TwoCursorsPaths.standardAppSearchRoots(fileManager: fileManager)
        self.fileManager = fileManager
        self.running = running
    }

    public func detect(
        recipeID: String,
        displayName: String,
        appFileNames: [String],
        requiredBundleIDs: [String],
        executableName: String
    ) -> AppStatus {
        var status = AppStatus(recipeID: recipeID, displayName: displayName)

        for root in searchRoots {
            for name in appFileNames {
                let appURL = root.appendingPathComponent(name, isDirectory: true)
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: appURL.path, isDirectory: &isDir), isDir.boolValue else {
                    continue
                }
                let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
                guard let plist = NSDictionary(contentsOf: plistURL) as? [String: Any] else {
                    continue
                }
                let bundleID = plist["CFBundleIdentifier"] as? String
                if !requiredBundleIDs.isEmpty {
                    guard let bundleID, requiredBundleIDs.contains(bundleID) else { continue }
                }

                let executableURL = appURL
                    .appendingPathComponent("Contents/MacOS", isDirectory: true)
                    .appendingPathComponent(executableName)

                status.isInstalled = true
                status.appURL = appURL
                status.executableURL = executableURL
                status.bundleIdentifier = bundleID
                status.shortVersion = plist["CFBundleShortVersionString"] as? String
                if let build = plist["CFBundleVersion"] as? String {
                    status.buildVersion = build
                }
                status.isExecutable = fileManager.isExecutableFile(atPath: executableURL.path)
                break
            }
            if status.isInstalled { break }
        }

        let ids = requiredBundleIDs.isEmpty
            ? [status.bundleIdentifier].compactMap { $0 }
            : requiredBundleIDs
        if let match = running.runningApplications().first(where: { info in
            guard let bid = info.bundleIdentifier else { return false }
            return ids.contains(bid)
        }) {
            status.isRunning = true
            status.processIdentifier = match.processIdentifier
            status.isActive = match.isActive
            status.localizedName = match.localizedName
        }

        return status
    }
}
