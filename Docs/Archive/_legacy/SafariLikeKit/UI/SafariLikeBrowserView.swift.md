import SwiftUI

/// SwiftUI root view for embedding SafariLikeKit into your app.
///
/// `SafariLikeBrowserView` is one of the **three public API entrypoints** for SafariLikeKit.
/// It bridges a ``BrowserSceneSession`` into SwiftUI and handles all internal wiring of ViewModels,
/// Runtime components, and UI state without exposing those types to your App.
///
/// ## Contract
/// - Obtain a ``BrowserSceneSession`` from ``SafariLikeUIKitHost.makeHostingController(sceneID:initialURL:configuration:makeSettingsView:)``
/// - Wrap this view in a `UIHostingController` (UIKit) or embed directly in SwiftUI hierarchy
/// - **Do NOT** import internal types like `SplitBrowserViewModel`, `BrowserEnvironment`, or `SplitBrowserRootView`
/// - **Do NOT** try to access `.viewModel` or internal state from outside
///
/// ## Typical Usage (SwiftUI)
/// ```swift
/// struct ContentView: View {
///     @State private var session: BrowserSceneSession?
///     @State private var config: SafariLikeConfiguration = .default
///
///     var body: some View {
///         if let session = session {
///             SafariLikeBrowserView(
///                 session: session,
///                 initialURL: "https://www.example.com",
///                 configuration: $config
///             )
///         } else {
///             Button("Start Browser") {
///                 session = SafariLikeFactory.makeSceneSession(
///                     sceneID: "swiftui",
///                     configuration: config
///                 )
///             }
///         }
///     }
/// }
/// ```
///
/// ## Internal Architecture (not for public use)
/// - Wires `BrowserSceneSession` to internal SwiftUI view
/// - Manages scene lifecycle (scenePhase, settings updates)
/// - Exposes only public initialization parameters; internal state is hidden
public struct SafariLikeBrowserView: View {
    private let session: BrowserSceneSession
    private let initialURL: String?
    @Binding private var configuration: SafariLikeConfiguration
    private let makeSettingsView: (() -> AnyView)?

    @State private var didOpenInitialURL: Bool = false

    /// Initialize SafariLikeBrowserView with session and optional parameters.
    ///
    /// - Parameters:
    ///   - session: A ``BrowserSceneSession`` instance created via ``SafariLikeFactory`` or ``SafariLikeUIKitHost``
    ///   - initialURL: Optional URL to load on first appearance (default: nil)
    ///   - configuration: Binding to ``SafariLikeConfiguration`` for reactive updates (required)
    ///   - makeSettingsView: Optional closure to provide custom settings UI (default: nil)
    public init(
        session: BrowserSceneSession,
        initialURL: String? = nil,
        configuration: Binding<SafariLikeConfiguration>,
        makeSettingsView: (() -> AnyView)? = nil
    ) {
        self.session = session
        self.initialURL = initialURL
        self._configuration = configuration
        self.makeSettingsView = makeSettingsView
    }

    public var body: some View {
        SplitBrowserRootView(
            viewModel: session.viewModel,
            chrome: session.chrome,
            configuration: configuration,
            makeSettingsView: makeSettingsView
        )
        .onAppear {
            AppBrowserSessionRegistry.shared.registerActiveSession(self.session)

            // Open initial URL once on first appearance if provided
            if !self.didOpenInitialURL,
               let urlString = self.initialURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !urlString.isEmpty,
               let url = URL(string: urlString) {
                self.didOpenInitialURL = true
                self.session.openExternalURL(url)
            }
        }
        .onDisappear {
            AppBrowserSessionRegistry.shared.unregisterSession(self.session)
            self.session.invalidateSession()
        }
    }
}
