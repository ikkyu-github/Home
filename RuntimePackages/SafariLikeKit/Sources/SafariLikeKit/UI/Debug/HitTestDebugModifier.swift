import SwiftUI
import SafariLikeCoreKit
#if DEBUG
internal struct HitTestDebugModifier: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content
            .background(color.opacity(0.15))
            .overlay(
                Rectangle()
                    .stroke(color, lineWidth: 1)
                    .allowsHitTesting(false)
            )
    }
}
internal extension View {
    func hitDebug(_ color: Color) -> some View {
        if UserDefaults.standard.bool(forKey: "debug.hitTestOverlay") {
            return AnyView(self.modifier(HitTestDebugModifier(color: color)))
        } else {
            return AnyView(self)
        }
    }
}
#else
internal extension View {
    func hitDebug(_ color: Color) -> some View { self }
}
#endif
