import SwiftUI
import TwoCursorsCore
import UniformTypeIdentifiers
import AppKit

struct CreateProfileSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = "Work"
    @State private var recipeID = GrokRecipe().id
    @State private var isolation = IsolationMode.userDataDir
    @State private var installCLIShim = false
    @State private var adoptsDefaultData = false
    @State private var icon = IconSpec(tintHex: IconSpec.palette[0], badge: "WORK")

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New clone")
                .font(.title2.weight(.semibold))
            Text("Name it, pick an icon, launch. That’s the whole flow.")
                .foregroundStyle(.secondary)

            Form {
                TextField("Name", text: $name)
                    .onChange(of: name) { _, value in
                        icon.badge = String(value.prefix(8)).uppercased()
                    }
                Picker("App", selection: $recipeID) {
                    Text("Grok Bot").tag(GrokRecipe().id)
                    Text("Cursor").tag(CursorRecipe().id)
                }
                Picker("Isolation", selection: $isolation) {
                    ForEach(IsolationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Toggle("Install CLI shim in ~/.local/bin", isOn: $installCLIShim)
                if recipeID == CursorRecipe().id, model.profiles.isEmpty {
                    Toggle("Adopt my current Cursor data as this clone", isOn: $adoptsDefaultData)
                }
            }

            IconEditorView(spec: $icon, recipeID: recipeID)
                .frame(minHeight: 280)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
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
        .padding(24)
        .frame(width: 560)
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
                TextField("Badge", text: $spec.badge)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Choose image…") { pickImage() }
                    if spec.customImagePNG != nil {
                        Button("Clear image") { spec.customImagePNG = nil }
                    }
                }
                Text("Drop a PNG or JPEG on the preview. Badge stays inside the icon so macOS Tahoe does not pad it.")
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
