import XCTest
import SwiftUI
@testable import SafariLikeKit

final class ResolvedInsetsProviderTests: XCTestCase {

    func testResolve_sceneInsetsNonZeroWinsOverGeometry() {
        let scene = EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0)
        let geo = EdgeInsets(top: 1, leading: 2, bottom: 3, trailing: 4)

        let resolved = ResolvedInsetsProvider.resolve(sceneInsets: scene, geometryInsets: geo)

        XCTAssertEqual(resolved.top, 10, accuracy: 0.001)
        XCTAssertEqual(resolved.leading, 0, accuracy: 0.001)
        XCTAssertEqual(resolved.bottom, 0, accuracy: 0.001)
        XCTAssertEqual(resolved.trailing, 0, accuracy: 0.001)
    }

    func testResolve_sceneInsetsAllZeroUsesGeometry() {
        let scene = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        let geo = EdgeInsets(top: 1, leading: 2, bottom: 3, trailing: 4)

        let resolved = ResolvedInsetsProvider.resolve(sceneInsets: scene, geometryInsets: geo)

        XCTAssertEqual(resolved.top, 1, accuracy: 0.001)
        XCTAssertEqual(resolved.leading, 2, accuracy: 0.001)
        XCTAssertEqual(resolved.bottom, 3, accuracy: 0.001)
        XCTAssertEqual(resolved.trailing, 4, accuracy: 0.001)
    }

    func testResolve_negativeComponentsAreClampedToZero() {
        let scene = EdgeInsets(top: -3, leading: -1, bottom: 2, trailing: -5)
        let geo = EdgeInsets(top: 9, leading: 9, bottom: 9, trailing: 9)

        let resolved = ResolvedInsetsProvider.resolve(sceneInsets: scene, geometryInsets: geo)

        // Scene wins because bottom is > 0 after sanitization; negatives must be clamped to 0.
        XCTAssertEqual(resolved.top, 0, accuracy: 0.001)
        XCTAssertEqual(resolved.leading, 0, accuracy: 0.001)
        XCTAssertEqual(resolved.bottom, 2, accuracy: 0.001)
        XCTAssertEqual(resolved.trailing, 0, accuracy: 0.001)
    }
}
