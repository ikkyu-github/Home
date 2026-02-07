import Foundation
import SafariLikeCoreKit
public struct WindowState: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    // MARK: - Safari-style window persistence
    public var sceneID: String
    public var activeTabIDs: [UUID]
    public var isSplitViewEnabled: Bool
    public var splitRatio: Double
    public var lastActivePane: String
    // MARK: - Legacy fields (kept for compatibility)
    public var selectedTabID: UUID?
    public var tabOrder: [UUID]
    public var splitMode: String? // e.g. "single", "split"
    public var activePane: String? // e.g. "left", "right"
    public init(
        id: UUID = UUID(),
        sceneID: String = "",
        activeTabIDs: [UUID] = [],
        isSplitViewEnabled: Bool = false,
        splitRatio: Double = 0.5,
        lastActivePane: String = "left",
        selectedTabID: UUID? = nil,
        tabOrder: [UUID] = [],
        splitMode: String? = nil,
        activePane: String? = nil
    ) {
        self.id = id
        self.sceneID = sceneID
        self.activeTabIDs = activeTabIDs
        self.isSplitViewEnabled = isSplitViewEnabled
        self.splitRatio = splitRatio
        self.lastActivePane = lastActivePane
        self.selectedTabID = selectedTabID
        self.tabOrder = tabOrder
        self.splitMode = splitMode
        self.activePane = activePane
    }
    private enum CodingKeys: String, CodingKey {
        case id
        case sceneID
        case activeTabIDs
        case isSplitViewEnabled
        case splitRatio
        case lastActivePane
        case selectedTabID
        case tabOrder
        case splitMode
        case activePane
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.sceneID = try container.decodeIfPresent(String.self, forKey: .sceneID) ?? ""
        self.activeTabIDs = try container.decodeIfPresent([UUID].self, forKey: .activeTabIDs) ?? []
        self.isSplitViewEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSplitViewEnabled) ?? false
        self.splitRatio = try container.decodeIfPresent(Double.self, forKey: .splitRatio) ?? 0.5
        // Prefer explicit lastActivePane; fall back to legacy activePane.
        let legacyPane = try container.decodeIfPresent(String.self, forKey: .activePane)
        self.lastActivePane = try container.decodeIfPresent(String.self, forKey: .lastActivePane) ?? legacyPane ?? "left"
        self.selectedTabID = try container.decodeIfPresent(UUID.self, forKey: .selectedTabID)
        self.tabOrder = try container.decodeIfPresent([UUID].self, forKey: .tabOrder) ?? []
        self.splitMode = try container.decodeIfPresent(String.self, forKey: .splitMode)
        self.activePane = legacyPane
    }
}
