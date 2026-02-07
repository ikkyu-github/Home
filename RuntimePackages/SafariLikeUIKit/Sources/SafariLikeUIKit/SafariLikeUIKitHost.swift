import Foundation
import UIKit
import SwiftUI
import SafariLikeKit
import BrowserCore

/// UIKit host factory for embedding SafariLikeKit into a UIViewController hierarchy.
///
/// `SafariLikeUIKitHost` is the recommended factory for UIKit apps creating `UIHostingController`
/// instances that embed `SafariLikeBrowserView`. It encapsulates the factory pattern and returns
/// both the hosting controller and the underlying `BrowserSceneSession` for lifecycle management.
///
/// ## Typical Usage
/// ```swift
/// // In SceneDelegate / composition root
/// let session = SafariLikeFactory.makeSceneSession(
///     sceneID: windowScene.session.persistentIdentifier,
///     configuration: .default
/// )
/// let hostVC = SafariLikeUIKitHost.makeHostingController(
///     session: session,
///     initialURL: resolvedInitialURL,
///     configuration: .default,
///     makeSettingsView: nil
/// )
/// window.rootViewController = hostVC
/// self.sceneSession = session
///
/// // In lifecycle handlers
/// session.openExternalURL(url)
/// session.persistSessionNow()
/// session.invalidateSession()
/// ```
@MainActor
public enum SafariLikeUIKitHost {
    /// Create a UIHostingController wrapping SafariLikeBrowserView.
    ///
    /// SafariLikeUIKit is downstream of runtime; it **hosts** sessions but does not create them.
    public static func makeHostingController(
        session: SafariLikeKit.BrowserSceneSession,
        siteHeuristicsStore: SiteHeuristicsStore,
        initialURL: String? = nil,
        configuration: SafariLikeConfiguration = .default,
        makeSettingsView: (() -> AnyView)? = nil
    ) -> UIViewController {
        let resolvedSettingsView: () -> AnyView = makeSettingsView ?? { AnyView(EmptyView()) }
        let host = UIHostingController(
            rootView: SafariLikeKit.SafariLikeBrowserView(
                session: session,
                context: session.makeSceneRuntimeContext(siteHeuristicsStore: siteHeuristicsStore),
                initialURL: nil,
                configuration: .constant(configuration),
                makeSettingsView: resolvedSettingsView
            )
        )
        host.view.backgroundColor = UIColor.systemBackground
        host.view.insetsLayoutMarginsFromSafeArea = false
        host.view.layoutMargins = UIEdgeInsets.zero
        host.view.preservesSuperviewLayoutMargins = false

        if let urlString = initialURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            session.openExternalURL(url)
        }
        return host
    }
}
