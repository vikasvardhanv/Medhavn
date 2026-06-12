import SwiftUI

// MARK: - Global adaptive layout utilities
// Use these modifiers in any view to automatically adapt for iPhone and iPad.

extension View {
    /// Constrains content to a readable max width and centers it on iPad.
    /// On iPhone: full width. On iPad: capped at 720pt, centered.
    func adaptiveContentWidth() -> some View {
        modifier(AdaptiveWidthModifier())
    }
}

struct AdaptiveWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSizeClass

    func body(content: Content) -> some View {
        if hSizeClass == .regular {
            content
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

/// A vertically and horizontally centered scroll container.
/// Use for full-screen forms on iPad (auth, consent, etc).
struct AdaptiveScrollCenter<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack {
                    if hSizeClass == .regular { Spacer(minLength: 0) }
                    content()
                        .frame(maxWidth: hSizeClass == .regular ? 560 : .infinity)
                        .padding(.horizontal, hSizeClass == .regular ? 0 : 20)
                    if hSizeClass == .regular { Spacer(minLength: 0) }
                }
                .frame(minHeight: geo.size.height)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
