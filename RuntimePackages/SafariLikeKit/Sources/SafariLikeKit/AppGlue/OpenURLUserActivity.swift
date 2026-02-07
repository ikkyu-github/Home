import Foundation
import SafariLikeCoreKit
/// UserActivity payload for routing URL opens into a specific newly-created scene.
///
/// Used by `AppWindowActions.openURL(_:inNewWindow:)` when requesting a new window via
/// `UIApplication.requestSceneSessionActivation`.
public enum OpenURLUserActivity {
    public static let activityType: String = "SafariLikeKit.openURL"
    public static let urlKey: String = "url"
    public static func make(url: URL) -> NSUserActivity {
        let activity = NSUserActivity(activityType: activityType)
        activity.userInfo = [urlKey: url.absoluteString]
        activity.webpageURL = url
        activity.title = url.absoluteString
        return activity
    }
    public static func extractURL(from activity: NSUserActivity) -> URL? {
        if let url = activity.webpageURL { return url }
        if let urlString = activity.userInfo?[urlKey] as? String {
            return URL(string: urlString)
        }
        return nil
    }
}
