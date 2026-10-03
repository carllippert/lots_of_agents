import SwiftUI
import TwoCursorsCore

struct ProfileListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: $model.selectedID) {
            ForEach(RecipeRegistry.all, id: \.id) { recipe in
                let clones = model.profiles.filter { $0.recipeID == recipe.id }
                let installed = model.status(for: recipe.id).isInstalled
                if installed || !clones.isEmpty {
                    Section(recipe.displayName) {
                        if installed {
                            primaryRow(recipe)
                        }
                        ForEach(clones) { profile in
                            row(profile)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Clones")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                model.openCreate()
            } label: {
                Label("New Clone", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.anySupportedAppInstalled)
            .padding(12)
            .background(.bar)
        }
    }

    /// The official app in /Applications: listed so every install is visible, but not editable.
    private func primaryRow(_ recipe: any AppRecipe) -> some View {
        HStack(spacing: 10) {
            OfficialIconView(recipeID: recipe.id, size: 28)
            Text(recipe.displayName)
            Spacer()
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("Primary install — the official app. Its name and icon can't be changed.")
        }
        .tag(AppModel.primaryID(for: recipe.id))
    }

    private func row(_ profile: Profile) -> some View {
        HStack(spacing: 10) {
            ProfileIconView(spec: profile.icon, size: 28, recipeID: profile.recipeID)
            Text(profile.name)
        }
        .tag(profile.id)
    }
}

struct ProfileIconView: View {
    var spec: IconSpec
    var size: CGFloat
    var recipeID: String = GrokRecipe().id

    var body: some View {
        Image(nsImage: IconComposer.image(from: spec, base: IconComposer.baseIcon(for: recipeID), size: 128))
            .resizable()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

struct OfficialIconView: View {
    var recipeID: String
    var size: CGFloat

    var body: some View {
        if let image = IconComposer.baseIcon(for: recipeID) {
            Image(nsImage: image)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app")
                .resizable()
                .frame(width: size, height: size)
        }
    }
}
