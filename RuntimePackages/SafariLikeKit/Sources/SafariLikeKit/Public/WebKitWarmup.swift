import SafariLikeCoreKit
/// SafariLikeKit facade for WebKit warmup hooks.
///
/// This avoids requiring app targets to import `SafariLikeCoreKit` directly.
public enum WebKitWarmupHooks {
	public static var onFirstWebViewCreated: (@MainActor () -> Void)? {
		get { SafariLikeCoreKit.WebKitWarmup.onFirstWebViewCreated }
		set { SafariLikeCoreKit.WebKitWarmup.onFirstWebViewCreated = newValue }
	}
}
