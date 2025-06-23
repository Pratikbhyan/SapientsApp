import SwiftUI

/// Enum representing appearance choices available to the user.
public enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case lightMono
    case darkMono
    public var id: String { rawValue }
}

/// Observable object that stores and publishes theme selection.
@MainActor
public final class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") private var storedTheme: String = AppTheme.system.rawValue
    @Published public var selection: AppTheme = .system {
        didSet { storedTheme = selection.rawValue }
    }

    public init() {
        self.selection = AppTheme(rawValue: storedTheme) ?? .system
    }
}
