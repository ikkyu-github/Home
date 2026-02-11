# Dead Keys / Signals Report (STRICT literal-based)

Scope and limitations:
- UserDefaults/AppStorage/SceneStorage: only literal string keys are tracked. Constant-based keys are TOOLING-LIMITED.
- NotificationCenter: only literal Notification.Name("...") tracked. Static-let names and .foo are TOOLING-LIMITED here.
- Environment: EnvironmentValues var definitions + @Environment(\.key) / .environment(\.key, ...) usages are tracked via regex; complex patterns may be TOOLING-LIMITED.

## UserDefaults/AppStorage keys written but never read (0)


## UserDefaults/AppStorage keys read but never written (0)


## Notification.Name literals posted but never observed (0)


## Notification.Name literals observed but never posted (0)


## EnvironmentValues keys defined but never used (7)

- browserLayoutMode
  - def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift#L42): var browserLayoutMode: BrowserLayoutMode {
- browserRuntime
  - def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift#L16): var browserRuntime: (any BrowserRuntimeIntentDispatching)? {
- browserWindowID
  - def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Environment/BrowserEnvironmentKeys.swift#L11): var browserWindowID: BrowserWindowID? {
- isLayoutStabilizing
  - def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LayoutStability.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LayoutStability.swift#L10): var isLayoutStabilizing: Bool {
- keyboardHeight
  - def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Input/KeyboardHeightEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Platform/Input/KeyboardHeightEnvironment.swift#L11): var keyboardHeight: CGFloat {
- layoutEnvironment
  - def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/BrowserLayoutEnvironment.swift#L47): var layoutEnvironment: LayoutEnvironment {
- uxPolicy
  - def: [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/UXPolicyEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Policy/UXPolicyEnvironment.swift#L8): var uxPolicy: UXPolicy {

## EnvironmentValues keys used but no definition found (TOOLING-LIMITED) (0)

