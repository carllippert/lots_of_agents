import SwiftUI
import TwoCursorsCore

struct ProfileDetailView: View {
    @EnvironmentObject private var model: AppModel
    var profile: Profile

    @State private var name: String = ""
    @State private var isolation: IsolationMode = .userDataDir
    @State private var installCLIShim = false
    @State private var showingAdvanced = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                actions
                identity
                isolationSection
                paths
                advanced
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
                Text("Click the icon to edit it in place. No need to recreate the Dock app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var actions: some View {
        HStack {
            Button("Launch") { model.launch(profile) }
                .buttonStyle(.borderedProminent)
                .disabled(!appInstalled || isDirty)
                .help(isDirty ? "Save your changes first." : "Launch this clone")
            Spacer()
            Button("Save") { commitIdentity() }
                .buttonStyle(.borderedProminent)
                .disabled(!isDirty)
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
                Text(isolation.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isDirty && isolation != profile.isolation {
                    Text("Save to apply this mode. It takes effect the next time you launch.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(8)
        }
    }

    private var paths: some View {
        GroupBox("Data") {
            VStack(alignment: .leading, spacing: 6) {
                pathRow("User data", model.store.userDataURL(for: profile).path)
                pathRow("Extensions", model.store.extensionsURL(for: profile).path)
                if isolation == .fullHomeOverlay {
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

    private var advanced: some View {
        DisclosureGroup("Advanced", isExpanded: $showingAdvanced) {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Bundle ID") {
                    Text(profile.wrapperBundleIdentifier)
                        .textSelection(.enabled)
                }
                Toggle("Install CLI shim (\(profile.cliShimName))", isOn: $installCLIShim)
                Text("Puts a launcher in ~/.local/bin for this clone only. The plain command for this app still opens the default install. Save to apply.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private var appInstalled: Bool {
        model.status(for: profile.recipeID).isInstalled
    }

    private func pathRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .textSelection(.enabled)
                .font(.caption.monospaced())
        }
    }

    private var isDirty: Bool {
        name != profile.name
            || isolation != profile.isolation
            || installCLIShim != profile.installCLIShim
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
        showingAdvanced = false
    }

    private func commitIdentity() {
        model.save(current)
    }
}
