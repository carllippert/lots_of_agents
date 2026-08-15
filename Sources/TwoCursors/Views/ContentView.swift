import AppKit
import SwiftUI
import TwoCursorsCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var signIn: SignInCoordinator

    var body: some View {
        VStack(spacing: 0) {
            if signIn.isSigningIn {
                SignInBanner()
            }
            if model.profiles.isEmpty {
                if let recipeID = model.selectedRecipeID {
                    RecipeHubView(recipeID: recipeID)
                } else {
                    LandingView()
                }
            } else {
                NavigationSplitView {
                    ProfileListView()
                        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
                        .frame(minWidth: 240)
                } detail: {
                    if let profile = model.selected {
                        ProfileDetailView(profile: profile)
                    } else if let recipeID = model.selectedRecipeID, model.profiles.isEmpty {
                        RecipeHubView(recipeID: recipeID)
                    } else if let first = model.profiles.first {
                        ProfileDetailView(profile: first)
                    }
                }
            }
        }
        .sheet(isPresented: $model.showingCreate) {
            CreateProfileSheet(initialRecipeID: model.createRecipeID)
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
