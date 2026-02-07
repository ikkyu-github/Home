import SwiftUI
import SafariLikeCoreKit
internal struct StartPageBackgroundView: View {
    var body: some View {
        ZStack {
            // Procedural "wallpaper" (non-flat) + blur + dim.
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.18),
                    Color(red: 0.18, green: 0.10, blue: 0.22),
                    Color(red: 0.10, green: 0.16, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.clear
                ],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            Canvas { context, size in
                // Subtle grain so it reads like a wallpaper/snapshot under blur.
                let count = 260
                for i in 0..<count {
                    let x = CGFloat((i * 37) % 997) / 997.0 * size.width
                    let y = CGFloat((i * 91) % 991) / 991.0 * size.height
                    let r = CGFloat((i % 7) + 1)
                    let alpha = Double(((i * 13) % 9) + 1) / 900.0
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
            .blendMode(.overlay)
            .opacity(0.8)
            Rectangle()
                .fill(.black.opacity(0.22))
        }
        .blur(radius: 18)
    }
}
