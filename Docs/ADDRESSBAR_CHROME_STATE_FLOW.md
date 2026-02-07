# Address Bar / Chrome State Flow (Scaffolding)

Goal: define stable, UI-safe contract types for Address Bar + Chrome state/event ownership, without changing behavior.

## Current sources of truth

### Address Bar

- Core (deterministic UX state): `SafariLikeContracts.AddressBarState`
- Core reducer: `SafariLikeCoreKit.AddressBarReducer`
- UI rendering model: `SafariLikeUXKit.AddressBarUIState`
- UI state machine (pure): `SafariLikeUXKit.AddressBarUIStateMachine`
- Current owner in app layer: `SafariLikeKit.SplitBrowserAddressBarDomain`

### Chrome

- Pure chrome machine: `SafariLikeUXKit.ChromeStateMachine`
- Snapshot value: `SafariLikeUXKit.ChromeSnapshot`
- Current owner in app layer: `SafariLikeKit.BrowserChromeState`

## Contracts added (UI-safe)

- `SafariLikeContracts.AddressBarEvent`, `SafariLikeContracts.AddressBarViewState`
- `SafariLikeContracts.ChromeEvent`, `SafariLikeContracts.ChromeViewState`

These types avoid CoreKit/WebKit objects and only use primitives.

## State flow diagram

```mermaid
flowchart LR
    subgraph View[SwiftUI Views]
        V1[TopBar / Omnibox]
        V2[Chrome container]
    end

    subgraph Kit[SafariLikeKit]
        D1[SplitBrowserAddressBarDomain]
        C1[BrowserChromeState]
    end

    subgraph UXKit[SafariLikeUXKit]
        U1[AddressBarUIStateMachine]
        U2[ChromeStateMachine]
    end

    subgraph Core[Core + Contracts]
        S1[AddressBarState]
        R1[AddressBarReducer]
        CT1[AddressBarEvent / AddressBarViewState]
        CT2[ChromeEvent / ChromeViewState]
    end

    V1 -->|AddressBarEvent| D1
    D1 -->|AddressBarAction| R1
    R1 -->|new AddressBarState| S1
    D1 -->|derive UI state| U1
    U1 -->|AddressBarUIState| D1
    D1 -->|map| CT1
    CT1 --> V1

    V2 -->|focus/overview intents| C1
    C1 -->|reduce Event| U2
    U2 -->|ChromeSnapshot| C1
    C1 -->|map| CT2
    CT2 --> V2
```

## What changed (no behavior)

- `SplitBrowserAddressBarDomain` gained a protocol adapter surface (`AddressBarStateProviding`) via mapping:
  - Contracts `AddressBarEvent` -> UXKit `AddressBarUIEvent`
  - UXKit `AddressBarUIState` -> Contracts `AddressBarViewState`
- `BrowserChromeState` gained a `chromeViewState` computed mapping from its `chromeSnapshot`.

## Migration points (next PR)

- Update `TopBarView` / omnibox views to render from `AddressBarViewState` (contract) rather than directly from UXKit `AddressBarUIState` or ad-hoc fields.
- Route address-bar intent entrypoints in `SplitBrowserViewModel+ChromeState.swift` through `AddressBarEvent` (contract) instead of directly calling `AddressBarUIEvent`.
- Optional: introduce a `ChromeStateProviding` protocol once `BrowserChromeState` is slimmed or split (keeping file-scope-private dispatch constraints in mind).
