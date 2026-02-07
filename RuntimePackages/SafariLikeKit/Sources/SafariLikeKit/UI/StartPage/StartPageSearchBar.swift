import SwiftUI
import SafariLikeUXKit
import SafariLikeCoreKit
internal struct StartPageSearchBar: View {
    @Environment(\.uxPolicy) private var uxPolicy
    @ObservedObject var stateStore: StartPageStateStore
    let keyboardHeight: CGFloat
    let safeAreaBottom: CGFloat
    let onSubmit: (String) -> Void
    @FocusState private var isFocused: Bool
    private var bottomLift: CGFloat {
        // keyboardHeight already includes the safe area; lift only by the delta.
        max(0, keyboardHeight - safeAreaBottom)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(uxPolicy.strings.addressPlaceholder, text: $stateStore.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .focused($isFocused)
                    .onSubmit {
                        let trimmed = stateStore.query.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.isEmpty == false else { return }
                        onSubmit(trimmed)
                        stateStore.endSearch()
                        isFocused = false
                    }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onChange(of: isFocused) { focused in
                if focused {
                    stateStore.beginSearch()
                } else if stateStore.state == .searching {
                    stateStore.transition(to: .idle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .offset(y: -bottomLift)
    }
}
