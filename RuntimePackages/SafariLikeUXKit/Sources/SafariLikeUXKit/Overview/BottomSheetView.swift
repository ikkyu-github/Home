import SwiftUI

/// A reusable, Safari-like bottom sheet that overlays content without pushing layout.
/// - Supports drag-to-resize with snapping to min/mid/max anchors.
/// - Respects safe-area and animates smoothly.
public struct BottomSheetView<Content: View>: View {

    public typealias AnchorProvider = (CGSize) -> CGFloat

    private let isPresented: Bool
    private let heightFraction: Binding<CGFloat>?
    private let minHeightProvider: AnchorProvider
    private let midHeightProvider: AnchorProvider
    private let maxHeightProvider: AnchorProvider
    private let bottomSafeInset: CGFloat
    private let dimmingOpacity: Double
    private let dimmingAllowsHitTesting: Bool
    private let onDimmingTap: (() -> Void)?
    private let animation: Animation?
    private let content: () -> Content
    private let onClose: (() -> Void)?

    @State private var currentHeight: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0

    public init(
        isPresented: Bool,
        heightFraction: Binding<CGFloat>? = nil,
        minHeight: @escaping AnchorProvider,
        midHeight: @escaping AnchorProvider,
        maxHeight: @escaping AnchorProvider,
        bottomSafeInset: CGFloat = 0,
        dimmingOpacity: Double = 0,
        dimmingAllowsHitTesting: Bool = false,
        onDimmingTap: (() -> Void)? = nil,
        animation: Animation? = .spring(response: 0.32, dampingFraction: 0.88),
        onClose: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isPresented = isPresented
        self.heightFraction = heightFraction
        self.minHeightProvider = minHeight
        self.midHeightProvider = midHeight
        self.maxHeightProvider = maxHeight
        self.bottomSafeInset = bottomSafeInset
        self.dimmingOpacity = dimmingOpacity
        self.dimmingAllowsHitTesting = dimmingAllowsHitTesting
        self.onDimmingTap = onDimmingTap
        self.animation = animation
        self.onClose = onClose
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let minH = clamp(minHeightProvider(size), to: 0...size.height)
            let midH = clamp(midHeightProvider(size), to: 0...size.height)
            let maxH = clamp(maxHeightProvider(size), to: 0...size.height)

            let preferredHeight: CGFloat = {
                guard let heightFraction else { return midH }
                let fraction = clamp(heightFraction.wrappedValue, to: 0...1)
                return clamp(size.height * fraction, to: minH...maxH)
            }()

            // Initialize height when presented (idempotent across updates)
            let initialH = clamp(currentHeight == 0 ? preferredHeight : currentHeight, to: minH...maxH)

            ZStack(alignment: .bottom) {
                if isPresented {
                    dimmingLayer

                    sheet(size: size, minH: minH, midH: midH, maxH: maxH)
                        .frame(height: initialH + dragTranslation)
                        .padding(.bottom, bottomSafeInset)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(animation, value: initialH + dragTranslation)
                        .onAppear {
                            self.currentHeight = initialH
                            if let heightFraction {
                                heightFraction.wrappedValue = clamp(initialH / max(1, size.height), to: 0...1)
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var dimmingLayer: some View {
        Color.black
            .opacity(dimmingOpacity)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .allowsHitTesting(dimmingAllowsHitTesting)
            .onTapGesture {
                onDimmingTap?()
            }
    }

    // MARK: - Sheet content and interaction
    @ViewBuilder
    private func sheet(size: CGSize, minH: CGFloat, midH: CGFloat, maxH: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Handle area (drag only here; do NOT block taps inside content)
            HStack {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 42, height: 5)
                    .padding(.vertical, 8)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .gesture(sheetDragGesture(sizeHeight: size.height, minH: minH, midH: midH, maxH: maxH))

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(sheetBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .zIndex(999)
    }

    @ViewBuilder
    private var sheetBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if #available(iOS 15.0, macOS 12.0, *) {
            shape.fill(.ultraThinMaterial)
        } else {
            shape.fill(Color.secondary.opacity(0.12))
        }
    }

    private func sheetDragGesture(sizeHeight: CGFloat, minH: CGFloat, midH: CGFloat, maxH: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let proposed = currentHeight - value.translation.height
                dragTranslation = clamp(proposed, to: minH...maxH) - currentHeight
            }
            .onEnded { value in
                let predicted = currentHeight - value.predictedEndTranslation.height
                let snapped = snap(predicted, anchors: [minH, midH, maxH])
                withAnimation(animation) {
                    currentHeight = snapped
                    dragTranslation = 0
                }
                if let heightFraction {
                    heightFraction.wrappedValue = clamp(snapped / max(1, sizeHeight), to: 0...1)
                }
                if currentHeight <= minH * 0.9 { onClose?() }
            }
    }

    // MARK: - Helpers
    private func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func snap(_ value: CGFloat, anchors: [CGFloat]) -> CGFloat {
        anchors.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
    }
}
