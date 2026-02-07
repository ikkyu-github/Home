import SwiftUI
import SafariLikeContracts
/// Full-screen overlay shown while the omnibox is focused.
/// Provides a blur/dim backdrop and taps dismiss focus.
internal struct OmniboxOverlayView: View {
    @ObservedObject var bar: SplitBrowserAddressBarDomain
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Color.black.opacity(0.18)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                bar.send(SafariLikeContracts.AddressBarEvent.cancelEditing)
            }
    }
}
