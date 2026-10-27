import SwiftUI

/// MotorMind's calm, clinical color palette.
enum Theme {
    static let navy = Color(red: 0.039, green: 0.086, blue: 0.157)          // #0A1628 background
    static let surface = Color(red: 0.078, green: 0.145, blue: 0.247)       // #14253F cards
    static let surfaceRaised = Color(red: 0.118, green: 0.208, blue: 0.333) // #1E3555
    static let teal = Color(red: 0.204, green: 0.788, blue: 0.741)          // #34C9BD accent (right hand)
    static let amber = Color(red: 0.961, green: 0.698, blue: 0.341)         // #F5B257 (left hand, warnings)
    static let green = Color(red: 0.392, green: 0.820, blue: 0.494)         // #64D17E (stable)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.78)
}

// MARK: - Buttons

/// Big, full-width teal button.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.weight(.semibold))
            .foregroundStyle(Theme.navy)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Theme.teal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Big, full-width outlined button.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.weight(.semibold))
            .foregroundStyle(Theme.teal)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.teal, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

// MARK: - Card

struct Card<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Screen styling

extension View {
    /// Navy background plus navy navigation and tab bars.
    func screenStyle() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.navy.ignoresSafeArea())
            .toolbarBackground(Theme.navy, for: .navigationBar)
            .toolbarBackground(Theme.surface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}
