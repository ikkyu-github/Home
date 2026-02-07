import SwiftUI

public struct OmnibarView: View {
    @ObservedObject private var coordinator: OmnibarCoordinator
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(coordinator: OmnibarCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(spacing: 0) {
            bar
            if case .showingSuggestions(let query) = coordinator.state {
                suggestions(query: query)
            }
        }
    }

    private var bar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search or enter website name", text: $text)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .onTapGesture { coordinator.send(.onTapBar) }
                .onChange(of: text) { newValue in coordinator.send(.onTextChange(text: newValue)) }
                .onSubmit { coordinator.submit(text) }

            if isFocused {
                Button("Cancel") {
                    if reduceMotion {
                        coordinator.cancelEditing()
                        isFocused = false
                    } else {
                        withAnimation(.easeOut(duration: 0.18)) {
                            coordinator.cancelEditing()
                            isFocused = false
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .onChange(of: isFocused) { newValue in coordinator.send(.onFocusChanged(isFocused: newValue)) }
    }

    private func suggestions(query: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                coordinator.submit(query)
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Search \(query)")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.top, 8)
    }
}
