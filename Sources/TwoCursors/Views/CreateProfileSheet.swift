import SwiftUI
import TwoCursorsCore
import UniformTypeIdentifiers
import AppKit

struct CreateProfileSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var name = "Work"
    @State private var recipeID: String
    @State private var isolation = IsolationMode.userDataDir
    @State private var installCLIShim = false
    @State private var adoptsDefaultData = false
    @State private var icon = IconSpec(tintHex: IconSpec.palette[0], showsBadge: false)

    init(initialRecipeID: String = GrokRecipe().id) {
        _recipeID = State(initialValue: initialRecipeID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(step == 0 ? "New clone" : "Configure clone")
                .font(.title2.weight(.semibold))
            Text(step == 0
                 ? "Which app should this clone launch?"
                 : "Name it and tint the icon. A Dock label is optional — color is enough.")
                .foregroundStyle(.secondary)

            if step == 0 {
                appSelector
            } else {
                configureStep
            }

            HStack {
                if step == 1 {
                    Button("Back") { step = 0 }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                if step == 0 {
                    Button("Continue") { step = 1 }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(!selectedAppInstalled)
                } else {
                    Button("Create") {
                        model.createProfile(
                            name: name,
                            recipeID: recipeID,
                            icon: icon,
                            isolation: isolation,
                            installCLIShim: installCLIShim,
                            adoptsDefaultData: adoptsDefaultData
                        )
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(24)
        .frame(width: 680)
    }

    private var appSelector: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(RecipeRegistry.all, id: \.id) { recipe in
                AppPickerCard(recipeID: recipe.id, selection: $recipeID)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var selectedAppInstalled: Bool {
        model.status(for: recipeID).isInstalled
    }

    private var configureStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                SupportedAppIcon(recipeID: recipeID, size: 36, showsCaption: false)
                Text(RecipeRegistry.recipe(id: recipeID)?.displayName ?? "App")
                    .font(.headline)
            }

            Form {
                TextField("Name", text: $name)
                Picker("Isolation", selection: $isolation) {
                    ForEach(IsolationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                if recipeID == CursorRecipe().id, model.profiles.filter({ $0.recipeID == "cursor" }).isEmpty {
                    Toggle("Adopt my current Cursor data as this clone", isOn: $adoptsDefaultData)
                }
            }

            IconEditorView(spec: $icon, recipeID: recipeID)
                .frame(minHeight: 240)

            DisclosureGroup("Advanced") {
                Toggle("Install CLI shim in ~/.local/bin", isOn: $installCLIShim)
                Text("Optional terminal shortcut for this clone. Leave off unless you launch from a shell.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AppPickerCard: View {
    @EnvironmentObject private var model: AppModel
    var recipeID: String
    @Binding var selection: String

    private var recipeName: String {
        RecipeRegistry.recipe(id: recipeID)?.displayName ?? "App"
    }

    private var status: AppStatus {
        model.status(for: recipeID)
    }

    var body: some View {
        Button {
            selection = recipeID
        } label: {
            cardLabel
        }
        .buttonStyle(.plain)
        .disabled(!status.isInstalled)
        .help(status.isInstalled ? "Clone \(recipeName)" : "Install \(recipeName) first")
    }

    private var cardLabel: some View {
        VStack(spacing: 12) {
            SupportedAppIcon(recipeID: recipeID, size: 72, showsCaption: false)
            Text(recipeName)
                .font(.headline)
            Text(status.isInstalled ? "Installed" : "Not installed")
                .font(.caption)
                .foregroundStyle(status.isInstalled ? Color.secondary : Color.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(cardBackground)
        .overlay(cardStroke)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(selection == recipeID ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(selection == recipeID ? Color.accentColor : Color.clear, lineWidth: 2)
    }
}

struct IconEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var profile: Profile
    @State private var spec: IconSpec

    init(profile: Profile) {
        self.profile = profile
        _spec = State(initialValue: profile.icon)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit icon")
                .font(.title2.weight(.semibold))
            Text("Saved onto the existing Dock app. You do not recreate anything.")
                .foregroundStyle(.secondary)
            IconEditorView(spec: $spec, recipeID: profile.recipeID)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save icon") {
                    var next = profile
                    next.icon = spec
                    model.save(next)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

struct IconEditorView: View {
    @Binding var spec: IconSpec
    var recipeID: String = GrokRecipe().id
    @State private var isDropTarget = false

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            ProfileIconView(spec: spec, size: 128, recipeID: recipeID)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isDropTarget ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 2)
                )
                .onDrop(of: [UTType.image], isTargeted: $isDropTarget) { providers in
                    loadDroppedImage(providers)
                }

            VStack(alignment: .leading, spacing: 12) {
                Text("Tint")
                    .font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(28)), count: 8), spacing: 8) {
                    ForEach(IconSpec.palette, id: \.self) { hex in
                        Circle()
                            .fill(Color(nsColor: NSColor(hex: hex) ?? .gray))
                            .frame(width: 24, height: 24)
                            .overlay {
                                if spec.tintHex.lowercased() == hex.lowercased() {
                                    Circle().stroke(Color.primary, lineWidth: 2)
                                }
                            }
                            .onTapGesture { spec.tintHex = hex }
                    }
                }
                Toggle("Label on icon", isOn: $spec.showsBadge)
                if spec.showsBadge {
                    TextField("Label", text: $spec.badge)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Button("Choose image…") { pickImage() }
                    if spec.customImagePNG != nil {
                        Button("Clear image") { spec.customImagePNG = nil }
                    }
                }
                Text("Tint is usually enough. Leave the label off if you don’t want the clone name on the Dock icon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            spec.customImagePNG = data
        }
    }

    private func loadDroppedImage(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadDataRepresentation(for: .image) { data, _ in
            if let data {
                DispatchQueue.main.async {
                    spec.customImagePNG = data
                }
            }
        }
        return true
    }
}
