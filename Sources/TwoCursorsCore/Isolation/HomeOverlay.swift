import Foundation

/// Full-home overlay: every top-level item in the real home is a symlink.
/// Only `.cursor` is a real per-clone directory.
/// This is the opposite of Parall's "minimal home" with a handful of links and empty folders.
public enum HomeOverlay {
    public static let isolatedName = ".cursor"

    @discardableResult
    public static func prepare(
        overlayRoot: URL,
        realHome: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try fileManager.createDirectory(at: overlayRoot, withIntermediateDirectories: true)

        let isolated = overlayRoot.appendingPathComponent(isolatedName, isDirectory: true)
        if !fileManager.fileExists(atPath: isolated.path) {
            try fileManager.createDirectory(at: isolated, withIntermediateDirectories: true)
        }

        let items: [URL]
        do {
            items = try fileManager.contentsOfDirectory(
                at: realHome,
                includingPropertiesForKeys: [.isSymbolicLinkKey],
                options: []
            )
        } catch {
            throw TwoCursorsError.overlayFailed(error.localizedDescription)
        }

        for item in items {
            let name = item.lastPathComponent
            if name == isolatedName { continue }
            let dest = overlayRoot.appendingPathComponent(name)
            if fileManager.fileExists(atPath: dest.path) { continue }
            do {
                try fileManager.createSymbolicLink(at: dest, withDestinationURL: item)
            } catch {
                continue
            }
        }

        return overlayRoot
    }

    public static func isFullOverlay(
        overlayRoot: URL,
        realHome: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        let isolated = overlayRoot.appendingPathComponent(isolatedName)
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: isolated.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        if let attrs = try? isolated.resourceValues(forKeys: [.isSymbolicLinkKey]), attrs.isSymbolicLink == true {
            return false
        }
        let required = [".ssh", ".gitconfig"]
        for name in required {
            let real = realHome.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: real.path) else { continue }
            let link = overlayRoot.appendingPathComponent(name)
            guard let dest = try? fileManager.destinationOfSymbolicLink(atPath: link.path) else {
                return false
            }
            if URL(fileURLWithPath: dest).standardizedFileURL != real.standardizedFileURL,
               (realHome.appendingPathComponent(dest).standardizedFileURL != real.standardizedFileURL) {
                let destURL = URL(fileURLWithPath: dest).standardizedFileURL
                if destURL != real.standardizedFileURL {
                    return false
                }
            }
        }
        return true
    }
}
