import SwiftUI
import SafariLikeContracts

public struct NetworkDiagnosticsView: View {
    @ObservedObject private var model = NetworkDiagnosticsModel.shared

    public init() {}

    public var body: some View {
        List {
            Section("Network") {
                if let status = model.networkStatus {
                    row("Status", status.status.rawValue)
                    row("Interface", status.primaryInterface?.rawValue ?? "unknown")
                    row("Expensive", status.isExpensive ? "true" : "false")
                    row("Constrained", status.isConstrained ? "true" : "false")
                    row("IPv4", status.supportsIPv4 ? "true" : "false")
                    row("IPv6", status.supportsIPv6 ? "true" : "false")
                } else {
                    Text("No network snapshot yet")
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button("Clear Failures") {
                    model.clearFailures()
                }
            }

            Section("Recent Navigation Failures") {
                if model.recentNavigationFailures.isEmpty {
                    Text("No failures recorded")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(model.recentNavigationFailures) { rec in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(rec.category.rawValue)
                                .font(.headline)
                            Text([rec.urlHost, rec.urlScheme].compactMap { $0 }.joined(separator: " • "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(rec.errorDomain) (\(rec.errorCode))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if let msg = rec.message {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Network Diagnostics")
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
