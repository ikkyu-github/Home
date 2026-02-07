import Combine
import Foundation

/// UI/UX-focused address bar entry state machine (focus/editing/draft/display + suggestion debounce).
///
/// This lives in UXKit and is intentionally generic over the suggestion type so it does not depend
/// on app or view-model types.
@MainActor
public final class AddressBarEntryStateMachine<Suggestion>: ObservableObject {

    public enum Mode: Equatable {
        case display
        case editing
    }

    private struct Snapshot: Equatable {
        var displayed: String
        var draft: String
        var committedURL: String?

        init(displayed: String = "", draft: String = "", committedURL: String? = nil) {
            self.displayed = displayed
            self.draft = draft
            self.committedURL = committedURL
        }
    }

    public enum Event: Equatable {
        case focusGained
        case focusLost
        case userTyped(String)
        case submit
        case cancel
        case navigationCommitted(String)
        case tabChanged(String?)
    }

    @Published public private(set) var mode: Mode
    @Published public var draftText: String
    @Published public private(set) var displayedText: String
    @Published public private(set) var shouldSelectAllOnFocus: Bool
    @Published public private(set) var suggestions: [Suggestion] = []

    private var snapshot: Snapshot

    private let suggest: @MainActor @Sendable (String) async -> [Suggestion]
    private let onSubmit: @MainActor @Sendable (String) -> Void

    private var suggestionTask: Task<Void, Never>?
    private let suggestionDebounceNanoseconds: UInt64 = 160_000_000

    public init(
        initialDisplayed: String = "",
        suggest: @escaping @MainActor @Sendable (String) async -> [Suggestion],
        onSubmit: @escaping @MainActor @Sendable (String) -> Void
    ) {
        self.mode = .display
        self.displayedText = initialDisplayed
        self.draftText = initialDisplayed
        self.shouldSelectAllOnFocus = false
        self.snapshot = Snapshot(displayed: initialDisplayed, draft: initialDisplayed, committedURL: nil)
        self.suggest = suggest
        self.onSubmit = onSubmit
    }

    public func reduce(_ event: Event) {
        switch event {
        case .focusGained:
            snapshot.displayed = displayedText
            snapshot.draft = displayedText
            draftText = snapshot.draft
            mode = .editing

            let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
            shouldSelectAllOnFocus = trimmed.isEmpty == false
            scheduleSuggestions(for: draftText)

        case .focusLost:
            if mode == .editing {
                draftText = snapshot.displayed
            }
            mode = .display
            shouldSelectAllOnFocus = false
            cancelSuggestions()
            suggestions = []

        case .userTyped(let text):
            guard mode == .editing else {
                // Defensive: if UI types while not editing, treat as entering editing.
                reduce(.focusGained)
                draftText = text
                scheduleSuggestions(for: text)
                return
            }
            draftText = text
            scheduleSuggestions(for: text)

        case .submit:
            guard mode == .editing else { return }
            let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return }

            cancelSuggestions()
            suggestions = []
            onSubmit(trimmed)

            mode = .display
            shouldSelectAllOnFocus = false

        case .cancel:
            guard mode == .editing else { return }
            draftText = snapshot.displayed
            cancelSuggestions()
            suggestions = []
            mode = .display
            shouldSelectAllOnFocus = false

        case .navigationCommitted(let urlString):
            snapshot.committedURL = urlString
            guard mode == .display else { return }
            displayedText = urlString
            draftText = urlString

        case .tabChanged(let urlString):
            snapshot.committedURL = urlString
            guard mode == .display else { return }
            let value = (urlString ?? "")
            displayedText = value
            draftText = value
        }
    }

    private func cancelSuggestions() {
        suggestionTask?.cancel()
        suggestionTask = nil
    }

    private func scheduleSuggestions(for text: String) {
        cancelSuggestions()

        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.isEmpty == false else {
            suggestions = []
            return
        }

        suggestionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: self.suggestionDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            let out = await self.suggest(q)
            guard !Task.isCancelled else { return }
            self.suggestions = out
        }
    }
}
