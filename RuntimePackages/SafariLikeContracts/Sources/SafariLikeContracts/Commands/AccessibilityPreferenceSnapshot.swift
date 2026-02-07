import Foundation

/// Accessibility/user preference snapshot that can be used to adapt UI behavior.
///
/// This is intentionally framework-neutral; any platform-specific values should be
/// normalized to primitives.
public struct AccessibilityPreferenceSnapshot: Codable, Sendable, Hashable {
    public var isReduceMotionEnabled: Bool
    public var isVoiceOverRunning: Bool
    public var isBoldTextEnabled: Bool
    public var isIncreaseContrastEnabled: Bool
    public var isDarkerSystemColorsEnabled: Bool

    /// Platform-normalized content size category identifier (best-effort).
    /// Example values: "UICTContentSizeCategoryL", "accessibilityExtraExtraExtraLarge".
    public var preferredContentSizeCategory: String?

    public init(
        isReduceMotionEnabled: Bool,
        isVoiceOverRunning: Bool,
        isBoldTextEnabled: Bool,
        isIncreaseContrastEnabled: Bool,
        isDarkerSystemColorsEnabled: Bool,
        preferredContentSizeCategory: String? = nil
    ) {
        self.isReduceMotionEnabled = isReduceMotionEnabled
        self.isVoiceOverRunning = isVoiceOverRunning
        self.isBoldTextEnabled = isBoldTextEnabled
        self.isIncreaseContrastEnabled = isIncreaseContrastEnabled
        self.isDarkerSystemColorsEnabled = isDarkerSystemColorsEnabled
        self.preferredContentSizeCategory = preferredContentSizeCategory
    }
}
