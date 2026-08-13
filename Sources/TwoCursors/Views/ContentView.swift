import AppKit
import SwiftUI
import TwoCursorsCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var signIn: SignInCoordinator

    var body: some View {
        NavigationSplitView {
            ProfileListView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            if let profile = model.selected {
                ProfileDetailView(profile: profile)
            } else {
                emptyState
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.showingCreate = true
                } label: {
                    Label("New Clone", systemImage: "plus")
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                GrokStatusBanner()
                if signIn.isSigningIn {
                    SignInBanner()
                }
            }
        }
        .sheet(isPresented: $model.showingCreate) {
            CreateProfileSheet()
                .environmentObject(model)
        }
        .sheet(item: $model.editingIconFor) { profile in
            IconEditorSheet(profile: profile)
                .environmentObject(model)
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No clones yet")
                .font(.title2.weight(.semibold))
            Text("Make a Work and Personal Grok Bot. Each one keeps its own Cursor-tier login. Updating Grok Bot once updates them all. Cursor clones are also supported.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("New Clone") {
                model.showingCreate = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.grok.isInstalled && !model.cursor.isInstalled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct GrokStatusBanner: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                statusDot(on: model.grok.isInstalled)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.grok.isInstalled ? "Grok Bot installed: yes" : "Grok Bot installed: no")
                        .font(.headline)
                    if model.grok.isInstalled {
                        Text("Version \(model.grok.versionLabel) · \(runningLine)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Install Grok Bot from cursor.com/bot, then refresh.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !model.grok.isInstalled {
                    Button("Open download") {
                        NSWorkspace.shared.open(GrokRecipe().downloadURL)
                    }
                } else {
                    Button("Update Grok Bot") {
                        model.updateGrok()
                    }
                    .help("Opens the official Grok Bot.app so its updater runs once. Every clone uses that same binary.")
                }
                Button("Refresh") {
                    model.refresh()
                }
            }
            HStack(spacing: 8) {
                statusDot(on: model.cursor.isInstalled)
                Text(cursorLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if model.cursor.isInstalled {
                    Button("Update Cursor") {
                        model.updateCursor()
                    }
                    .controlSize(.small)
                    .help("Opens the official Cursor.app. Cursor clones share that binary.")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var runningLine: String {
        let path = model.grok.appURL?.path ?? "/Applications/Grok Bot.app"
        if model.grok.isRunning {
            let pid = model.grok.processIdentifier.map { "PID \($0)" } ?? "running"
            return "Running: yes · \(pid) · \(path)"
        }
        return "Running: no · \(path)"
    }

    private var cursorLine: String {
        if model.cursor.isInstalled {
            let running = model.cursor.isRunning ? "running" : "not running"
            return "Cursor also supported · \(model.cursor.versionLabel) · \(running)"
        }
        return "Cursor also supported · not installed"
    }

    private func statusDot(on: Bool) -> some View {
        Circle()
            .fill(on ? Color.green : Color.orange)
            .frame(width: 10, height: 10)
    }
}

struct SignInBanner: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var signIn: SignInCoordinator

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.badge.key.fill")
            VStack(alignment: .leading, spacing: 4) {
                Text("Sign-in mode")
                    .font(.headline)
                Text("Other \(signIn.displayName) clones are paused so \(signIn.urlScheme):// login reaches this one. Sign in inside the window, then resume.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Resume other clones") {
                model.finishSignIn()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.12))
    }
}
