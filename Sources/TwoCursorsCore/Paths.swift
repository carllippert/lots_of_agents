import Darwin
import Foundation

public enum TwoCursorsPaths {
    public static let appBundleIdentifier = "app.lotsofagents.macos"
    public static let wrapperBundlePrefix = "app.lotsofagents.clone"
    public static let productName = "Lots of Agents"

    /// Login-account home from Directory Services, not `$HOME`.
    /// Avoids storing data inside a Parall (or similar) fake home if this app was launched from one.
    public static func accountHome(fileManager: FileManager = .default) -> URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            let path = String(cString: dir)
            if !path.isEmpty {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
        }
        return fileManager.homeDirectoryForCurrentUser
    }

    public static func applicationSupport(fileManager: FileManager = .default) -> URL {
        accountHome(fileManager: fileManager)
            .appendingPathComponent("Library/Application Support/LotsOfAgents", isDirectory: true)
    }

    public static func profilesJSON(fileManager: FileManager = .default) -> URL {
        applicationSupport(fileManager: fileManager).appendingPathComponent("profiles.json")
    }

    public static func profileRoot(id: UUID, fileManager: FileManager = .default) -> URL {
        applicationSupport(fileManager: fileManager)
            .appendingPathComponent("Profiles", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    public static func wrappersDirectory(fileManager: FileManager = .default) -> URL {
        accountHome(fileManager: fileManager)
            .appendingPathComponent("Applications", isDirectory: true)
    }

    public static func cliBin(fileManager: FileManager = .default) -> URL {
        accountHome(fileManager: fileManager)
            .appendingPathComponent(".local/bin", isDirectory: true)
    }

    public static func standardAppSearchRoots(fileManager: FileManager = .default) -> [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            accountHome(fileManager: fileManager).appendingPathComponent("Applications", isDirectory: true),
        ]
    }
}

public enum TwoCursorsError: LocalizedError, Equatable {
    case appNotInstalled(String)
    case profileNotFound(UUID)
    case executableMissing(URL)
    case launchFailed(String)
    case overlayFailed(String)
    case wrapperFailed(String)
    case iconFailed(String)

    public var errorDescription: String? {
        switch self {
        case .appNotInstalled(let name):
            return "\(name) is not installed. Install it, then refresh."
        case .profileNotFound(let id):
            return "No clone found for \(id.uuidString)."
        case .executableMissing(let url):
            return "Missing executable at \(url.path)."
        case .launchFailed(let message):
            return "Could not launch: \(message)"
        case .overlayFailed(let message):
            return "Could not prepare isolated home: \(message)"
        case .wrapperFailed(let message):
            return "Could not update the Dock app: \(message)"
        case .iconFailed(let message):
            return "Could not write the icon: \(message)"
        }
    }
}
