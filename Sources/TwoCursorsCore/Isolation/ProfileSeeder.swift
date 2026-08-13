import Foundation

/// Seeds a brand-new Electron user-data dir.
/// Cursor gets the VS Marketplace URL; Grok Bot only disables in-clone Squirrel updates.
public enum ProfileSeeder {
    public static let marketplaceServiceURL = "https://marketplace.visualstudio.com/_apis/public/gallery"
    public static let marketplaceItemURL = "https://marketplace.visualstudio.com/items"

    public static func seedUserData(
        at userData: URL,
        icon: IconSpec,
        fileManager: FileManager = .default
    ) throws {
        let userDir = userData.appendingPathComponent("User", isDirectory: true)
        try fileManager.createDirectory(at: userDir, withIntermediateDirectories: true)
        let settingsURL = userDir.appendingPathComponent("settings.json")
        if fileManager.fileExists(atPath: settingsURL.path) {
            try mergeMarketplace(into: settingsURL)
            return
        }
        let settings: [String: Any] = [
            "update.mode": "none",
            "extensions.autoCheckUpdates": false,
            "extensions.gallery": [
                "serviceUrl": marketplaceServiceURL,
                "itemUrl": marketplaceItemURL,
                "cacheUrl": "https://vscode.blob.core.windows.net/gallery/index",
                "controlUrl": "",
            ],
            "workbench.colorCustomizations": titleBarColors(tintHex: icon.tintHex),
        ]
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settingsURL, options: .atomic)
    }

    /// Grok Bot is Electron + Squirrel, not VS Code. Skip the gallery; still try to
    /// keep the clone from self-updating so the official `/Applications/Grok Bot.app` stays the updater.
    public static func seedUpdateDisabled(
        at userData: URL,
        fileManager: FileManager = .default
    ) throws {
        let userDir = userData.appendingPathComponent("User", isDirectory: true)
        try fileManager.createDirectory(at: userDir, withIntermediateDirectories: true)
        let settingsURL = userDir.appendingPathComponent("settings.json")
        var object: [String: Any] = [:]
        if fileManager.fileExists(atPath: settingsURL.path),
           let data = try? Data(contentsOf: settingsURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            object = existing
        }
        object["update.mode"] = "none"
        object["extensions.autoCheckUpdates"] = false
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settingsURL, options: .atomic)
    }

    public static func mergeMarketplace(into settingsURL: URL) throws {
        let data = try Data(contentsOf: settingsURL)
        var object = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        if object["extensions.gallery"] == nil {
            object["extensions.gallery"] = [
                "serviceUrl": marketplaceServiceURL,
                "itemUrl": marketplaceItemURL,
            ]
        }
        let out = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: settingsURL, options: .atomic)
    }

    public static func titleBarColors(tintHex: String) -> [String: String] {
        [
            "titleBar.activeBackground": tintHex,
            "titleBar.inactiveBackground": tintHex,
            "titleBar.activeForeground": "#FFFFFF",
            "statusBar.background": tintHex,
            "statusBar.foreground": "#FFFFFF",
            "activityBar.background": tintHex,
        ]
    }
}
