import Foundation

public enum CloneLaunchEnvironment {
    public static func make(
        profile: Profile,
        store: ProfileStore,
        recipe: any AppRecipe,
        base: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> [String: String] {
        var env = base
        env.removeValue(forKey: "ELECTRON_RUN_AS_NODE")
        if profile.isolation == .fullHomeOverlay {
            let overlay = store.overlayHomeURL(for: profile)
            try HomeOverlay.prepare(
                overlayRoot: overlay,
                realHome: TwoCursorsPaths.accountHome(fileManager: store.fileManager),
                recipeID: profile.recipeID,
                fileManager: store.fileManager
            )
            env["HOME"] = overlay.path
            env["CURSOR_DATA_DIR"] = overlay.appendingPathComponent(".cursor").path
        }
        if recipe.id == ChatGPTRecipe().id {
            let home = profile.isolation == .fullHomeOverlay
                ? store.overlayHomeURL(for: profile)
                : TwoCursorsPaths.accountHome(fileManager: store.fileManager)
            env["CODEX_HOME"] = home.appendingPathComponent(".codex").path
            env["CODEX_ELECTRON_USER_DATA_PATH"] = store.userDataURL(for: profile).path
        }
        return env
    }

    public static func seedIfNeeded(recipe: any AppRecipe, profile: Profile, store: ProfileStore) throws {
        if recipe.seedsMarketplace {
            try ProfileSeeder.seedUserData(at: store.userDataURL(for: profile), icon: profile.icon)
        } else if recipe.seedsUpdateDisabled {
            try ProfileSeeder.seedUpdateDisabled(at: store.userDataURL(for: profile))
        }
    }
}
