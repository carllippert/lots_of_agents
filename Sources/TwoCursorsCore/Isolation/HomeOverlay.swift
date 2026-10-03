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

    public static func isolatedRelativePaths(for recipeID: String? = nil) -> [String] {
        var paths = [".cursor", ".codex"]
        switch recipeID {
        case ChatGPTRecipe().id:
            paths += [
                "Library/Application Support/OpenAI",
                "Library/Application Support/Codex",
                "Library/Application Support/com.openai.codex",
            ]
        case ClaudeRecipe().id:
            paths.append(".claude")
        default:
            break
        }
        return paths
    }

    @discardableResult
    public static func prepare(
        overlayRoot: URL,
        realHome: URL,
        recipeID: String? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let isolated = isolatedRelativePaths(for: recipeID)
        try fileManager.createDirectory(at: overlayRoot, withIntermediateDirectories: true)

        for relative in isolated {
            try isolate(relative, overlayRoot: overlayRoot, realHome: realHome, fileManager: fileManager)
        }

        let parents = parentPaths(of: isolated)
        try fillSiblingSymlinks(
            atRelative: "",
            overlayRoot: overlayRoot,
            realHome: realHome,
            isolated: isolated,
            fileManager: fileManager
        )
        for parent in parents.sorted() {
            try fillSiblingSymlinks(
                atRelative: parent,
                overlayRoot: overlayRoot,
                realHome: realHome,
                isolated: isolated,
                fileManager: fileManager
            )
        }

        return overlayRoot
    }

    public static func isFullOverlay(
        overlayRoot: URL,
        realHome: URL,
        recipeID: String? = nil,
        fileManager: FileManager = .default
    ) -> Bool {
        for relative in isolatedRelativePaths(for: recipeID) {
            let isolated = overlayRoot.appendingPathComponent(relative)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: isolated.path, isDirectory: &isDir), isDir.boolValue else {
                return false
            }
            if isSymlink(isolated) {
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

    private static func isolate(
        _ relative: String,
        overlayRoot: URL,
        realHome: URL,
        fileManager: FileManager
    ) throws {
        let components = relative.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return }

        var overlay = overlayRoot
        for (index, component) in components.enumerated() {
            overlay.appendPathComponent(component, isDirectory: true)
            let isLeaf = index == components.count - 1
            if isLeaf {
                try replaceSymlinkWithEmptyDirectory(overlay, fileManager: fileManager)
            } else {
                try ensureRealDirectory(overlay, fileManager: fileManager)
            }
        }
        _ = realHome
    }

    private static func replaceSymlinkWithEmptyDirectory(_ url: URL, fileManager: FileManager) throws {
        if isSymlink(url) {
            try fileManager.removeItem(at: url)
        }
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue { return }
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func ensureRealDirectory(_ url: URL, fileManager: FileManager) throws {
        if isSymlink(url) {
            try fileManager.removeItem(at: url)
        }
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue { return }
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static func fillSiblingSymlinks(
        atRelative parent: String,
        overlayRoot: URL,
        realHome: URL,
        isolated: [String],
        fileManager: FileManager
    ) throws {
        let realParent = parent.isEmpty ? realHome : realHome.appendingPathComponent(parent, isDirectory: true)
        let overlayParent = parent.isEmpty ? overlayRoot : overlayRoot.appendingPathComponent(parent, isDirectory: true)
        guard fileManager.fileExists(atPath: realParent.path) else { return }
        let skip = skippedChildNames(atRelativeParent: parent, isolated: isolated)
        let items: [URL]
        do {
            items = try fileManager.contentsOfDirectory(
                at: realParent,
                includingPropertiesForKeys: [.isSymbolicLinkKey],
                options: []
            )
        } catch {
            throw TwoCursorsError.overlayFailed(error.localizedDescription)
        }
        for item in items {
            let name = item.lastPathComponent
            if skip.contains(name) { continue }
            let dest = overlayParent.appendingPathComponent(name)
            if fileManager.fileExists(atPath: dest.path) || isSymlink(dest) { continue }
            do {
                try fileManager.createSymbolicLink(at: dest, withDestinationURL: item)
            } catch {
                continue
            }
        }
    }

    private static func skippedChildNames(atRelativeParent parent: String, isolated: [String]) -> Set<String> {
        var skip = Set<String>()
        for path in isolated {
            let remainder: String?
            if parent.isEmpty {
                remainder = path
            } else if path == parent {
                remainder = nil
            } else if path.hasPrefix(parent + "/") {
                remainder = String(path.dropFirst(parent.count + 1))
            } else {
                remainder = nil
            }
            guard let remainder, let first = remainder.split(separator: "/").first else { continue }
            skip.insert(String(first))
        }
        return skip
    }

    private static func parentPaths(of isolated: [String]) -> Set<String> {
        var parents = Set<String>()
        for path in isolated {
            let parts = path.split(separator: "/").map(String.init)
            if parts.count < 2 { continue }
            var soFar = ""
            for component in parts.dropLast() {
                soFar = soFar.isEmpty ? component : soFar + "/" + component
                parents.insert(soFar)
            }
        }
        return parents
    }

    private static func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
    }
}
