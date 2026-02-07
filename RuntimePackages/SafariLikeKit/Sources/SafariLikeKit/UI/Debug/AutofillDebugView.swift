import SwiftUI
import SafariLikeContracts
import SafariLikeCoreKit

#if DEBUG

struct AutofillDebugView: View {
    @ObservedObject var vm: SplitBrowserViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var availability: AutofillAvailability?
    @State private var isRefreshing: Bool = false

    private var activeSiteKey: SiteKey? {
        vm.activeURLString
            .flatMap { URL(string: $0)?.host }
            .map { SiteKey(host: $0) }
    }

    private var profile: WebsiteDataProfile {
        vm.isPrivateMode ? .private : .regular
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("System")) {
                    if let availability {
                        row("isEnabled", availability.isEnabled)
                        row("supportsPasswords", availability.supportsPasswords)
                        row("supportsPasskeys", availability.supportsPasskeys)
                        Text("lastCheckedAt: \(availability.lastCheckedAt.formatted())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No cached availability yet")
                            .foregroundColor(.secondary)
                    }

                    Button(isRefreshing ? "Checking…" : "Refresh") {
                        Task { await refresh() }
                    }
                    .disabled(isRefreshing)
                }

                Section(header: Text("Policy")) {
                    if let activeSiteKey {
                        let policy = vm.formFillPolicyEngine.effectivePolicy(siteKey: activeSiteKey, profile: profile)
                        Text("siteKey: \(activeSiteKey.storageKey)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        row("allowAutofill", policy.allowAutofill)
                        row("allowPasskeys", policy.allowPasskeys)
                        row("allowPasswordSaving", policy.allowPasswordSaving)
                        row("profileIsPrivate", profile == .private)
                    } else {
                        Text("No active site")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Privacy")) {
                    Text("No form contents, credentials, or passkey payloads are collected.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Autofill Debug")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadCached()
            }
        }
    }

    private func row(_ title: String, _ value: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value ? "true" : "false")
                .foregroundColor(.secondary)
        }
    }

    private func loadCached() async {
        availability = await vm.autofillStatusService.lastKnownAvailability()
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        availability = await vm.autofillStatusService.refresh()
    }
}

#endif
