import SwiftUI
import SafariLikeCoreKit
public struct LayoutEnvironmentKey: EnvironmentKey {
    public static let defaultValue: LayoutEnvironment = .compactSinglePane
}
public enum BrowserLayoutMode: Equatable {
    case phonePortrait
    case tabletLandscape

    internal static func from(chromeStyle: BrowserChromeStyle) -> BrowserLayoutMode {
        switch chromeStyle {
        case .phonePortraitSafari:
            return .phonePortrait
        case .padLandscapeSafari:
            return .tabletLandscape
        }
    }
    public var debugName: String {
        switch self {
        case .phonePortrait: return "phonePortrait"
        case .tabletLandscape: return "tabletLandscape"
        @unknown default: return "unknown"
        }
    }
}
public struct BrowserLayoutPolicy {
    public static func resolve(
        hSizeClass: UserInterfaceSizeClass?,
        safeWidth: CGFloat
    ) -> BrowserLayoutMode {
        if safeWidth >= 700 || hSizeClass == .regular {
            return .tabletLandscape
        } else {
            return .phonePortrait
        }
    }
}
public struct BrowserLayoutModeKey: EnvironmentKey {
    public static let defaultValue: BrowserLayoutMode = .phonePortrait
}
public extension EnvironmentValues {
    var browserLayoutMode: BrowserLayoutMode {
        get { self[BrowserLayoutModeKey.self] }
        set { self[BrowserLayoutModeKey.self] = newValue }
    }
    /// Runtime-driving layout environment (single-pane vs split-pane vs multi-window).
    var layoutEnvironment: LayoutEnvironment {
        get { self[LayoutEnvironmentKey.self] }
        set { self[LayoutEnvironmentKey.self] = newValue }
    }
}
