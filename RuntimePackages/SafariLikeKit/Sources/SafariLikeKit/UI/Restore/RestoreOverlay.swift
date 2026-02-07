import SwiftUI
import SafariLikeCoreKit
struct RestoreOverlay: View {
    let snapshotData: Data?
    init(snapshotData: Data?) {
        self.snapshotData = snapshotData
    }
    var body: some View {
        RestoreSnapshotLoadingView(snapshotData: snapshotData)
    }
}
