import AppKit
import Combine
import SwiftUI
import TwoCursorsCore

@MainActor
final class AppModel: ObservableObject {
    @Published var cursor: AppStatus
    @Published var grok: AppStatus
    @Published var claude: AppStatus
    @Published var chatgpt: AppStatus
    @Published var profiles: [Profile] = []
    @Published var selectedID: UUID?
    @Published var liveIDs: Set<UUID> = []
    @Published var errorMessage: String?
    @Published var showingCreate = false
    @Published var editingIconFor: Profile?
    @Published var selectedRecipeID: String?
    @Published var createRecipeID = GrokRecipe().id

    let store: ProfileStore
    let launcher = ProfileLauncher()
    let wrappers = WrapperAppBuilder()
    let shims = CLIShimInstaller()
    let signIn = SignInCoordinator()
    let detector: InstalledAppDetector

    private var refreshTimer: Timer?

    init() {
        let detector = InstalledAppDetector()
        self.detector = detector
        self.cursor = CursorDetector(detector: detector).status()
        self.grok = GrokDetector(detector: detector).status()
        self.claude = ClaudeDetector(detector: detector).status()
        self.chatgpt = ChatGPTDetector(detector: detector).status()
        do {
            self.store = try ProfileStore()
            self.profiles = store.profiles
            self.selectedID = store.profiles.first?.id
        } catch {
            // Store init is expected to succeed; surface a blank catalog if disk is unwritable.
            self.store = try! ProfileStore(root: FileManager.default.temporaryDirectory.appendingPathComponent("LotsOfAgents-fallback"))
            self.errorMessage = error.localizedDescription
        }
        refreshLive()
        DispatchQueue.main.async { [weak self] in self?.refreshStaleWrappers() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    var selected: Profile? {
        // A primary (official) install is selected: there is no profile to edit or delete.
        if selectedPrimaryRecipeID != nil { return nil }
        return profiles.first { $0.id == selectedID } ?? profiles.first
    }

    /// Sidebar tag for an app's official install. The sidebar selects by UUID, so each recipe gets
    /// a fixed UUID that can never collide with a random profile ID.
    static func primaryID(for recipeID: String) -> UUID {
        let index = RecipeRegistry.all.firstIndex { $0.id == recipeID } ?? 0
        return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
    }

    /// Recipe whose official install is selected in the sidebar, if any.
    var selectedPrimaryRecipeID: String? {
        RecipeRegistry.all.first { Self.primaryID(for: $0.id) == selectedID }?.id
    }

    func openPrimary(_ recipeID: String) {
        guard let url = status(for: recipeID).appURL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func status(for recipeID: String) -> AppStatus {
        switch recipeID {
        case CursorRecipe().id: return cursor
        case ClaudeRecipe().id: return claude
        case ChatGPTRecipe().id: return chatgpt
        default: return grok
        }
    }

    var anySupportedAppInstalled: Bool {
        RecipeRegistry.all.contains { status(for: $0.id).isInstalled }
    }

    func openCreate(recipeID: String? = nil) {
        createRecipeID = recipeID ?? selectedRecipeID ?? GrokRecipe().id
        showingCreate = true
    }

    func showRecipe(_ recipeID: String) {
        selectedRecipeID = recipeID
        selectedID = nil
    }

    func showLanding() {
        selectedRecipeID = nil
        selectedID = nil
    }

    func refresh() {
        cursor = CursorDetector(detector: detector).status()
        grok = GrokDetector(detector: detector).status()
        claude = ClaudeDetector(detector: detector).status()
        chatgpt = ChatGPTDetector(detector: detector).status()
        profiles = store.profiles
        refreshLive()
        reapplyIconsIfNeeded()
    }

    func refreshLive() {
        liveIDs = RunningCloneDetector.runningProfileIDs(profiles: profiles, store: store)
    }

    func createProfile(
        name: String,
        recipeID: String,
        icon: IconSpec,
        isolation: IsolationMode,
        installCLIShim: Bool,
        adoptsDefaultData: Bool
    ) {
        do {
            let profile = try store.create(
                name: name,
                recipeID: recipeID,
                icon: icon,
                isolation: isolation,
                installCLIShim: installCLIShim,
                adoptsDefaultData: adoptsDefaultData
            )
            if let recipe = RecipeRegistry.recipe(id: profile.recipeID) {
                try CloneLaunchEnvironment.seedIfNeeded(recipe: recipe, profile: profile, store: store)
            }
            try installSupport(for: profile)
            profiles = store.profiles
            selectedID = profile.id
            selectedRecipeID = profile.recipeID
            showingCreate = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(_ profile: Profile) {
        do {
            let previous = store.profile(id: profile.id)
            try store.update(profile)
            if let previous, previous.wrapperFileName != profile.wrapperFileName || previous.icon != profile.icon {
                try installSupport(for: profile)
                if previous.wrapperFileName != profile.wrapperFileName {
                    try wrappers.remove(profile: previous)
                }
            } else {
                try installSupport(for: profile)
            }
            if profile.installCLIShim {
                if let recipe = RecipeRegistry.recipe(id: profile.recipeID) {
                    let status = recipe.detect(using: detector)
                    _ = try shims.install(profile: profile, store: store, recipe: recipe, status: status)
                }
            } else {
                try shims.remove(profile: profile)
            }
            profiles = store.profiles
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSelected() {
        guard let profile = selected else { return }
        do {
            launcher.quit(profile: profile, store: store)
            try wrappers.remove(profile: profile)
            try shims.remove(profile: profile)
            try store.delete(profile.id)
            profiles = store.profiles
            selectedID = profiles.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func launch(_ profile: Profile) {
        guard let recipe = RecipeRegistry.recipe(id: profile.recipeID) else { return }
        let status = recipe.detect(using: detector)
        do {
            try installSupport(for: profile)
            try launcher.launch(profile, store: store, recipe: recipe, status: status)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.refreshLive() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func quit(_ profile: Profile) {
        launcher.quit(profile: profile, store: store)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.refreshLive() }
    }

    func beginSignIn(_ profile: Profile) {
        guard let recipe = RecipeRegistry.recipe(id: profile.recipeID) else { return }
        let status = recipe.detect(using: detector)
        do {
            try signIn.begin(profile: profile, store: store, launcher: launcher, recipe: recipe, status: status)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func finishSignIn() {
        signIn.finish(store: store, launcher: launcher, detector: detector)
        refreshLive()
    }

    func updateOfficial(_ status: AppStatus) {
        do {
            try launcher.openOfficialAppForUpdate(status: status)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateCursor() {
        updateOfficial(cursor)
    }

    func updateGrok() {
        updateOfficial(grok)
    }

    func installSupport(for profile: Profile) throws {
        guard let binary = WrapperAppBuilder.locateLauncherBinary() else {
            return
        }
        let image = IconComposer.image(from: profile.icon, base: IconComposer.baseIcon(for: profile.recipeID))
        _ = try wrappers.install(profile: profile, store: store, launcherBinary: binary, iconImage: image)
    }

    /// Rebuild wrappers made by an older Lots of Agents so they pick up launcher fixes
    /// (running clones are skipped by the builder and refresh on a later start).
    private func refreshStaleWrappers() {
        guard let binary = WrapperAppBuilder.locateLauncherBinary() else { return }
        for profile in profiles where wrappers.needsRefresh(profile: profile, launcherBinary: binary) {
            do {
                try installSupport(for: profile)
            } catch {
                NSLog("Lots of Agents: refreshing \(profile.wrapperFileName) failed: \(error.localizedDescription)")
            }
        }
    }

    private func reapplyIconsIfNeeded() {
        for profile in profiles {
            let url = wrappers.wrapperURL(for: profile)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            IconComposer.removeCustomIconOverride(from: url)
        }
    }
}

@main
struct TwoCursorsApp: App {
    @StateObject private var model = AppModel()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        Self.applyBrandIcon()
    }

    private static func applyBrandIcon() {
        let candidates = [
            Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/AppIcon.icns"),
        ]
        for url in candidates {
            guard let url, FileManager.default.fileExists(atPath: url.path),
                  let image = NSImage(contentsOf: url) else { continue }
            NSApplication.shared.applicationIconImage = image
            return
        }
    }

    var body: some Scene {
        WindowGroup("Lots of Agents") {
            ContentView()
                .environmentObject(model)
                .environmentObject(model.signIn)
                .frame(minWidth: 860, minHeight: 560)
        }
        .defaultSize(width: 980, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Clone…") {
                    model.showingCreate = true
                }
                .keyboardShortcut("n")
            }
        }
    }
}
