import SwiftUI

#if DEBUG && os(iOS)
import UIKit

private struct _GlobalFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct _ReportGlobalFrameModifier: ViewModifier {
    let onChange: (CGRect) -> Void

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: _GlobalFramePreferenceKey.self, value: proxy.frame(in: .global))
                }
            )
            .onPreferenceChange(_GlobalFramePreferenceKey.self, perform: onChange)
    }
}

private struct _TouchInspectorWindowInstaller: UIViewRepresentable {
    let isEnabled: Bool
    let activeFrameInScreen: CGRect

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.activeFrameInScreen = activeFrameInScreen

        guard let window = uiView.window else { return }
        context.coordinator.updateInstallation(on: window)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        fileprivate var isEnabled: Bool = false
        fileprivate var activeFrameInScreen: CGRect = .zero

        private weak var installedWindow: UIWindow?
        private weak var tapRecognizer: UITapGestureRecognizer?

        fileprivate func updateInstallation(on window: UIWindow) {
            if isEnabled == false {
                uninstallIfNeeded()
                return
            }

            if installedWindow !== window {
                uninstallIfNeeded()
                installedWindow = window
            }

            if tapRecognizer == nil {
                let r = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                r.cancelsTouchesInView = false
                r.delaysTouchesBegan = false
                r.delaysTouchesEnded = false
                r.delegate = self
                window.addGestureRecognizer(r)
                tapRecognizer = r
            }
        }

        private func uninstallIfNeeded() {
            if let window = installedWindow, let r = tapRecognizer {
                window.removeGestureRecognizer(r)
            }
            tapRecognizer = nil
            installedWindow = nil
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard isEnabled else { return }
            guard let window = recognizer.view as? UIWindow else { return }

            let point = recognizer.location(in: window)
            guard activeFrameInScreen.contains(point) else { return }

            let hitView = window.hitTest(point, with: nil)

            var chain: [UIView] = []
            var cursor = hitView
            while let v = cursor {
                chain.append(v)
                cursor = v.superview
            }

            let chainSummary = chain
                .map { v in
                    let cls = String(describing: type(of: v))
                    let hidden = v.isHidden ? "hidden" : "visible"
                    let ui = v.isUserInteractionEnabled ? "interactive" : "noUI"
                    let a = String(format: "%.2f", v.alpha)
                    let frame = NSCoder.string(for: v.frame)
                    return "\(cls) [\(hidden), \(ui), a=\(a)] frame=\(frame)"
                }
                .joined(separator: " -> ")

            print("[TouchInspector] tap@\(Int(point.x)),\(Int(point.y)) hit=\(String(describing: hitView))")
            print("[TouchInspector] chain: \(chainSummary)")
        }

        // MARK: UIGestureRecognizerDelegate

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

private struct _TouchInspectorModifier: ViewModifier {
    @State private var globalFrame: CGRect = .zero

    func body(content: Content) -> some View {
        let isEnabled = UserDefaults.standard.bool(forKey: "debug.touchInspector")

        return content
            .modifier(_ReportGlobalFrameModifier { globalFrame = $0 })
            .overlay(
                _TouchInspectorWindowInstaller(isEnabled: isEnabled, activeFrameInScreen: globalFrame)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            )
    }
}

internal extension View {
    /// DEBUG-only: installs a passive tap observer on the window that logs hit-test chain for taps inside this view's frame.
    /// Toggle with `UserDefaults.standard.set(true, forKey: "debug.touchInspector")`.
    func debugTouchInspector() -> some View {
        self.modifier(_TouchInspectorModifier())
    }
}

#else

internal extension View {
    func debugTouchInspector() -> some View { self }
}

#endif
