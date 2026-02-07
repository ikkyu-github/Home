import Foundation
import SafariLikeCoreKit
/// Stable identity for a UIKit/SwiftUI scene.
///
/// Backed by `UISceneSession.persistentIdentifier`.
public struct SceneID: Hashable, Sendable {
    public let raw: String
    public init(raw: String) {
        self.raw = raw
    }
}
