import SwiftUI

// MARK: - Dark‑theme foundations
// A single place to keep all custom colours & depth helpers so we don't sprinkle raw values around.

extension Color {
    /// Primary background for the whole app (≈ Apple's #1C1C1E).
    static let backgroundPrimary = Color(red: 28/255, green: 28/255, blue: 30/255)

    /// Slightly lighter surface used for cards, list rows, etc. Conveys elevation without shadows.
    static let surfaceElevated = Color(red: 44/255, green: 44/255, blue: 46/255)
}

// MARK: - Elevation helper

private struct SurfaceCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.surfaceElevated)
            .cornerRadius(12)
            // A very soft shadow adds one extra step of depth without feeling heavy.
            .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}

extension View {
    /// Apply to any container that should look like a raised card.
    func surfaceCard() -> some View {
        modifier(SurfaceCardModifier())
    }

    /// Attach to a top‑level container (e.g. `NavigationView { … }`) to get a consistent dark background everywhere.
    func appBackground() -> some View {
        background(Color.backgroundPrimary).ignoresSafeArea()
    }
}