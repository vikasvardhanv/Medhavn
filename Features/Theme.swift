import SwiftUI

public struct AppTheme {
    public static let primary = Color(UIColor { traitCollection in
        // Premium Warm Gold-Yellow (#F2C94C)
        return UIColor(red: 0.95, green: 0.79, blue: 0.30, alpha: 1.0)
    })
    
    public static let secondary = Color(UIColor { traitCollection in
        // Sleek Slate Grey
        return UIColor(red: 0.61, green: 0.62, blue: 0.67, alpha: 1.0)
    })
    
    public static let success = Color(UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 0.08, green: 0.80, blue: 0.50, alpha: 1.0) // Neon Green
        } else {
            return UIColor(red: 0.08, green: 0.60, blue: 0.38, alpha: 1.0)
        }
    })
    
    public static let danger = Color(UIColor { traitCollection in
        return UIColor(red: 1.00, green: 0.28, blue: 0.44, alpha: 1.0) // Coral Red
    })
    
    public static let warning = Color(UIColor { traitCollection in
        return UIColor(red: 1.00, green: 0.65, blue: 0.00, alpha: 1.0)
    })
    
    public static let info = Color(UIColor { traitCollection in
        return UIColor(red: 0.60, green: 0.40, blue: 1.00, alpha: 1.0) // Electric Purple
    })
    
    public static let cardBackground = Color(UIColor { traitCollection in
        // Sleek Obsidian Charcoal (#1B1E26)
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 0.85)
        } else {
            return UIColor(red: 0.13, green: 0.14, blue: 0.18, alpha: 0.90) // Dark matte even in light mode for consistency
        }
    })
    
    // Matte dark backgrounds
    public static let meshStart = Color(UIColor { traitCollection in
        return UIColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1.0) // Matte black space
    })
    
    public static let meshEnd = Color(UIColor { traitCollection in
        return UIColor(red: 0.10, green: 0.11, blue: 0.15, alpha: 1.0) // Deep slate black
    })
    
    public static let glowPurple = Color(UIColor { traitCollection in
        return UIColor(red: 0.60, green: 0.40, blue: 1.00, alpha: 0.06)
    })
    
    public static let glowTeal = Color(UIColor { traitCollection in
        return UIColor(red: 0.95, green: 0.79, blue: 0.30, alpha: 0.04) // Gold ambient glow
    })
    
    public static let glowIndigo = Color(UIColor { traitCollection in
        return UIColor(red: 0.20, green: 0.30, blue: 0.80, alpha: 0.05)
    } )

    // Categorical accent colors — themed to match dark matte aesthetic
    public static let accentBlue = Color(UIColor { _ in
        UIColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1.0)
    })

    public static let accentTeal = Color(UIColor { _ in
        UIColor(red: 0.15, green: 0.70, blue: 0.70, alpha: 1.0)
    })
}

public struct GlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    
    public init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }
    
    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Translucent blur with dark obsidian fill
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    AppTheme.cardBackground
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.12),
                                .white.opacity(0.03),
                                .black.opacity(0.10),
                                .white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(color: Color.black.opacity(0.20), radius: 10, x: 0, y: 5)
            .shadow(color: Color.black.opacity(0.12), radius: 25, x: 0, y: 15)
    }
}

public struct StaggeredEntranceModifier: ViewModifier {
    public let delay: Double
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init(delay: Double) {
        self.delay = delay
    }
    
    public func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .opacity(isVisible ? 1.0 : 0.0)
                .offset(y: isVisible ? 0 : 16)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                        isVisible = true
                    }
                }
        }
    }
}

public struct MeshBackgroundView: View {
    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Base background
            LinearGradient(
                colors: [AppTheme.meshStart, AppTheme.meshEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if !reduceMotion {
                // Layered radial glows
                ZStack {
                    RadialGradient(
                        colors: [AppTheme.glowIndigo, Color.clear],
                        center: .init(x: animate ? 0.2 : 0.8, y: animate ? 0.3 : 0.7),
                        startRadius: 50,
                        endRadius: 450
                    )
                    
                    RadialGradient(
                        colors: [AppTheme.glowTeal, Color.clear],
                        center: .init(x: animate ? 0.8 : 0.2, y: animate ? 0.2 : 0.8),
                        startRadius: 50,
                        endRadius: 400
                    )
                    
                    RadialGradient(
                        colors: [AppTheme.glowPurple, Color.clear],
                        center: .init(x: animate ? 0.3 : 0.7, y: animate ? 0.8 : 0.2),
                        startRadius: 50,
                        endRadius: 350
                    )
                }
                .blur(radius: 60)
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 12.0).repeatForever(autoreverses: true)) {
                        animate = true
                    }
                }
            }
        }
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
    
    func staggeredEntrance(delay: Double) -> some View {
        self.modifier(StaggeredEntranceModifier(delay: delay))
    }
}

public extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
