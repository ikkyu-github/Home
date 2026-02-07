import SwiftUI
import Combine
import Foundation
import SafariLikeUXKit
import SafariLikeCoreKit
// BUILD-PERF-AUDIT(2026-01-21): Compile hotspot (SwiftUI animation/physics state machine used widely).
// Keep dependencies minimal; prefer pure-Foundation helpers for debug labels/telemetry.
@MainActor
final class TabOverviewTransitionController: ObservableObject {
    enum Source {
        case chrome(isTopChrome: Bool)
        case overlay
    }
    @Published private(set) var presentationProgress: CGFloat = 0
    /// The value SwiftUI animates towards; presentationProgress tracks the in-flight value.
    @Published var targetProgress: CGFloat = 0
    @Published private(set) var isDragging: Bool = false
    @Published private(set) var debugStateLabel: String = ""
    private var machine: OverviewPhysicsEngine.TransitionMachine
    private var physics: SafariPhysicsConfig
    private var isVisibleBinding: Binding<Bool>?
    private var lastKnownContainerWidth: CGFloat = 0
    init(physics: SafariPhysicsConfig = .default) {
        self.physics = physics
        self.machine = OverviewPhysicsEngine.TransitionMachine(
            initial: .closed,
            config: .init(
                settleThreshold: physics.overview.settleThreshold,
                projectedSettleThreshold: physics.overview.projectedSettleThreshold
            )
        )
        updateDebugLabel(reason: "init")
    }
    func applyPolicy(_ policy: UXPolicy, containerWidth: CGFloat) {
        // Preserve current machine state but swap config + physics.
        let currentState = machine.state
        let nextPhysics = policy.tabOverview.physics
        self.physics = nextPhysics
        self.machine = OverviewPhysicsEngine.TransitionMachine(
            initial: currentState,
            config: .init(
                settleThreshold: nextPhysics.overview.settleThreshold,
                projectedSettleThreshold: nextPhysics.overview.projectedSettleThreshold
            )
        )
        updateContainerWidth(containerWidth)
        updateDebugLabel(reason: "applyPolicy")
    }
    func updateContainerWidth(_ containerWidth: CGFloat) {
        let w = max(0, containerWidth)
        guard abs(w - lastKnownContainerWidth) > 0.5 else { return }
        lastKnownContainerWidth = w
        physics.overview.openDistance = SafariPhysicsConfig.resolvedOverviewOpenDistance(containerWidth: w)
        updateDebugLabel(reason: "containerWidth")
    }
    func connect(isVisible: Binding<Bool>) {
        self.isVisibleBinding = isVisible
        machine.setVisible(isVisible.wrappedValue)
        targetProgress = isVisible.wrappedValue ? 1 : 0
        presentationProgress = targetProgress
        updateDebugLabel(reason: "connect")
    }
    func updatePresentationProgress(_ value: CGFloat) {
        let clamped = min(1, max(0, value))
        if abs(clamped - presentationProgress) < 0.0005 { return }
        presentationProgress = clamped
        // Keep state labels honest.
        if !isDragging {
            if clamped <= 0.0001 {
                machine.setVisible(false)
            } else if clamped >= 0.9999 {
                machine.setVisible(true)
            }
        }
        updateDebugLabel(reason: "presentation")
    }
    func syncVisibilityFromExternalChange(_ isVisible: Bool) {
        guard isDragging == false else { return }
        machine.setVisible(isVisible)
        settle(to: isVisible ? .open : .closed, updateVisible: false)
        updateDebugLabel(reason: "externalVisibility")
    }
    func beginDrag(source: Source) {
        isDragging = true
        // Cancel any in-flight animation by pinning the target to the current presentation.
        withAnimation(.none) {
            targetProgress = presentationProgress
        }
        updateDebugLabel(reason: "beginDrag")
        // Ensure overlay is present as soon as we start tracking an opening gesture.
        if presentationProgress <= 0.0001 {
            isVisibleBinding?.wrappedValue = true
        }
        machine.beginTracking(currentProgress: presentationProgress)
        updateDebugLabel(reason: "beginTracking")
    }
    func updateDrag(source: Source, translation: CGFloat, predictedEndTranslation: CGFloat) {
        let engineSource: OverviewPhysicsEngine.TransitionSource = {
            switch source {
            case .overlay:
                return .overlay
            case .chrome(let isTopChrome):
                return .chrome(isTopChrome: isTopChrome)
            }
        }()
        guard let out = OverviewPhysicsEngine.updateDrag(
            .init(
                source: engineSource,
                translation: translation,
                predictedEndTranslation: predictedEndTranslation,
                openDistance: physics.overview.openDistance,
                deadZone: physics.overview.deadZone,
                currentProgress: presentationProgress
            )
        ) else {
            return
        }
        let next = out.nextProgress
        withAnimation(.none) {
            targetProgress = next
        }
        updateDebugLabel(reason: "updateDrag")
        // Keep the VM-visible flag conservative: only keep it false when truly closed.
        if out.shouldForceVisible {
            isVisibleBinding?.wrappedValue = true
        }
        // State is still tracking.
        _ = predictedEndTranslation // reserved for future per-frame projection
    }
    func endDrag(source: Source, translation: CGFloat, predictedEndTranslation: CGFloat) {
        isDragging = false
        let engineSource: OverviewPhysicsEngine.TransitionSource = {
            switch source {
            case .overlay:
                return .overlay
            case .chrome(let isTopChrome):
                return .chrome(isTopChrome: isTopChrome)
            }
        }()
        let projectedProgress = OverviewPhysicsEngine.endDrag(
            .init(
                source: engineSource,
                translation: translation,
                predictedEndTranslation: predictedEndTranslation,
                openDistance: physics.overview.openDistance,
                deadZone: physics.overview.deadZone,
                currentProgress: presentationProgress
            )
        ).projectedProgress
        let target = machine.decideTarget(currentProgress: presentationProgress, projectedProgress: projectedProgress)
        settle(to: target, updateVisible: true)
        updateDebugLabel(reason: "endDrag->settle")
        // If we decided to close, update the VM immediately; overlay stays present
        // via presentationProgress > 0 until animation completes.
        if target == .closed {
            isVisibleBinding?.wrappedValue = false
        }
        _ = translation
    }
    func requestDismiss() {
        guard presentationProgress > 0.001 else {
            isVisibleBinding?.wrappedValue = false
            return
        }
        isVisibleBinding?.wrappedValue = false
        settle(to: .closed, updateVisible: false)
        updateDebugLabel(reason: "requestDismiss")
    }
    func forceClosed(reason: String = "forceClosed") {
        isDragging = false
        isVisibleBinding?.wrappedValue = false
        machine.setVisible(false)
        machine.settle(to: .closed)
        withAnimation(.none) {
            targetProgress = 0
        }
        presentationProgress = 0
        updateDebugLabel(reason: reason)
    }
    private func settle(to target: OverviewPhysicsEngine.TransitionMachine.Target, updateVisible: Bool) {
        machine.settle(to: target)
        let spring = Animation.interactiveSpring(
            response: physics.overviewSpring.response,
            dampingFraction: physics.overviewSpring.dampingFraction,
            blendDuration: 0
        )
        withAnimation(spring) {
            targetProgress = target.progress
        }
        updateDebugLabel(reason: "settle")
        if updateVisible, target == .open {
            isVisibleBinding?.wrappedValue = true
        }
    }
    private func updateDebugLabel(reason: String) {
        debugStateLabel = "overview \(reason) state=\(String(describing: machine.state)) target=\(String(format: "%.3f", Double(targetProgress))) present=\(String(format: "%.3f", Double(presentationProgress))) drag=\(isDragging ? 1 : 0) openDist=\(Int(physics.overview.openDistance))"
    }
}
