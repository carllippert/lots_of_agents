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
        var script = """
        #!/bin/sh
        exec "\(executable.path)" --user-data-dir="\(userData)" --extensions-dir="\(extensions)" "$@"
        """
        if profile.isolation == .fullHomeOverlay {
            let home = store.overlayHomeURL(for: profile).path
            script = """
            #!/bin/sh
            export HOME="\(home)"
            export CURSOR_DATA_DIR="\(home)/.cursor"
            exec "\(executable.path)" --user-data-dir="\(userData)" --extensions-dir="\(extensions)" "$@"
            """
        }
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
