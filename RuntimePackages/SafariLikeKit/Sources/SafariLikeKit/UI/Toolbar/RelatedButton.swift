import SwiftUI
import SafariLikeCoreKit
struct RelatedButton: View {
    var action: (() -> Void)? = nil
    @EnvironmentObject private var relatedChrome: RelatedChromeState
    var body: some View {
        Button {
            relatedChrome.toggle(animation: .easeOut(duration: 0.25))
            action?()
        } label: {
            Image(systemName: "sidebar.right")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .layoutPriority(1000)
    }
}
