import CoreGraphics

public enum UXLayoutMode: Sendable, Equatable {
    case phone
    case tabletLandscape
}

public enum UXCompanionPresentationMode: Sendable, Equatable {
    case overlay
    case sidebar
}

public struct UXPolicyResolver {

    public struct Inputs: Sendable, Equatable {
        public var safeWidth: CGFloat
        public var safeHeight: CGFloat
        public var layoutMode: UXLayoutMode

        public init(safeWidth: CGFloat, safeHeight: CGFloat, layoutMode: UXLayoutMode) {
            self.safeWidth = safeWidth
            self.safeHeight = safeHeight
            self.layoutMode = layoutMode
        }
    }

    public static func resolve(_ inputs: Inputs) -> UXPolicy {
        // Start from defaults and tune based on layout.
        var policy = UXPolicy.default

        // Overview distances feel better when derived from viewport.
        // Keep spring characteristics Safari-like.
        policy.tabOverview.physics.overview.openDistance = SafariPhysicsConfig.resolvedOverviewOpenDistance(containerWidth: inputs.safeWidth)

        // Gesture tuning by layout.
        switch inputs.layoutMode {
        case .phone:
            // Keep defaults.
            break
        case .tabletLandscape:
            // Slightly more intentional on iPad-like layouts.
            policy.gestures.tabOverviewFromChromeMinimumDistance = max(policy.gestures.tabOverviewFromChromeMinimumDistance, 14)
        }

        // iPad-ish companion behavior.
        // Safari tends to prefer a persistent sidebar when there is enough width.
        // (Views should query resolved values rather than embedding cutoffs.)
        // Note: actual presentation mode decision can be performed at the UI layer
        // but uses this threshold.

        // Split enablement: conservative, phone-friendly.
        // The resolver does NOT clamp panes; the split controller should enforce `maxPanes`.
        policy.splitBrowser.maxPanes = 2

        // Optional: device-specific tweaks.
        switch inputs.layoutMode {
        case .phone:
            // Keep defaults.
            break
        case .tabletLandscape:
            // Slightly larger edge zone feels closer to iPad Safari.
            policy.swipeNavigation.edgeZoneWidth = max(policy.swipeNavigation.edgeZoneWidth, 24)
        }

        return policy
    }

    public static func companionPresentationMode(policy: UXPolicy, inputs: Inputs) -> UXCompanionPresentationMode {
        if inputs.layoutMode == .tabletLandscape { return .sidebar }
        if inputs.safeWidth >= policy.companion.minSidebarWidth { return .sidebar }
        return .overlay
    }

    public static func isSplitEnabled(policy: UXPolicy, inputs: Inputs) -> Bool {
        inputs.safeWidth >= policy.splitBrowser.splitEnabledMinWidth
    }
}
