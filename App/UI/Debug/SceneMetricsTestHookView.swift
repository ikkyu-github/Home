#if DEBUG
import SwiftUI

import SafariLikeKit
struct SceneMetricsTestHookView: View {

    @ObservedObject var sceneMetrics: SceneMetrics
    var body: some View {
        let s = sceneMetrics.stableInsets
        // Keep the label stable and parseable for UI tests.
        let payload = [
            "stableEpoch=\(sceneMetrics.stableEpoch)",
            "stableCommittedEpoch=\(sceneMetrics.stableCommittedEpoch)",
            "rotationInProgress=\(sceneMetrics.rotationInProgress ? 1 : 0)",
            "interfaceOrientationRaw=\(sceneMetrics.interfaceOrientation.rawValue)",
            "stableOrientationRaw=\(sceneMetrics.stableInterfaceOrientation.rawValue)",
            "containerSizeW=\(Int(sceneMetrics.containerSize.width.rounded()))",
            "containerSizeH=\(Int(sceneMetrics.containerSize.height.rounded()))",
            "stableInsetsTop=\(Int(s.top.rounded()))",
            "stableInsetsLeft=\(Int(s.left.rounded()))",
            "stableInsetsBottom=\(Int(s.bottom.rounded()))",
            "stableInsetsRight=\(Int(s.right.rounded()))",
            "stableSizeW=\(Int(sceneMetrics.stableSize.width.rounded()))",
            "stableSizeH=\(Int(sceneMetrics.stableSize.height.rounded()))"
        ].joined(separator: ";")

        Text(payload)
            .font(.system(size: 6, weight: .regular, design: .monospaced))
            .padding(2)
            .background(Color.black.opacity(0.001))
            .accessibilityIdentifier("SafariLike.SceneMetrics.Hook")
            .accessibilityLabel(payload)
            .opacity(0.01)
            .allowsHitTesting(false)
    }
}
#endif
