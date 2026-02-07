import Foundation

// MARK: - Public Type Alias for Compatibility
public typealias Tab = BrowserTab

public struct BrowserTab: Identifiable, Hashable, Codable, Sendable {
	public let id: UUID
	public var title: String
	public var urlString: String

	public enum State: Hashable, Codable, Sendable {
		case startPage
		case web(URL)
		case empty
	}

	public var state: State {
		get {
			let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
			if trimmed.isEmpty { return .empty }
			if trimmed.lowercased() == "about:blank" { return .startPage }
			if let url = URL(string: trimmed) { return .web(url) }
			return .empty
		}
		set {
			switch newValue {
			case .startPage:
				urlString = "about:blank"
			case .empty:
				urlString = ""
			case .web(let url):
				urlString = url.absoluteString
			}
		}
	}
	public var lifecycleState: TabLifecycleState = .active
	public var discardLevel: TabDiscardLevel = .keepAttached
	public var restoreToken: TabRestoreToken?
	public var isPinned: Bool = false
	public var isUserLocked: Bool = false
	public var lastVisitedAt: Date
	public var groupID: UUID?

	public init(
		id: UUID = UUID(),
		title: String = "New Tab",
		urlString: String = "about:blank",
		lifecycleState: TabLifecycleState = .active,
		discardLevel: TabDiscardLevel = .keepAttached,
		restoreToken: TabRestoreToken? = nil,
		isPinned: Bool = false,
		isUserLocked: Bool = false,
		lastVisitedAt: Date = Date(),
		groupID: UUID? = nil
	) {
		self.id = id
		self.title = title
		self.urlString = urlString
		self.lifecycleState = lifecycleState
		self.discardLevel = discardLevel
		self.restoreToken = restoreToken
		self.isPinned = isPinned
		self.isUserLocked = isUserLocked
		self.lastVisitedAt = lastVisitedAt
		self.groupID = groupID
	}
}
