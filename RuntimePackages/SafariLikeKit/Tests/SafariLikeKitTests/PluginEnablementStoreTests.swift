import XCTest
@testable import SafariLikeKit

final class PluginEnablementStoreTests: XCTestCase {
    func testEnableDisablePersistsPerWindowID() async {
        let windowID = "test-" + UUID().uuidString
        let store = PluginEnablementStore(windowID: windowID)

        await store.reset()
        await store.loadEnablementState()

        let initiallyEnabled = await store.isEnabled(pluginID: "com.example.plugin")
        XCTAssertFalse(initiallyEnabled)

        await store.setEnabled(true, for: "com.example.plugin")
        let enabledAfterSet = await store.isEnabled(pluginID: "com.example.plugin")
        XCTAssertTrue(enabledAfterSet)

        await store.setEnabled(false, for: "com.example.plugin")
        let enabledAfterClear = await store.isEnabled(pluginID: "com.example.plugin")
        XCTAssertFalse(enabledAfterClear)

        await store.reset()
    }

    func testGrantedPermissionsRoundTrip() async {
        let windowID = "test-" + UUID().uuidString
        let store = PluginEnablementStore(windowID: windowID)

        await store.reset()

        let pluginID = "com.example.perms"
        await store.setPermission(.navigationRead, granted: true, for: pluginID)

        let granted = await store.grantedPermissions(pluginID: pluginID)
        XCTAssertTrue(granted.contains(.navigationRead))

        await store.setPermission(.navigationRead, granted: false, for: pluginID)
        let granted2 = await store.grantedPermissions(pluginID: pluginID)
        XCTAssertFalse(granted2.contains(.navigationRead))

        await store.reset()
    }
}
