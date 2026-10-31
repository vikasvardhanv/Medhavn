import SwiftUI

/// One-time question for accounts created before sex was collected at sign-up.
/// It decides which health sections the Hub shows. "Prefer not to say" keeps everything visible.
struct SexPromptView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.primary)
            Text("Personalise your Hub")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("We use this to show health tools that fit you, such as fertility tracking or men's health. You can change it later.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
            VStack(spacing: 10) {
                ForEach(Sex.allCases) { option in
                    Button { appState.setSex(option) } label: {
                        Text(option.title)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.primary.opacity(option == .preferNot ? 0.5 : 1))
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { MeshBackgroundView() }
    }
}
