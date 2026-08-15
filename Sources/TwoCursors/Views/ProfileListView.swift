import SwiftUI
import TwoCursorsCore

struct ProfileListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: $model.selectedID) {
            ForEach(RecipeRegistry.all, id: \.id) { recipe in
                let clones = model.profiles.filter { $0.recipeID == recipe.id }
                if !clones.isEmpty {
                    Section(recipe.displayName) {
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
