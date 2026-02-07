import Foundation

/// Centralized keys for scene/window restoration metadata.
///
/// Keep these keys stable across versions so iOS can restore multi-window state
/// without depending on hardcoded scene name formats.
enum SceneRestorationKeys {
    static let browserWindowUUID = "browserWindowUUID"
    static let browserSceneID = "browserSceneID"
}
