import Foundation

public struct CLIShimInstaller {
    public var fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func install(profile: Profile, store: ProfileStore, recipe: any AppRecipe, status: AppStatus) throws -> URL {
        guard let executable = status.executableURL else {
            throw TwoCursorsError.appNotInstalled(recipe.displayName)
        }
        let bin = TwoCursorsPaths.cliBin(fileManager: fileManager)
        try fileManager.createDirectory(at: bin, withIntermediateDirectories: true)
        let shim = bin.appendingPathComponent(profile.cliShimName)
        let userData = store.userDataURL(for: profile).path
        let extensions = store.extensionsURL(for: profile).path
        var exports: [String] = []
        if profile.isolation == .fullHomeOverlay {
            let home = store.overlayHomeURL(for: profile).path
            exports.append("export HOME=\"\(home)\"")
            exports.append("export CURSOR_DATA_DIR=\"\(home)/.cursor\"")
        }
        if recipe.id == ChatGPTRecipe().id {
            let home = profile.isolation == .fullHomeOverlay
                ? store.overlayHomeURL(for: profile).path
                : TwoCursorsPaths.accountHome(fileManager: fileManager).path
            exports.append("export CODEX_HOME=\"\(home)/.codex\"")
            exports.append("export CODEX_ELECTRON_USER_DATA_PATH=\"\(userData)\"")
        }
        let exportBlock = exports.isEmpty ? "" : exports.joined(separator: "\n") + "\n"
        let script = """
        #!/bin/sh
        \(exportBlock)exec "\(executable.path)" --user-data-dir="\(userData)" --extensions-dir="\(extensions)" "$@"
        """
        try script.write(to: shim, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: shim.path)
        return shim
    }

    public func remove(profile: Profile) throws {
        let shim = TwoCursorsPaths.cliBin(fileManager: fileManager).appendingPathComponent(profile.cliShimName)
        if fileManager.fileExists(atPath: shim.path) {
            try fileManager.removeItem(at: shim)
        }
    }
}
