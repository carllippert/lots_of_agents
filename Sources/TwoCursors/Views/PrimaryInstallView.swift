import AppKit
import SwiftUI
import TwoCursorsCore

/// Read-only page for an app's official install. Lots of Agents never modifies the official app:
/// editing its name or icon would break its signature and be undone by its next update. Clones are
/// built from it and update from it, so use the primary for one account and clones for the rest.
struct PrimaryInstallView: View {
    @EnvironmentObject private var model: AppModel
    var recipeID: String

    private var recipe: (any AppRecipe)? { RecipeRegistry.recipe(id: recipeID) }
    private var status: AppStatus { model.status(for: recipeID) }
    private var clones: [Profile] { model.profiles.filter { $0.recipeID == recipeID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                actions
                GroupBox("Primary install") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("App") {
                            Text(status.appURL?.path ?? "Not installed")
                                .textSelection(.enabled)
                        }
                        LabeledContent("Version") { Text(status.versionLabel) }
                        LabeledContent("Bundle ID") {
                            Text(status.bundleIdentifier ?? "—")
                                .textSelection(.enabled)
                        }
                        LabeledContent("Status") { Text(status.isRunning ? "Running" : "Not running") }
                    }
                    .padding(8)
                }
                GroupBox("Clones") {
                    VStack(alignment: .leading, spacing: 8) {
                        if clones.isEmpty {
                            Text("No clones yet.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(clones) { profile in
                            HStack(spacing: 10) {
                                ProfileIconView(spec: profile.icon, size: 22, recipeID: profile.recipeID)
                                Text(profile.wrapperDisplayName)
                            }
                        }
                        Text("Clones are built from this app and pick up its updates the next time they open. Keep this app updated to update every clone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                }
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            OfficialIconView(recipeID: recipeID, size: 72)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(recipe?.displayName ?? recipeID)
                        .font(.largeTitle.weight(.semibold))
                    Label("Primary", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                Text("The official app. Its name and icon stay as installed — use it for one account and make clones for the others.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var actions: some View {
        HStack {
            Button(status.isRunning ? "Show" : "Open") { model.openPrimary(recipeID) }
                .buttonStyle(.borderedProminent)
                .disabled(!status.isInstalled)
            if let url = status.appURL {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            Spacer()
            Button("New Clone") { model.openCreate(recipeID: recipeID) }
        }
    }
}
