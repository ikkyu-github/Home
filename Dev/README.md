# webOS / SafariLike* Browser

A modern iOS browser with Safari-like features and split-view support.

## Quick Start

```bash
# Open the Xcode project
open webOS.xcodeproj

# Build & run (Xcode 15+, iOS 15+)
⌘B to build
⌘R to run
```

## Architecture

See [`Docs/ARCHITECTURE.md`](Docs/ARCHITECTURE.md) for detailed architecture analysis.

## Active Code Structure

```
webOS/
├── App/                    # SwiftUI app entry point
├── Assets.xcassets/        # App assets (icons, colors)
├── BrowserCore/            # Core data models & persistence
├── SafariLikeCoreKit/      # WebKit adapter & tab management
├── SafariLikeUIKit/        # UIKit custom components
├── SafariLikeKit/          # Composite framework (main logic)
├── Features/               # Modular features
├── Docs/                   # Documentation
├── Tools/                  # Build tools & utilities
└── webOS.xcodeproj         # Xcode project
```

## Key Features

- Multi-window support (iPadOS)
- Plugin system with hooks
- Tab groups & management
- Website preferences
- Content blocking
- Live Activities integration

## Documentation

- **[Architecture Overview](Docs/ARCHITECTURE.md)** - Framework design, dependencies, patterns
- **[Plugin System](Docs/PluginSystem.md)** - Plugin development guide
- **[Project README](Docs/README_PROJECT.md)** - Original project notes

## 🚫 Archive & Legacy Code

**Do NOT use archived code.** Legacy files are in `Docs/Archive/_DO_NOT_USE/`:

```
Docs/Archive/_DO_NOT_USE/
├── Process/              # Repository cleanup process docs
└── Framework-Reports/    # Archived framework documentation
```

**Key Rule:** Archive is read-only reference. To reuse an idea:
1. Read the design notes in `Docs/Archive/_DO_NOT_USE/Framework-Reports/`
2. Reimplement in the active codebase

**Protection:** Run `./Dev/Tools/check-archive-leaks.sh` to verify no archived code is being compiled.

See [`Docs/Archive/README.md`](Docs/Archive/README.md) for details.

## Framework Dependencies

```
App ↓
SafariLikeKit ↓ (domain + runtime + UI)
├─ SafariLikeCoreKit ↓ (WebKit adapter)
│  └─ BrowserCore ↓ (models + persistence)
└─ SafariLikeUIKit (UIKit components)
```

## Build Status

✅ Builds successfully - 0 errors, 0 warnings

This repo enforces a strict **0 warnings** policy. See [CONTRIBUTING.md](../CONTRIBUTING.md).
