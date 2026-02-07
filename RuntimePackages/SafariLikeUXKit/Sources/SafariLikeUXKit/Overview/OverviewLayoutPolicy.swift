import CoreGraphics

/// Single source of truth for Tab Overview layout/spacing/scale.
///
/// Design goals:
/// - Drive layout primarily from container width (not orientation heuristics)
/// - Keep thresholds and metrics centralized (no scattered magic numbers)
/// - Provide stable recomputation via hysteresis bands
public struct OverviewLayoutPolicy: Sendable, Equatable {

    public struct Insets: Sendable, Equatable {
        public var top: CGFloat
        public var leading: CGFloat
        public var bottom: CGFloat
        public var trailing: CGFloat

        public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
            self.top = top
            self.leading = leading
            self.bottom = bottom
            self.trailing = trailing
        }

        public var horizontal: CGFloat { leading + trailing }
        public var vertical: CGFloat { top + bottom }
    }

    public struct WidthBand: Sendable, Equatable {
        public var minWidth: CGFloat
        public var columns: Int

        public init(minWidth: CGFloat, columns: Int) {
            self.minWidth = minWidth
            self.columns = columns
        }
    }

    public struct CardSizing: Sendable, Equatable {
        /// width/height ratio
        public var aspectRatio: CGFloat
        public var minWidth: CGFloat
        public var maxWidth: CGFloat

        public init(aspectRatio: CGFloat, minWidth: CGFloat, maxWidth: CGFloat) {
            self.aspectRatio = aspectRatio
            self.minWidth = minWidth
            self.maxWidth = maxWidth
        }
    }

    public struct ScaleCurve: Sendable, Equatable {
        public var minScale: CGFloat
        public var exponent: CGFloat

        public init(minScale: CGFloat, exponent: CGFloat) {
            self.minScale = minScale
            self.exponent = exponent
        }

        public func scale(progress: CGFloat) -> CGFloat {
            let p = max(0, min(1, progress))
            // Ease-out curve; p=0 => minScale, p=1 => 1
            let eased = 1 - pow(1 - p, exponent)
            return minScale + (1 - minScale) * eased
        }
    }

    public var bands: [WidthBand]
    public var hysteresis: CGFloat

    public var card: CardSizing
    public var interCardSpacing: CGFloat
    public var sectionInsets: Insets
    public var scaleCurve: ScaleCurve

    public init(
        bands: [WidthBand],
        hysteresis: CGFloat,
        card: CardSizing,
        interCardSpacing: CGFloat,
        sectionInsets: Insets,
        scaleCurve: ScaleCurve
    ) {
        self.bands = bands.sorted(by: { $0.minWidth < $1.minWidth })
        self.hysteresis = hysteresis
        self.card = card
        self.interCardSpacing = interCardSpacing
        self.sectionInsets = sectionInsets
        self.scaleCurve = scaleCurve
    }

    public static let `default` = OverviewLayoutPolicy(
        bands: [
            .init(minWidth: 0, columns: 1),
            .init(minWidth: 390, columns: 2),
            .init(minWidth: 740, columns: 3),
            .init(minWidth: 1024, columns: 4)
        ],
        hysteresis: 28,
        card: .init(aspectRatio: 0.72, minWidth: 220, maxWidth: 360),
        interCardSpacing: 16,
        sectionInsets: .init(top: 12, leading: 18, bottom: 110, trailing: 18),
        scaleCurve: .init(minScale: 0.94, exponent: 2.4)
    )

    /// Safari-like spacing that grows slightly with width.
    /// Keeps layout feeling less "third-party" by avoiding a constant grid gap across devices.
    public func resolvedInterCardSpacing(containerWidth: CGFloat) -> CGFloat {
        let width = max(0, containerWidth)
        let proposed = width * 0.018
        return min(22, max(12, proposed))
    }

    /// Compute columns from width with hysteresis for stability.
    public func columns(containerWidth: CGFloat, previous: Int?) -> Int {
        let width = max(0, containerWidth)

        // Base decision.
        var desired = bands.first?.columns ?? 1
        for band in bands where width >= band.minWidth {
            desired = band.columns
        }

        guard let previous else { return max(1, desired) }
        if previous == desired { return max(1, desired) }

        // Apply hysteresis around the decision boundary between previous and desired.
        // Find the boundary minWidth for the desired band.
        let desiredMin = bands.first(where: { $0.columns == desired })?.minWidth
        let prevMin = bands.first(where: { $0.columns == previous })?.minWidth

        // If moving to more columns, require width to exceed the threshold + hysteresis.
        if desired > previous, let desiredMin {
            return (width >= desiredMin + hysteresis) ? desired : previous
        }

        // If moving to fewer columns, require width to fall below the previous threshold - hysteresis.
        if desired < previous, let prevMin {
            return (width < prevMin - hysteresis) ? desired : previous
        }

        return max(1, desired)
    }

    public func cardSize(containerWidth: CGFloat, columns: Int) -> CGSize {
        cardSize(containerWidth: containerWidth, columns: columns, interCardSpacing: interCardSpacing)
    }

    public func cardSize(containerWidth: CGFloat, columns: Int, interCardSpacing: CGFloat) -> CGSize {
        let cols = max(1, columns)
        let spacing = max(0, interCardSpacing)
        let available = max(0, containerWidth - sectionInsets.horizontal - spacing * CGFloat(cols - 1))
        let rawW = available / CGFloat(cols)
        let w: CGFloat = {
            // Never exceed available slot width; minWidth is a preference, not a hard constraint.
            if rawW < card.minWidth {
                return max(0, rawW)
            }
            return min(card.maxWidth, rawW)
        }()
        let h = w / max(0.001, card.aspectRatio)
        return CGSize(width: w, height: h)
    }
}
