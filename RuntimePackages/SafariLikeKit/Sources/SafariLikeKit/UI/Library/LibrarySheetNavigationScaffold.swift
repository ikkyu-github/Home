import SwiftUI
import SafariLikeCoreKit
/// Shared NavigationStack/NavigationView wrapper for Library sheets.
///
/// This keeps iOS 15/16 navigation + toolbar differences in one place.
internal struct LibrarySheetNavigationScaffold<Content: View>: View {
    let title: String
    let showsClearButton: Bool
    let clearButtonSystemImage: String
    let onClear: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    init(
        title: String,
        showsClearButton: Bool,
        clearButtonSystemImage: String = "trash",
        onClear: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showsClearButton = showsClearButton
        self.clearButtonSystemImage = clearButtonSystemImage
        self.onClear = onClear
        self.content = content
    }
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content()
                    .navigationTitle(title)
            }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if showsClearButton {
                        Button(role: .destructive) {
                            onClear()
                        } label: {
                            Image(systemName: clearButtonSystemImage)
                        }
                    }
                }
                #else
                ToolbarItem {
                    Button("Close") { dismiss() }
                }
                ToolbarItem {
                    if showsClearButton {
                        Button(role: .destructive) {
                            onClear()
                        } label: {
                            Image(systemName: clearButtonSystemImage)
                        }
                    }
                }
                #endif
            }
        } else {
            #if os(iOS)
            NavigationView {
                content()
                    .navigationTitle(title)
            }
            .navigationViewStyle(.stack)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if showsClearButton {
                        Button(role: .destructive) {
                            onClear()
                        } label: {
                            Image(systemName: clearButtonSystemImage)
                        }
                    }
                }
            }
            #else
            NavigationView {
                content()
                    .navigationTitle(title)
            }
            .toolbar {
                ToolbarItem {
                    Button("Close") { dismiss() }
                }
                ToolbarItem {
                    if showsClearButton {
                        Button(role: .destructive) {
                            onClear()
                        } label: {
                            Image(systemName: clearButtonSystemImage)
                        }
                    }
                }
            }
            #endif
        }
    }
}
