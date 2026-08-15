import AppKit
import SwiftUI
import TwoCursorsCore

/// Tokens from e2b.dev dark mode.
private enum E2B {
    static let bg = Color.black
    static let bgSecondary = Color(red: 0.078, green: 0.078, blue: 0.078)   // #141414
    static let bgTertiary = Color(red: 0.102, green: 0.102, blue: 0.102)    // #1a1a1a
    static let stroke = Color(red: 0.161, green: 0.161, blue: 0.161)        // #292929
    static let strokeHover = Color(red: 0.239, green: 0.239, blue: 0.239)   // #3d3d3d
    static let content = Color.white
    static let secondary = Color(red: 0.8, green: 0.8, blue: 0.8)           // #ccc
    static let tertiary = Color(red: 0.467, green: 0.467, blue: 0.467)      // #777
    static let brand = Color(red: 1.0, green: 0.533, blue: 0.0)             // #f80
}

struct LandingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            E2B.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                brandHeader
                    .padding(.top, 40)
                Spacer(minLength: 16)
                orbitStage
                Spacer(minLength: 28)
            }
            .padding(.horizontal, 28)
        }
        .preferredColorScheme(.dark)
    }

    private var brandHeader: some View {
        VStack(spacing: 18) {
            BrandMarkView(size: 52)
            Text("Lots of Agents")
                .font(.system(size: 36, weight: .semibold, design: .default))
                .tracking(-0.6)
                .foregroundStyle(E2B.content)
            Text("ISOLATED AGENT LOGINS")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(E2B.tertiary)
        }
    }

    private var orbitStage: some View {
        TimelineView(.animation(minimumInterval: 1 / 24)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let recipes = RecipeRegistry.all
            let orbit: CGFloat = 128
            ZStack {
                Circle()
                    .stroke(E2B.stroke, lineWidth: 1)
                    .frame(width: orbit * 2, height: orbit * 2)

                ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                    floatingApp(
                        recipeID: recipe.id,
                        time: t,
                        seed: -.pi / 2 + (Double(index) * .pi * 2 / Double(recipes.count)),
                        radius: orbit
                    )
                }

                Button {
                    model.openCreate(recipeID: model.selectedRecipeID ?? GrokRecipe().id)
                } label: {
                    Text("NEW CLONE")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(E2B.bg)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(E2B.content))
                }
                .buttonStyle(.plain)
                .disabled(!model.anySupportedAppInstalled)
                .opacity(model.anySupportedAppInstalled ? 1 : 0.4)
                .help("Create an isolated login. Click an app icon first to choose which one.")
                .zIndex(1)
            }
            .frame(width: 340, height: 340)
        }
    }

    private func floatingApp(recipeID: String, time: TimeInterval, seed: Double, radius: CGFloat) -> some View {
        let angle = time * 0.16 + seed
        let offset = CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
        return Button {
            model.showRecipe(recipeID)
        } label: {
            SupportedAppIcon(recipeID: recipeID, size: 52, showsCaption: true)
        }
        .buttonStyle(.plain)
        .offset(offset)
        .zIndex(0)
    }
}

struct BrandMarkView: View {
    var size: CGFloat

    var body: some View {
        Group {
            if let image = Self.brandImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(E2B.bgSecondary)
                    .overlay {
                        Image(systemName: "square.on.square")
                            .font(.system(size: size * 0.36, weight: .medium))
                            .foregroundStyle(E2B.brand)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(E2B.stroke, lineWidth: 1)
        )
    }

    private static let brandImage: NSImage? = {
        if let url = Bundle.module.url(forResource: "BrandMark", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        let fallback = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/BrandMark.png")
        return NSImage(contentsOf: fallback)
    }()
}

struct RecipeHubView: View {
    @EnvironmentObject private var model: AppModel
    var recipeID: String

    private var recipe: any AppRecipe {
        RecipeRegistry.recipe(id: recipeID) ?? GrokRecipe()
    }

    private var status: AppStatus {
        model.status(for: recipeID)
    }

    private var clones: [Profile] {
        model.profiles.filter { $0.recipeID == recipeID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if model.profiles.isEmpty {
                    Button("← ALL APPS") {
                        model.showLanding()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(E2B.tertiary)
                }

                HStack(alignment: .center, spacing: 20) {
                    SupportedAppIcon(recipeID: recipeID, size: 72, showsCaption: false)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(recipe.displayName)
                            .font(.system(size: 28, weight: .semibold))
                            .tracking(-0.4)
                            .foregroundStyle(E2B.content)
                        Text(statusLine)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(E2B.tertiary)
                        HStack(spacing: 10) {
                            if status.isInstalled {
                                Button("UPDATE") {
                                    model.updateOfficial(status)
                                }
                                .buttonStyle(E2BSecondaryButtonStyle())
                            } else {
                                Button("INSTALL") {
                                    NSWorkspace.shared.open(recipe.downloadURL)
                                }
                                .buttonStyle(E2BPrimaryButtonStyle())
                            }
                            Button("NEW CLONE") {
                                model.openCreate(recipeID: recipeID)
                            }
                            .buttonStyle(E2BPrimaryButtonStyle())
                            .disabled(!status.isInstalled)
                        }
                    }
                    Spacer()
                }

                panel(title: "HOW CLONES WORK") {
                    Text(howTo)
                        .font(.system(size: 13))
                        .foregroundStyle(E2B.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                panel(title: "YOUR CLONES") {
                    if clones.isEmpty {
                        Text("None yet. Make Work and Personal so both logins stay signed in.")
                            .font(.system(size: 13))
                            .foregroundStyle(E2B.tertiary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(clones) { profile in
                                Button {
                                    model.selectedID = profile.id
                                } label: {
                                    HStack {
                                        ProfileIconView(spec: profile.icon, size: 28, recipeID: profile.recipeID)
                                        Text(profile.name)
                                            .foregroundStyle(E2B.content)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(E2B.bg)
        .preferredColorScheme(.dark)
    }

    private func panel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(E2B.tertiary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 2).fill(E2B.bgSecondary))
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(E2B.stroke, lineWidth: 1))
    }

    private var statusLine: String {
        if status.isInstalled {
            let running = status.isRunning ? "running" : "idle"
            return "INSTALLED · \(status.versionLabel) · \(running)".uppercased()
        }
        return "NOT INSTALLED"
    }

    private var howTo: String {
        switch recipeID {
        case GrokRecipe().id:
            return "Grok Bot has no account switcher. Make Work and Personal clones, launch each, and sign into a different account. Both stay signed in."
        case ClaudeRecipe().id:
            return "Claude Desktop has no account switcher. Make a clone per login, launch it, and sign in there. Repeat for each Anthropic account you need."
        case ChatGPTRecipe().id:
            return "ChatGPT Desktop (Codex) has no account switcher. Make a clone per login, launch it, and sign in there. Repeat for each OpenAI account you need."
        default:
            return "Cursor has no account switcher. Make a clone per login, launch it, and sign in there. Repeat for each account you need."
        }
    }
}

struct E2BPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(E2B.bg)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(E2B.content.opacity(configuration.isPressed ? 0.85 : 1)))
    }
}

struct E2BSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(E2B.content)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .stroke(E2B.strokeHover, lineWidth: 1)
                    .background(Capsule().fill(E2B.bgSecondary.opacity(configuration.isPressed ? 0.6 : 1)))
            )
    }
}

struct SupportedAppIcon: View {
    @EnvironmentObject private var model: AppModel
    var recipeID: String
    var size: CGFloat
    var showsCaption: Bool

    private var recipe: any AppRecipe {
        RecipeRegistry.recipe(id: recipeID) ?? GrokRecipe()
    }

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let icon = IconComposer.baseIcon(for: recipeID) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(E2B.bgSecondary)
                        .overlay {
                            Image(systemName: "app.fill")
                                .font(.system(size: size * 0.4))
                                .foregroundStyle(E2B.tertiary)
                        }
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .stroke(E2B.stroke, lineWidth: 1)
            )

            if showsCaption {
                Text(recipe.displayName.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(E2B.secondary)
            }
        }
        .padding(4)
        .contentShape(Rectangle())
    }
}
