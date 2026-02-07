public typealias TabGroup = BrowserTabGroup
import Foundation

public struct BrowserTabGroup: Identifiable, Hashable, Codable, Sendable {
	public let id: UUID
	public var name: String
	public var color: TabGroupColor
	public var tabIDs: [UUID]
	public var createdAt: Date
	public var lastModifiedAt: Date

	public init(
		id: UUID = UUID(),
		name: String,
		color: TabGroupColor = .blue,
		tabIDs: [UUID] = [],
		createdAt: Date = Date(),
		lastModifiedAt: Date = Date()
	) {
		self.id = id
		self.name = name
		self.color = color
		self.tabIDs = tabIDs
		self.createdAt = createdAt
		self.lastModifiedAt = lastModifiedAt
	}

	public enum TabGroupColor: String, Codable, CaseIterable, Sendable {
		case blue, red, orange, yellow, green, purple, pink, gray
	}
}
