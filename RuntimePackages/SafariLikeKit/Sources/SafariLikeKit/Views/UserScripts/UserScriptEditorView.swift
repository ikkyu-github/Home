import SwiftUI
import SafariLikeContracts

struct UserScriptEditorView: View {
    let initialScript: UserScript?
    let isPrivateMode: Bool
    let onSave: (UserScript) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var descriptionText: String
    @State private var sourceCode: String
    @State private var injectionTime: InjectionTime
    @State private var enabled: Bool

    @State private var allowRegular: Bool
    @State private var allowPrivate: Bool

    @State private var includeHosts: String
    @State private var excludeHosts: String
    @State private var includeURLPatterns: String
    @State private var excludeURLPatterns: String

    @State private var saveError: String? = nil

    init(
        initialScript: UserScript?,
        isPrivateMode: Bool,
        onSave: @escaping (UserScript) async throws -> Void
    ) {
        self.initialScript = initialScript
        self.isPrivateMode = isPrivateMode
        self.onSave = onSave

        _name = State(initialValue: initialScript?.name ?? "")
        _descriptionText = State(initialValue: initialScript?.description ?? "")
        _sourceCode = State(initialValue: initialScript?.sourceCode ?? "")
        _injectionTime = State(initialValue: initialScript?.injectionTime ?? .documentEnd)
        _enabled = State(initialValue: initialScript?.isEnabled ?? true)

        let profiles = initialScript?.profilesAllowed ?? Set(UserScriptProfile.allCases)
        _allowRegular = State(initialValue: profiles.contains(.regular))
        _allowPrivate = State(initialValue: profiles.contains(.private))

        let rules = initialScript?.matchRules ?? UserScriptMatchRules()
        _includeHosts = State(initialValue: rules.includeHosts.joined(separator: ", "))
        _excludeHosts = State(initialValue: rules.excludeHosts.joined(separator: ", "))
        _includeURLPatterns = State(initialValue: rules.includeURLPatterns.joined(separator: ", "))
        _excludeURLPatterns = State(initialValue: rules.excludeURLPatterns.joined(separator: ", "))
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                Group {
                    if #available(iOS 16.0, *) {
                        TextField("Description", text: $descriptionText, axis: .vertical)
                            .lineLimit(2...6)
                    } else {
                        TextEditor(text: $descriptionText)
                            .frame(minHeight: 72)
                    }
                }
                Picker("Injection", selection: $injectionTime) {
                    Text("Document Start").tag(InjectionTime.documentStart)
                    Text("Document End").tag(InjectionTime.documentEnd)
                }
                Toggle("Enabled", isOn: $enabled)
            } header: {
                Text("Script")
            }

            Section {
                Toggle("Allow in Regular", isOn: $allowRegular)
                Toggle("Allow in Private", isOn: $allowPrivate)

                if isPrivateMode {
                    Text("Note: edits in Private mode are typically in-memory.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Profiles")
            }

            Section {
                TextField("Include hosts (comma-separated)", text: $includeHosts)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Exclude hosts (comma-separated)", text: $excludeHosts)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Include URL patterns (comma-separated)", text: $includeURLPatterns)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Exclude URL patterns (comma-separated)", text: $excludeURLPatterns)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("Hosts support `*` and `*.example.com`. URL patterns support `*` wildcards.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } header: {
                Text("Match Rules")
            }

            Section {
                TextEditor(text: $sourceCode)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 220)
            } header: {
                Text("Source")
            }

            if let saveError {
                Section {
                    Text(saveError)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle(initialScript == nil ? "New Script" : "Edit Script")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task { @MainActor in
                        await save()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func parseCSV(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    @MainActor
    private func save() async {
        saveError = nil

        let profiles: Set<UserScriptProfile> = {
            var s = Set<UserScriptProfile>()
            if allowRegular { s.insert(.regular) }
            if allowPrivate { s.insert(.private) }
            return s
        }()

        if profiles.isEmpty {
            saveError = "Select at least one profile (Regular or Private)."
            return
        }

        let rules = UserScriptMatchRules(
            includeHosts: parseCSV(includeHosts),
            excludeHosts: parseCSV(excludeHosts),
            includeURLPatterns: parseCSV(includeURLPatterns),
            excludeURLPatterns: parseCSV(excludeURLPatterns)
        )

        var script = initialScript ?? UserScript(
            name: name,
            description: descriptionText,
            sourceCode: sourceCode,
            bundledResourceName: nil,
            injectionTime: injectionTime,
            isEnabled: enabled,
            profilesAllowed: profiles,
            matchRules: rules
        )

        script.name = name
        script.description = descriptionText
        script.sourceCode = sourceCode
        script.bundledResourceName = nil
        script.injectionTime = injectionTime
        script.isEnabled = enabled
        script.profilesAllowed = profiles
        script.matchRules = rules

        do {
            try await onSave(script)
            dismiss()
        } catch {
            saveError = "Failed to save."
        }
    }
}
