import UIKit
import SwiftUI
import SafariLikeKit

/// UIKit host factory for embedding SafariLikeKit into a UIViewController hierarchy.
///
/// `SafariLikeUIKitHost` is the recommended factory for UIKit apps creating `UIHostingController`
/// instances that embed `SafariLikeBrowserView`. It encapsulates the factory pattern and returns
/// both the hosting controller and the underlying `BrowserSceneSession` for lifecycle management.
///
/// ## Typical Usage
/// ```swift
/// // In SceneDelegate
/// let (hostVC, session) = SafariLikeUIKitHost.makeHostingController(
///     sceneID: windowScene.session.persistentIdentifier,
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
    /// Create a UIHostingController wrapping SafariLikeBrowserView, paired with its BrowserSceneSession.
    public static func makeHostingController(
        sceneID: String,
        initialURL: String? = nil,
        configuration: SafariLikeConfiguration = .default,
        makeSettingsView: (() -> AnyView)? = nil
    ) -> (UIViewController, BrowserSceneSession) {
        let session = SafariLikeFactory.makeSceneSession(
            sceneID: sceneID,
            configuration: configuration
        )

        let host = UIHostingController(
            rootView: SafariLikeBrowserView(
                session: session,
                initialURL: initialURL,
                configuration: .constant(configuration),
                makeSettingsView: makeSettingsView
            )
        )
        host.view.backgroundColor = UIColor.black
        host.view.insetsLayoutMarginsFromSafeArea = false
        host.view.layoutMargins = UIEdgeInsets.zero
        host.view.preservesSuperviewLayoutMargins = false
        return (host, session)
    }
}
