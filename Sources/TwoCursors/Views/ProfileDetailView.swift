import SwiftUI
import TwoCursorsCore

struct ProfileDetailView: View {
    @EnvironmentObject private var model: AppModel
    var profile: Profile

    @State private var name: String = ""
    @State private var isolation: IsolationMode = .userDataDir
    @State private var installCLIShim = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                actions
                identity
                isolationSection
                paths
                grokNote
            }
            .padding(24)
        }
        .onAppear { sync() }
        .onChange(of: profile.id) { _, _ in sync() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Button {
                model.editingIconFor = profile
            } label: {
                ProfileIconView(spec: profile.icon, size: 72, recipeID: profile.recipeID)
            }
            .buttonStyle(.plain)
            .help("Edit icon")

            VStack(alignment: .leading, spacing: 6) {
                TextField("Name", text: $name)
                    .font(.largeTitle.weight(.semibold))
                    .textFieldStyle(.plain)
                    .onSubmit { commitIdentity() }
                Text(model.liveIDs.contains(profile.id) ? "Running" : "Stopped")
                    .foregroundStyle(model.liveIDs.contains(profile.id) ? .green : .secondary)
                Text("Click the icon to edit it in place. No need to recreate the Dock app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var actions: some View {
        HStack {
            Button("Launch") { model.launch(current) }
                .buttonStyle(.borderedProminent)
                .disabled(!appInstalled)
            Button("Quit") { model.quit(current) }
                .disabled(!model.liveIDs.contains(profile.id))
            Button("Sign in…") { model.beginSignIn(current) }
                .help("Pauses other \(appName) clones so \(urlScheme):// login reaches this one.")
            Spacer()
            Button("Save") { commitIdentity() }
            Button("Delete clone", role: .destructive) { model.deleteSelected() }
        }
    }

    private var identity: some View {
        GroupBox("Dock app") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Wrapper") {
                    Text("~/Applications/\(profile.wrapperFileName)")
                        .textSelection(.enabled)
                }
                LabeledContent("Bundle ID") {
                    Text(profile.wrapperBundleIdentifier)
                        .textSelection(.enabled)
                }
                Toggle("Install CLI shim (\(profile.cliShimName))", isOn: $installCLIShim)
                    .onChange(of: installCLIShim) { _, _ in commitIdentity() }
                Text("The shim lives in ~/.local/bin and always launches this clone. The plain `\(profile.recipeID == "grok" ? "grok" : "cursor")` command still opens the default install.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    private var isolationSection: some View {
        GroupBox("Isolation") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Mode", selection: $isolation) {
                    ForEach(IsolationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: isolation) { _, _ in commitIdentity() }
                Text(isolation.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    private var paths: some View {
        GroupBox("Data") {
            VStack(alignment: .leading, spacing: 6) {
                pathRow("User data", model.store.userDataURL(for: profile).path)
                pathRow("Extensions", model.store.extensionsURL(for: profile).path)
                if profile.isolation == .fullHomeOverlay {
                    pathRow("Overlay HOME", model.store.overlayHomeURL(for: profile).path)
                }
                if profile.adoptsDefaultData {
                    Text("This clone adopted the existing app data folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private var grokNote: some View {
        if profile.recipeID == "grok" {
            GroupBox("Grok Bot") {
                Text("Grok Bot has no account switcher. This clone launches the same /Applications/Grok Bot.app with a private data directory, so you can stay signed into a second Cursor-tier login. Sign-in mode pauses other Grok clones so sand:// reaches this one. Update from the official app — clones share that binary.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
    }

    private var appInstalled: Bool {
        if profile.recipeID == "grok" { return model.grok.isInstalled }
        if profile.recipeID == "cursor" { return model.cursor.isInstalled }
        return false
    }

    private var appName: String {
        RecipeRegistry.recipe(id: profile.recipeID)?.displayName ?? "app"
    }

    private var urlScheme: String {
        RecipeRegistry.recipe(id: profile.recipeID)?.urlSchemes.first ?? "app"
    }

    private func pathRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .textSelection(.enabled)
                .font(.caption.monospaced())
        }
    }

    private var current: Profile {
        var next = profile
        next.name = name
        next.slug = Profile.makeSlug(name)
        next.isolation = isolation
        next.installCLIShim = installCLIShim
        return next
    }

    private func sync() {
        name = profile.name
        isolation = profile.isolation
        installCLIShim = profile.installCLIShim
    }

    private func commitIdentity() {
        model.save(current)
    }
}
