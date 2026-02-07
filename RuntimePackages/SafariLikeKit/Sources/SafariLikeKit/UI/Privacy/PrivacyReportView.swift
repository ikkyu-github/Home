import SwiftUI
import SafariLikeContracts
import SafariLikeCoreKit

internal struct PrivacyReportView: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var snapshot: PrivacyReportSnapshot?
    @State private var isLoading: Bool = false

    private var websiteDataProfile: WebsiteDataProfile {
        vm.isPrivateMode ? .private : .regular
    }

    var body: some View {
        NavigationView {
            Group {
                if let snapshot {
                    List {
                        Section {
                            row(title: "Sites With Website Data", value: "\(snapshot.sitesWithWebsiteDataCount)")
                            row(title: "Content Blocker Exceptions", value: "\(snapshot.contentBlockerExceptionsCount)")
                            row(title: "Trackers Blocked", value: snapshot.trackersBlockedCount.map(String.init) ?? "—")
                        }

                        Section(header: Text("Permissions")) {
                            ForEach(snapshot.permissionSummaries, id: \.permissionType) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.permissionType.rawValue)
                                        .font(.headline)
                                    Text("allow \(item.counts.allow)  deny \(item.counts.deny)  ask \(item.counts.ask)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Section {
                            Text("Generated: \(snapshot.generatedAt.formatted(date: .abbreviated, time: .standard))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if isLoading {
                    ProgressView("Generating…")
                } else {
                    VStack(spacing: 12) {
                        Text("No snapshot")
                            .foregroundStyle(.secondary)
                        Button("Generate") {
                            Task { await refresh() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Privacy Report")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task { await refresh() }
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                await loadCachedIfAvailable()
                await refresh()
            }
        }
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func loadCachedIfAvailable() async {
        if websiteDataProfile == .regular {
            let cached = await vm.privacyReportSnapshotStore.latestSnapshot()
            if snapshot == nil {
                snapshot = cached
            }
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let snap = await vm.privacyReportEngine.generateSnapshot(profile: websiteDataProfile)
        snapshot = snap

        if websiteDataProfile == .regular {
            await vm.privacyReportSnapshotStore.setLatestSnapshot(snap)
        }
    }
}
