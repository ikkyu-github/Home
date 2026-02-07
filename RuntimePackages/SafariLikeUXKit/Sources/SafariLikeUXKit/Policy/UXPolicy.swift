import CoreGraphics

/// Unified UX policy for Safari-like interaction rules.
///
/// Design goals:
/// - Centralize thresholds/timings so views don't embed UX rules
/// - Keep as pure values (no SwiftUI dependency)
/// - Resolve per-device/per-layout via `UXPolicyResolver`
public struct UXPolicy: Sendable, Equatable {

    public struct GesturesPolicy: Sendable, Equatable {
        /// Enable Safari-like “drag from chrome to open tab overview”.
        public var isTabOverviewFromChromeEnabled: Bool
        /// Minimum distance for the chrome drag gesture to begin.
        public var tabOverviewFromChromeMinimumDistance: CGFloat
        /// Minimum distance for the tab overview interaction tracking gesture.
        public var tabOverviewInteractionMinimumDistance: CGFloat
        /// Minimum distance for per-card swipe interactions inside the overview.
        public var tabOverviewCardMinimumDistance: CGFloat

        public init(
            isTabOverviewFromChromeEnabled: Bool,
            tabOverviewFromChromeMinimumDistance: CGFloat,
            tabOverviewInteractionMinimumDistance: CGFloat,
            tabOverviewCardMinimumDistance: CGFloat
        ) {
            self.isTabOverviewFromChromeEnabled = isTabOverviewFromChromeEnabled
            self.tabOverviewFromChromeMinimumDistance = tabOverviewFromChromeMinimumDistance
            self.tabOverviewInteractionMinimumDistance = tabOverviewInteractionMinimumDistance
            self.tabOverviewCardMinimumDistance = tabOverviewCardMinimumDistance
        }

        public static let `default` = GesturesPolicy(
            isTabOverviewFromChromeEnabled: true,
            tabOverviewFromChromeMinimumDistance: 12,
            tabOverviewInteractionMinimumDistance: 1,
            tabOverviewCardMinimumDistance: 6
        )
    }

    public struct Strings: Sendable, Equatable {
        public var newTabTitle: String
        public var tabOverviewTitle: String
        public var addressPlaceholder: String

        public init(newTabTitle: String, tabOverviewTitle: String, addressPlaceholder: String) {
            self.newTabTitle = newTabTitle
            self.tabOverviewTitle = tabOverviewTitle
            self.addressPlaceholder = addressPlaceholder
        }

        public static let `default` = Strings(
            newTabTitle: "New Tab",
            tabOverviewTitle: "Tab Overview",
            addressPlaceholder: "Search or enter website name"
        )
    }

    public struct ChromeCollapsePolicy: Sendable, Equatable {
        public struct Spring: Sendable, Equatable {
            public var response: Double
            public var dampingFraction: Double
            public var blendDuration: Double

            public init(response: Double, dampingFraction: Double, blendDuration: Double) {
                self.response = response
                self.dampingFraction = dampingFraction
                self.blendDuration = blendDuration
            }
        }

        /// When snapping at end of scroll, the progress threshold to choose collapsed.
        public var snapThreshold: CGFloat

        /// Collapse distance rule: max(minDistance, heightRange * multiplier).
        public var collapseDistanceMin: CGFloat
        public var collapseDistanceHeightMultiplier: CGFloat

        /// Safari-like: upward scroll reveals faster than downward collapses.
        public var revealBoostMultiplier: CGFloat

        public var snapSpring: Spring

        public init(
            snapThreshold: CGFloat,
            collapseDistanceMin: CGFloat,
            collapseDistanceHeightMultiplier: CGFloat,
            revealBoostMultiplier: CGFloat,
            snapSpring: Spring
        ) {
            self.snapThreshold = snapThreshold
            self.collapseDistanceMin = collapseDistanceMin
            self.collapseDistanceHeightMultiplier = collapseDistanceHeightMultiplier
            self.revealBoostMultiplier = revealBoostMultiplier
            self.snapSpring = snapSpring
        }

        public static let `default` = ChromeCollapsePolicy(
            snapThreshold: 0.5,
            collapseDistanceMin: 120,
            collapseDistanceHeightMultiplier: 2.5,
            revealBoostMultiplier: 1.6,
            snapSpring: .init(response: 0.28, dampingFraction: 0.88, blendDuration: 0)
        )
    }

    public struct AddressBarPolicy: Sendable, Equatable {
        public var microInteractions: MicroInteractionConfig

        public init(microInteractions: MicroInteractionConfig) {
            self.microInteractions = microInteractions
        }

        public static let `default` = AddressBarPolicy(microInteractions: .init())
    }

    public struct EdgeSwipeNavigationPolicy: Sendable, Equatable {
        public var edgeZoneWidth: CGFloat
        public var commitProgressThreshold: CGFloat
        public var commitVelocityThreshold: CGFloat
        /// Prefer horizontal intent: require `abs(vx) >= abs(vy) * ratio`.
        public var horizontalIntentRatio: CGFloat

        public init(
            edgeZoneWidth: CGFloat,
            commitProgressThreshold: CGFloat,
            commitVelocityThreshold: CGFloat,
            horizontalIntentRatio: CGFloat
        ) {
            self.edgeZoneWidth = edgeZoneWidth
            self.commitProgressThreshold = commitProgressThreshold
            self.commitVelocityThreshold = commitVelocityThreshold
            self.horizontalIntentRatio = horizontalIntentRatio
        }

        public static let `default` = EdgeSwipeNavigationPolicy(
            edgeZoneWidth: 22,
            commitProgressThreshold: 0.35,
            commitVelocityThreshold: 1100,
            horizontalIntentRatio: 1.15
        )
    }

    public struct TabOverviewPolicy: Sendable, Equatable {
        /// Master switch for Tab Overview UI + gestures.
        public var isEnabled: Bool
        public var physics: SafariPhysicsConfig
        public var layout: OverviewLayoutPolicy
        /// Debounce for overview thumbnail refresh.
        public var thumbnailCaptureCooldownSeconds: Double

        public init(
            isEnabled: Bool,
            physics: SafariPhysicsConfig,
            layout: OverviewLayoutPolicy,
            thumbnailCaptureCooldownSeconds: Double
        ) {
            self.isEnabled = isEnabled
            self.physics = physics
            self.layout = layout
            self.thumbnailCaptureCooldownSeconds = thumbnailCaptureCooldownSeconds
        }

        public static let `default` = TabOverviewPolicy(
            isEnabled: true,
            physics: .default,
            layout: .default,
            thumbnailCaptureCooldownSeconds: 0.8
        )
    }

    public struct CompanionPolicy: Sendable, Equatable {
        /// If `safeWidth >= minSidebarWidth`, prefer sidebar presentation (Safari iPad-like).
        public var minSidebarWidth: CGFloat

        public init(minSidebarWidth: CGFloat) {
            self.minSidebarWidth = minSidebarWidth
        }

        public static let `default` = CompanionPolicy(minSidebarWidth: 600)
    }

    public struct SplitBrowserPolicy: Sendable, Equatable {
        public var maxPanes: Int
        public var splitEnabledMinWidth: CGFloat
        public var minPaneWidth: CGFloat
        public var defaultSplitRatio: CGFloat

        public init(maxPanes: Int, splitEnabledMinWidth: CGFloat, minPaneWidth: CGFloat, defaultSplitRatio: CGFloat) {
            self.maxPanes = maxPanes
            self.splitEnabledMinWidth = splitEnabledMinWidth
            self.minPaneWidth = minPaneWidth
            self.defaultSplitRatio = defaultSplitRatio
        }

        public static let `default` = SplitBrowserPolicy(
            maxPanes: 2,
            splitEnabledMinWidth: 390,
            minPaneWidth: 320,
            defaultSplitRatio: 0.75
        )
    }

    public var strings: Strings
    public var addressBar: AddressBarPolicy
    public var chromeCollapse: ChromeCollapsePolicy
    public var swipeNavigation: EdgeSwipeNavigationPolicy
    public var tabOverview: TabOverviewPolicy
    public var companion: CompanionPolicy
    public var splitBrowser: SplitBrowserPolicy
    public var gestures: GesturesPolicy
    public var layout: LayoutPolicy

    public init(
        strings: Strings,
        addressBar: AddressBarPolicy,
        chromeCollapse: ChromeCollapsePolicy,
        swipeNavigation: EdgeSwipeNavigationPolicy,
        tabOverview: TabOverviewPolicy,
        companion: CompanionPolicy,
        splitBrowser: SplitBrowserPolicy,
        gestures: GesturesPolicy,
        layout: LayoutPolicy
    ) {
        self.strings = strings
        self.addressBar = addressBar
        self.chromeCollapse = chromeCollapse
        self.swipeNavigation = swipeNavigation
        self.tabOverview = tabOverview
        self.companion = companion
        self.splitBrowser = splitBrowser
        self.gestures = gestures
        self.layout = layout
    }

    public static let `default` = UXPolicy(
        strings: .default,
        addressBar: .default,
        chromeCollapse: .default,
        swipeNavigation: .default,
        tabOverview: .default,
        companion: .default,
        splitBrowser: .default,
        gestures: .default,
        layout: .default
    )
}
