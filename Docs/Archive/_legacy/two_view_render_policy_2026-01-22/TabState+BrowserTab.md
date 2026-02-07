# Archived Swift Reference (Not Built)

This file is a legacy code reference only.
Canonical source lives under `RuntimePackages/**/Sources/**`.

```swift
import BrowserCore
import Foundation

extension TabState {
    /// Bridge persisted `BrowserTab` metadata into the Engine tab state model.
    init(browserTab: BrowserTab, isPrivate: Bool) {
        self.init(
            id: browserTab.id,
            url: URL(string: browserTab.urlString),
            title: browserTab.title,
            lastActiveAt: browserTab.lastVisitedAt,
            hasSnapshot: false,
            lastSnapshotAt: nil,
            snapshotData: nil,
            isPrivate: isPrivate,
            lifecycle: browserTab.lifecycleState,
            runtimeAttachment: .detached
        )
    }
}
```
