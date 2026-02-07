import Foundation

/// Centralized UI layout policy (z-ordering, layering).
///
/// Design goals:
/// - Single source of truth for layering and view stacking
/// - Keep as pure values (no SwiftUI dependency)
public struct LayoutPolicy: Sendable, Equatable {

    public struct ZOrder: Sendable, Equatable {
        public var webContent: Double
        public var startPage: Double
        public var relatedSidebar: Double
        public var relatedOverlay: Double
        public var chrome: Double
        public var companion: Double
        public var tabOverview: Double
        public var omniboxOverlay: Double

        public init(
            webContent: Double,
            startPage: Double,
            relatedSidebar: Double,
            relatedOverlay: Double,
            chrome: Double,
            companion: Double,
            tabOverview: Double,
            omniboxOverlay: Double
        ) {
            self.webContent = webContent
            self.startPage = startPage
            self.relatedSidebar = relatedSidebar
            self.relatedOverlay = relatedOverlay
            self.chrome = chrome
            self.companion = companion
            self.tabOverview = tabOverview
            self.omniboxOverlay = omniboxOverlay
        }

        public static let `default` = ZOrder(
            webContent: 0,
            startPage: 10,
            relatedSidebar: 20,
            relatedOverlay: 50,
            chrome: 100,
            companion: 200,
            tabOverview: 1000,
            omniboxOverlay: 3000
        )
    }

    public var zOrder: ZOrder

    public init(zOrder: ZOrder) {
        self.zOrder = zOrder
    }

    public static let `default` = LayoutPolicy(zOrder: .default)
}
