import Foundation

/// Lightweight model used by the "companion" (secondary pane) feature.
///
/// อยู่ใน CoreKit เพื่อให้ Runtime/Tab ส่งข้อมูลไป UI ได้โดยไม่ต้องพึ่ง UI module.
public struct CompanionItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let urlString: String
    public let hint: String?

    public init(id: UUID = UUID(), title: String, urlString: String, hint: String? = nil) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.hint = hint
    }
}
