import SwiftUI
import SafariLikeCoreKit
struct FindOnPageBarView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var chrome: BrowserChromeState
    @FocusState private var focused: Bool
    init(chrome: BrowserChromeState) {
        self.chrome = chrome
    }
    var body: some View {
        HStack(spacing: 10) {
            TextField("Find on Page", text: $chrome.findQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($focused)
                .onSubmit { chrome.onFindNext?() }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.thinMaterial)
                )
            Button {
                chrome.onFindPrevious?()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            Button {
                chrome.onFindNext?()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1), alignment: .top)
        )
        .onAppear {
            self.focused = true
        }
    }
}
