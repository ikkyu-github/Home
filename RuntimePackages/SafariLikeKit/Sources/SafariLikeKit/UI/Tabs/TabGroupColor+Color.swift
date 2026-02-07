import SwiftUI
import SafariLikeCoreKit
extension TabGroupColor {
    var swiftUIColor: Color {
        switch self {
        case .blue: return Color(.systemBlue)
        case .red: return Color(.systemRed)
        case .green: return Color(.systemGreen)
        case .orange: return Color(.systemOrange)
        case .purple: return Color(.systemPurple)
        case .gray: return Color(.systemGray)
        @unknown default:
            return Color(.systemGray)
        }
    }
}
