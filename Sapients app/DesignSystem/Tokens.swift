import SwiftUI

/// Single-source-of-truth design tokens.  
/// Add/modify only here to propagate across the UI.
public enum Tokens {
    // MARK: – Grid & Spacing
    public static let grid: CGFloat = 4 // Base 4-pt rhythm
    public enum Spacing {
        public static let xs: CGFloat = grid * 1   // 4
        public static let s:  CGFloat = grid * 2   // 8
        public static let m:  CGFloat = grid * 3   // 12
        public static let l:  CGFloat = grid * 4   // 16
        public static let xl: CGFloat = grid * 6   // 24
        public static let xxl: CGFloat = grid * 8  // 32
    }

    // MARK: – Corner Radius
    public enum Corner {
        public static let r1: CGFloat = 4
        public static let r2: CGFloat = 8
        public static let r3: CGFloat = 12
        public static let r4: CGFloat = 20
    }

    // MARK: – Elevation / Shadows
    public enum Elevation {
        /// No shadow
        public static let e0: Shadow = .init(radius: 0, y: 0, opacity: 0)
        /// Card shadow – light
        public static let e1: Shadow = .init(radius: 4, y: 1, opacity: 0.12)
        /// Modal shadow – heavier
        public static let e2: Shadow = .init(radius: 12, y: 4, opacity: 0.16)

        public struct Shadow {
            let radius: CGFloat
            let y: CGFloat
            let opacity: Double
        }
    }

    // MARK: – Color Palette (requires matching assets in Assets.xcassets)
    public enum Palette {
        public static let canvas   = Color("Canvas")
        public static let primary  = Color("Primary")
        public static let progress = Color("Progress")
        public static let ink      = Color("Ink")
    }

    // MARK: – Typography
    public enum FontStyle {
        public static var display1: Font { serifBold(size: 34) }
        public static var title1:   Font { serifSemi(size: 28) }
        public static var title2:   Font { sansSemi(size: 22) }
        public static var body1:    Font { sansRegular(size: 17) }
        public static var caption:  Font { sansRegular(size: 15) }

        // Helpers
        private static func serifBold(size: CGFloat) -> Font {
            Font.custom("NewYorkSerif-Bold", size: size, relativeTo: .largeTitle)
        }
        private static func serifSemi(size: CGFloat) -> Font {
            Font.custom("NewYorkSerif-Semibold", size: size, relativeTo: .title)
        }
        private static func sansSemi(size: CGFloat) -> Font {
            .system(size: size, weight: .semibold, design: .default)
        }
        private static func sansRegular(size: CGFloat) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }
    }
}

// MARK: – View helpers
public extension View {
    /// Applies the specified elevation shadow from Tokens.
    func elevation(_ level: Tokens.Elevation.Shadow) -> some View {
        shadow(color: Color.black.opacity(level.opacity), radius: level.radius, x: 0, y: level.y)
    }

    /// Convenience for e-1 card.
    func cardShadow() -> some View { elevation(Tokens.Elevation.e1) }
} 