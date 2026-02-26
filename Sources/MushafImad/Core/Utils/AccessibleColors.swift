import SwiftUI

/// Extension to fix Dark Mode contrast issues
/// Addresses issue #2: Fix Dark Mode Contrast in Settings
extension Color {
    /// Primary text color with WCAG AA compliance
    static var accessiblePrimary: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0) // Light text on dark
                : UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) // Dark text on light
        })
    }
    
    /// Secondary text color with proper contrast
    static var accessibleSecondary: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.70, green: 0.70, blue: 0.73, alpha: 1.0) // 4.5:1 contrast
                : UIColor(red: 0.38, green: 0.38, blue: 0.40, alpha: 1.0) // 4.5:1 contrast
        })
    }
    
    /// Background color with proper contrast
    static var accessibleBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) // Dark background
                : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0) // Light background
        })
    }
    
    /// Accent color with WCAG compliance
    static var accessibleAccent: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.35, green: 0.78, blue: 0.98, alpha: 1.0) // Bright cyan on dark
                : UIColor(red: 0.0, green: 0.48, blue: 0.73, alpha: 1.0) // Standard blue
        })
    }
}

/// View modifier for accessible settings rows
struct AccessibleSettingsRow: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(.accessiblePrimary)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.accessibleBackground)
            .cornerRadius(10)
    }
}

extension View {
    func accessibleSettingsStyle() -> some View {
        modifier(AccessibleSettingsRow())
    }
}
