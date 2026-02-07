import SwiftUI

struct PerformanceSettingsSheet: View {

    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    PerformanceSettingsView(settings: settings)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { dismiss() }
                            }
                        }
                }
            } else {
                NavigationView {
                    PerformanceSettingsView(settings: settings)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { dismiss() }
                            }
                        }
                }
                .navigationViewStyle(.stack)
            }
        }
    }
}
