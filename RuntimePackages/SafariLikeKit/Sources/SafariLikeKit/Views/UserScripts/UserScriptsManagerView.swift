import SwiftUI
import SafariLikeCoreKit
import SafariLikeContracts

struct UserScriptsManagerView: View {
    let userScriptStore: UserScriptStore
    let isPrivateMode: Bool

    @StateObject private var vm: UserScriptsManagerViewModel

    @State private var isEditorPresented: Bool = false
    @State private var editingScript: UserScript? = nil

    init(userScriptStore: UserScriptStore, isPrivateMode: Bool) {
        self.userScriptStore = userScriptStore
        self.isPrivateMode = isPrivateMode
        _vm = StateObject(wrappedValue: UserScriptsManagerViewModel(store: userScriptStore, isPrivateMode: isPrivateMode))
    }

    var body: some View {
        List {
            Section {
                Toggle(
                    "Enable User Scripts",
                    isOn: Binding(
                        get: { vm.policy.globalEnabled },
                        set: { newValue in
                            Task { @MainActor in await vm.setGlobalEnabled(newValue) }
                        }
                    )
                )

                Toggle(
                    "Allow in Private Browsing",
                    isOn: Binding(
                        get: { vm.policy.privateModeEnabled },
                        set: { newValue in
                            Task { @MainActor in await vm.setPrivateModeEnabled(newValue) }
                        }
                    )
                )

                if isPrivateMode && vm.policy.privateModeEnabled == false {
                    Text("Private mode: user scripts are disabled by default.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else if isPrivateMode {
                    Text("Private mode: changes are in-memory unless you enable private-mode scripts globally.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Policy")
            }

            Section {
                if vm.scripts.isEmpty {
                    Text("No user scripts")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(vm.scripts) { script in
                        Button {
                            editingScript = script
                            isEditorPresented = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(script.name)
                                        .font(.body)
                                    Text(script.injectionTime == .documentStart ? "Document Start" : "Document End")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { script.isEnabled },
                                        set: { newValue in
                                            Task { @MainActor in await vm.setScriptEnabled(script.id, enabled: newValue) }
                                        }
                                    )
                                )
                                .labelsHidden()
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { @MainActor in await vm.delete(script.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("Scripts")
            }
        }
        .navigationTitle("User Scripts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingScript = nil
                    isEditorPresented = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await vm.reload()
        }
        .refreshable {
            await vm.reload()
        }
        .sheet(isPresented: $isEditorPresented) {
            NavigationView {
                UserScriptEditorView(
                    initialScript: editingScript,
                    isPrivateMode: isPrivateMode,
                    onSave: { script in
                        try await vm.upsert(script)
                    }
                )
            }
        }
    }
}
