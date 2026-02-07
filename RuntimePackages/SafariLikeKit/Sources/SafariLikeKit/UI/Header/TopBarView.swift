import SwiftUI
import SafariLikeUXKit
import SafariLikeContracts
struct TopBarView: View {
    enum InteractionMode: Equatable {
        /// Full editable address field (TextField participates in FocusState).
        case interactive
        /// Non-editable field that only requests focus when tapped.
        case passive
    }
    @ObservedObject var vm: SplitBrowserViewModel
    let mode: InteractionMode
    private let showsCancelButton: Bool
    @ObservedObject private var bar: SplitBrowserAddressBarDomain
    @EnvironmentObject private var chrome: BrowserChromeState
    @Environment(\.uxPolicy) private var uxPolicy
    /// Local mirrors for UIKit bridge bindings.
    /// Source of truth remains `bar.addressBarViewState`.
    @State private var textMirror: String = ""
    @State private var isTextFieldFocused: Bool = false
    @State private var focusPresentationProgress: CGFloat = 0
    @Environment(\.browserLayoutMode) private var layoutMode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    init(
        vm: SplitBrowserViewModel,
        mode: InteractionMode = .interactive,
        showsCancelButton: Bool = true
    ) {
        self.vm = vm
        self.mode = mode
        self.showsCancelButton = showsCancelButton
        self._bar = ObservedObject(wrappedValue: vm.bar)
    }
    var body: some View {
        addressField
            .onAppear { syncFromState(animated: false) }
            .onChange(of: mode) { newMode in
                if newMode == .passive {
                    isTextFieldFocused = false
                }
                syncFromState(animated: true)
            }
            .onChange(of: bar.addressBarViewState) { _ in syncFromState(animated: true) }
    }
    private func syncFromState(animated: Bool) {
        let state = bar.addressBarViewState
        if textMirror != state.textFieldText {
            textMirror = state.textFieldText
        }
        let shouldFocus = (mode == .interactive) && state.isTextInputFocused
        if isTextFieldFocused != shouldFocus {
            isTextFieldFocused = shouldFocus
        }
        // Focus must be purely visual and must not animate layout.
        // We still allow visual styling changes (stroke/shadow/selection) via state, but do not animate them here.
        focusPresentationProgress = shouldFocus ? 1 : 0
    }
    // MARK: - Address Field
    private var addressField: some View {
        let metrics = AddressBarLayoutMetrics.current(
            layoutMode: layoutMode,
            dynamicTypeSize: dynamicTypeSize
        )
        let state = bar.addressBarViewState
        let collapseT: CGFloat = chrome.interaction.scrollProgress
        let coupling = uxPolicy.addressBar.microInteractions.scrollCollapseCouplingStrength
        let coupledT = max(0, min(1, collapseT * coupling))
        let targetHeight: CGFloat = metrics.expandedHeight - (metrics.expandedHeight - metrics.collapsedHeight) * coupledT
        let verticalPadding: CGFloat = metrics.expandedVerticalPadding - (metrics.expandedVerticalPadding - metrics.collapsedVerticalPadding) * coupledT
        let shouldShowCancel = showsCancelButton
            && mode == .interactive
            && focusPresentationProgress > uxPolicy.addressBar.microInteractions.cancelButtonRevealThreshold
        return HStack(spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                HStack(spacing: 8) {
                    Button {
                        bar.send(SafariLikeContracts.AddressBarEvent.tapLockIcon)
                    } label: {
                        Image(systemName: state.securityIconSystemName)
                            .font(.caption)
                            .opacity(0.7)
                            .frame(width: metrics.iconWidth)
                            .accessibilityHidden(true)
                    }
                    .buttonStyle(.plain)
                    .popover(
                        isPresented: Binding(
                            get: { bar.addressBarViewState.isSecurityInfoPresented },
                            set: { isPresented in
                                if isPresented == false {
                                    bar.send(SafariLikeContracts.AddressBarEvent.dismissSecurityInfo)
                                }
                            }
                        ),
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .top
                    ) {
                        WebsiteSettingsView(vm: vm)
                    }
                    if mode == .interactive {
                        interactiveTextField
                    } else {
                        passiveField
                    }
                    if mode == .interactive, state.shouldShowClearButton {
                        Button {
                            bar.send(SafariLikeContracts.AddressBarEvent.clearText)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear text")
                    }
                }
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(height: targetHeight)
                .background(
                    RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                                .strokeBorder(
                                    SwiftUI.Color(white: 1.0, opacity: Double(isTextFieldFocused ? 0.22 : 0.10)),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(
                    color: SwiftUI.Color(white: 0.0, opacity: Double(isTextFieldFocused ? 0.28 : 0.12)),
                    radius: isTextFieldFocused ? 12 : 6,
                    y: 4
                )
                .scaleEffect(1.0 + 0.02 * focusPresentationProgress)
                .clipped()
                if let p = state.loadingProgress, p > 0 {
                    AddressLoadingProgressBar(progress: p)
                        .allowsHitTesting(false)
                }
            }
            if shouldShowCancel {
                Button("Cancel") {
                    bar.send(SafariLikeContracts.AddressBarEvent.cancelEditing)
                }
                .foregroundStyle(.blue)
                .transition(SwiftUI.AnyTransition.opacity)
                .accessibilitySortPriority(1)
            }
        }
        .accessibilityElement(children: .contain)
    }
    private var interactiveTextField: some View {
        return SelectableTextField(
            placeholder: uxPolicy.strings.addressPlaceholder,
            text: $textMirror,
            isFocused: $isTextFieldFocused,
            caretBlinkPolicy: uxPolicy.addressBar.microInteractions.caretBlinkPolicy,
            focusBehavior: .selectAll,
            selectionAnimationDuration: uxPolicy.addressBar.microInteractions.selectionAnimationDuration,
            keyboardType: .URL,
            submitLabel: .go,
            onSubmit: {
                bar.send(SafariLikeContracts.AddressBarEvent.submitAndDismissEditing)
            },
            onFocusChanged: { focused in
                // UI event -> VM state machine.
                bar.send(SafariLikeContracts.AddressBarEvent.focusChanged(isFocused: focused))
                if focused {
                    maybeHapticOnFocus()
                }
            },
            onTextChanged: { newValue in
                bar.send(SafariLikeContracts.AddressBarEvent.textChanged(newValue))
            }
        )
        .accessibilityLabel(uxPolicy.strings.addressPlaceholder)
        .accessibilityHint("Search or enter a website")
        .accessibilityIdentifier("SafariLike.AddressBar.TextField")
        .accessibilitySortPriority(2)
    }
    private var passiveField: some View {
        let text = bar.addressBarViewState.textFieldText.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = text.isEmpty ? uxPolicy.strings.addressPlaceholder : text
        return Text(display)
            .font(SwiftUI.Font.body)
            .foregroundStyle(text.isEmpty ? .secondary : .primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                bar.send(SafariLikeContracts.AddressBarEvent.tapAddressBar)
            }
            .accessibilityLabel(uxPolicy.strings.addressPlaceholder)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("SafariLike.AddressBar.Passive")
    }
    private func maybeHapticOnFocus() {
        #if os(iOS)
        // Optional: only when it won't interfere with accessibility.
        guard UIAccessibility.isVoiceOverRunning == false else { return }
        guard UIAccessibility.isReduceMotionEnabled == false else { return }
        #if !targetEnvironment(simulator)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred(intensity: 0.6)
        #endif
        #endif
    }
}
private struct AddressLoadingProgressBar: View, Equatable {
    let progress: Double
    var body: some View {
        GeometryReader { geo in
            let w = max(8, geo.size.width * min(1, progress))
            Capsule()
                .fill(SwiftUI.Color(white: 1.0, opacity: 0.55))
                .frame(width: w, height: 2)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .animation(.linear(duration: 0.08), value: w)
        }
    }
}
