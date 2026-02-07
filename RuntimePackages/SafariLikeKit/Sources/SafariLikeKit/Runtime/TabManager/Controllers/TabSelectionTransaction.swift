import Foundation

/// A lightweight monotonic token representing a single logical tab selection/binding transaction.
///
/// Used to gate async work (binding, activation, restores) to the latest user intent.
struct TabSelectionTransaction: Hashable, Sendable {
    let id: UInt64

    init(_ id: UInt64) {
        self.id = id
    }
}
