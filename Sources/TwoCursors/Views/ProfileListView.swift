import SwiftUI
import TwoCursorsCore

struct ProfileListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: $model.selectedID) {
            Section("Grok Bot clones") {
                ForEach(model.profiles.filter { $0.recipeID == "grok" }) { profile in
                    row(profile)
                }
            }
            Section("Cursor clones") {
                ForEach(model.profiles.filter { $0.recipeID == "cursor" }) { profile in
                    row(profile)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Lots of Agents")
    }

    private func row(_ profile: Profile) -> some View {
        HStack(spacing: 10) {
            ProfileIconView(spec: profile.icon, size: 28, recipeID: profile.recipeID)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                Text(model.liveIDs.contains(profile.id) ? "Running" : "Stopped")
                    .font(.caption)
                    .foregroundStyle(model.liveIDs.contains(profile.id) ? .green : .secondary)
            }
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
