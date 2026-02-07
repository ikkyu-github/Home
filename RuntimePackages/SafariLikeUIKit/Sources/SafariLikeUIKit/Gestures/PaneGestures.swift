import SwiftUI

public struct PaneGestures: ViewModifier {
    @ObservedObject private var coordinator: SplitPaneCoordinator

    @State private var edgeDrag: CGFloat = 0

    public init(coordinator: SplitPaneCoordinator) {
        self.coordinator = coordinator
    }

    public func body(content: Content) -> some View {
        content
            // Edge drag from right → enter split mode
            .highPriorityGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .global)
                    .onChanged { value in
                        // Only treat as edge gesture when starting near right edge.
                        if value.startLocation.x > UIScreen.main.bounds.width - 24 {
                            edgeDrag = max(0, -value.translation.width)
                        }
                    }
                    .onEnded { value in
                        defer { edgeDrag = 0 }
                        if value.startLocation.x > UIScreen.main.bounds.width - 24 {
                            if (-value.translation.width) > 80 {
                                coordinator.enterSplitMode()
                            }
                        }
                    }
            )
    }
}

public extension View {
    func paneGestures(coordinator: SplitPaneCoordinator) -> some View {
        modifier(PaneGestures(coordinator: coordinator))
    }
}

