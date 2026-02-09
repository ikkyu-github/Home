#if DEBUG
import SwiftUI

internal struct BrowserDebugVisualizer: View {
    let snapshot: BrowserLayoutSnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            FilledBand(rect: snapshot.chromeTopRect, color: .blue)
            FilledBand(rect: snapshot.chromeBottomRect, color: .orange)
            FilledBand(rect: snapshot.keyboardLiftRect, color: .purple)

            StrokedRect(rect: snapshot.contentViewportRect, color: .green)
            StrokedRect(rect: snapshot.chromeTopRect, color: .blue)
            StrokedRect(rect: snapshot.chromeBottomRect, color: .orange)
            StrokedRect(rect: snapshot.keyboardLiftRect, color: .purple)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct StrokedRect: View {
    let rect: CGRect
    let color: Color

    var body: some View {
        Path { path in
            path.addRect(rect.standardized)
        }
        .stroke(color, lineWidth: 1)
    }
}

private struct FilledBand: View {
    let rect: CGRect
    let color: Color

    var body: some View {
        Path { path in
            path.addRect(rect.standardized)
        }
        .fill(color.opacity(0.12))
    }
}
#endif
