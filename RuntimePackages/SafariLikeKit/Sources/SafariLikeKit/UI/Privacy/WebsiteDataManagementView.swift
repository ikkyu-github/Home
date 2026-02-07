import SwiftUI
import SafariLikeContracts
import SafariLikeCoreKit

internal struct WebsiteDataManagementView: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var records: [WebsiteDataRecord] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    @State private var isConfirmClearAllPresented: Bool = false
    @State private var clearAllRange: ClearDataTimeRange = .allTime

    private var websiteDataProfile: WebsiteDataProfile {
        vm.isPrivateMode ? .private : .regular
    }

    private var filtered: [WebsiteDataRecord] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.isEmpty == false else { return records }
        return records.filter {
            $0.displayName.lowercased().contains(q) || $0.siteKey.storageKey.contains(q)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if let errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await refresh() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            HStack {
                                Text("Sites")
                                Spacer()
                                Text("\(records.count)")
                                    .foregroundStyle(.secondary)
                            }

                            Picker("Time Range", selection: $clearAllRange) {
                                Text("Last Hour").tag(ClearDataTimeRange.lastHour)
                                Text("Today").tag(ClearDataTimeRange.today)
                                Text("Today & Yesterday").tag(ClearDataTimeRange.todayAndYesterday)
                                Text("All Time").tag(ClearDataTimeRange.allTime)
                            }

                            Button(role: .destructive) {
                                isConfirmClearAllPresented = true
                            } label: {
                                Text("Remove All Website Data")
                            }
                            .disabled(websiteDataProfile == .private)
                        }

                        Section(header: Text("Website Data")) {
                            if isLoading {
                                ProgressView()
                            }

                            ForEach(filtered) { record in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(record.siteKey.storageKey)
                                        .font(.headline)
                                    Text("types: \(record.dataTypes.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Button(role: .destructive) {
                                        Task { await clearSite(record.siteKey) }
                                    } label: {
                                        Text("Remove Data for This Site")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Website Data")
            .searchable(text: $searchText, prompt: "Search")
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
            .confirmationDialog(
                "Remove All Website Data?",
                isPresented: $isConfirmClearAllPresented,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    Task { await clearAll() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes cookies, cache, and other website data.")
            }
            .task {
                await refresh()
            }
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            records = try await vm.websiteDataService.fetchRecords(profile: websiteDataProfile)
        } catch WebsiteDataServiceError.unsupportedProfile {
            errorMessage = "Private browsing data is non-persistent and isn’t enumerable in the current runtime configuration."
        } catch {
            errorMessage = "Failed to load website data."
        }
    }

    private func clearAll() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            try await vm.websiteDataService.clear(
                request: ClearWebsiteDataRequest(
                    profile: websiteDataProfile,
                    scope: .all(timeRange: clearAllRange)
                )
            )
            await refresh()
        } catch {
            errorMessage = "Failed to remove website data."
        }
    }

    private func clearSite(_ siteKey: SiteKey) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            try await vm.websiteDataService.clear(
                request: ClearWebsiteDataRequest(
                    profile: websiteDataProfile,
                    scope: .site(siteKey: siteKey)
                )
            )
            await refresh()
        } catch {
            errorMessage = "Failed to remove site data."
        }
    }
}
