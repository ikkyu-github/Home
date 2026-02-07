# webOS

Safari-like browser prototype with explicit anti-bloat guardrails.

## Quick start

- Open Xcode project: `open webOS.xcodeproj`

## Dependency boundaries (must stay one-way)

`App → SafariLikeKit → (SafariLikeCoreKit / SafariLikeUXKit / BrowserCore / SafariLikeContracts)`

See:
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [CONVENTIONS.md](CONVENTIONS.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)

## Anti-bloat rules (reviewable + enforceable)

- SwiftUI Views must not contain policy/decision logic.
- No `.shared` for scene/tab/window-bound state.
- `BrowserCore` / `SafariLikeContracts` / `SafariLikeUXKit` must not import `WebKit`.
- Keep debug overlays under `App/UI/Debug/` and wrap in `#if DEBUG`.

## Before merging a PR (checklist)

Run from repo root:

```bash
bash Scripts/repo_guard.sh
bash Dev/Tools/Scripts/architecture_guard.sh
bash Scripts/run_swiftlint.sh
Dev/Tools/Scripts/xcodebuild.sh --fail-on-warnings clean build
Dev/Tools/Scripts/spm.sh RuntimePackages/BrowserCore test
```

Notes:
- SwiftLint is expected via Homebrew: `brew install swiftlint`.
- Xcode build logs are written under `~/Library/Logs/webOS/` by the wrapper script.
