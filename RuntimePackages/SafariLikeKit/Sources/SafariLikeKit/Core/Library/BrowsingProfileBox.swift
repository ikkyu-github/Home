import Foundation
import Combine
import SafariLikeCoreKit
@MainActor
final class BrowsingProfileBox: ObservableObject {
    @Published var profile: BrowsingProfile
    init(profile: BrowsingProfile) {
        self.profile = profile
    }
}
