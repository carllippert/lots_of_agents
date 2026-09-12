import Foundation

/// Full-home overlay: every top-level item in the real home is a symlink.
/// A small set of app-specific folders are real, per-clone directories instead.
/// This is the opposite of Parall's "minimal home" with a handful of links and empty folders.
public enum HomeOverlay {
    /// `.cursor` holds Cursor/Grok Bot skills & user rules.
    /// `.codex` holds ChatGPT (Codex) session/auth/IPC state — ChatGPT stores its login here,
    /// outside the Chromium `--user-data-dir`, so it must be private per clone or every clone
    /// (and the real app) share one login and log each other out.
    public static let isolatedNames: Set<String> = [".cursor", ".codex"]

    @discardableResult
    public static func prepare(
        overlayRoot: URL,
        realHome: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try fileManager.createDirectory(at: overlayRoot, withIntermediateDirectories: true)

        for name in isolatedNames {
            let isolated = overlayRoot.appendingPathComponent(name, isDirectory: true)
            if !fileManager.fileExists(atPath: isolated.path) {
                try fileManager.createDirectory(at: isolated, withIntermediateDirectories: true)
            }
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
            if isolatedNames.contains(name) { continue }
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
        for name in isolatedNames {
            let isolated = overlayRoot.appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: isolated.path, isDirectory: &isDir), isDir.boolValue else {
                return false
            }
            if let attrs = try? isolated.resourceValues(forKeys: [.isSymbolicLinkKey]), attrs.isSymbolicLink == true {
                return false
            }
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
