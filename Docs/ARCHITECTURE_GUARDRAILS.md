# Architecture guardrails (anti-bloat)

Date: 28 มกราคม 2569

This repo is intentionally split into packages with a strict “App as composition root” rule.
The goal is to prevent long‑term bloat from creeping into the app target and from accidental layer inversion.

## Current package dependency graph (SwiftPM)

From `RuntimePackages/*/Package.swift`:

- `SafariLikeContracts` → bottom layer
- `BrowserCore` → depends on `SafariLikeContracts`
- `SafariLikeCoreKit` → depends on `BrowserCore`, `SafariLikeContracts`
- `SafariLikeUXKit` → depends on `SafariLikeContracts`
- `SafariLikeKit` (facade) → depends on `BrowserCore`, `SafariLikeCoreKit`, `SafariLikeUXKit`, `SafariLikeContracts`
- `SafariLikeUIKit` (UIKit host) → depends on `SafariLikeKit`, `SafariLikeCoreKit`, `BrowserCore`, `SafariLikeContracts`

There is no SwiftPM-level circular dependency in this graph.

## Primary future bloat risks (what to watch)

### 1) Facade “leaks” via `typealias` (MemberImportVisibility)
Swift can require importing the defining module to access static members / enum cases even when you `public typealias` it.
Result: pressure to import internal modules in App, and gradual facade erosion.

Guardrail:
- Prefer **wrapper types/functions** in `SafariLikeKit/Public/*` instead of `public typealias` for app-facing APIs.

### 2) “UXKit” becoming a dumping ground
`SafariLikeUXKit` is a policy/layout layer. A common bloat pattern is moving unrelated “device/app glue” into it.

Guardrail:
- UXKit contains **pure policy + layout heuristics** only.
- If something needs WebKit/engine state, it belongs in `SafariLikeCoreKit`/`SafariLikeKit`.
- If something is app-only UI preference, it belongs in App.

### 3) Host-layer pull-through (`SafariLikeUIKit`)
If `SafariLikeUIKit` re-exports or becomes required for default behaviors, App ends up importing it.

Guardrail:
- `SafariLikeKit` must never import `SafariLikeUIKit`.
- App must never import `SafariLikeUIKit`.

### 4) Duplicate implementations
Duplicates are a long-term bloat accelerant (confusion, dead code, multiple sources of truth).

Guardrail:
- No duplicate `.swift` basenames across modules (or at least treat as warning).
- Track duplicate type names across modules and require justification/allowlist.

## Enforced rules (recommended)

### Layering
- **App** imports only Apple frameworks + `SafariLikeKit`.
- `SafariLikeKit` (facade) may depend on: `BrowserCore`, `SafariLikeCoreKit`, `SafariLikeUXKit`, `SafariLikeContracts`.
- `SafariLikeUIKit` is optional “host” and must not be required by App.
- `SafariLikeContracts` has no local dependencies.
- `BrowserCore` must not import `SafariLikeKit`, `SafariLikeCoreKit`, `SafariLikeUIKit`, `SafariLikeUXKit`.
- `SafariLikeCoreKit` must not import `SafariLikeKit`, `SafariLikeUIKit`, `SafariLikeUXKit`.

### API surface
- Avoid `@_exported import`.
- Avoid `public typealias` for app-facing enums/structs where callers need cases/static members.

## Script: architecture audit

Run:

```bash
python3 Dev/Tools/Scripts/architecture_audit.py
```

Optional:

```bash
python3 Dev/Tools/Scripts/architecture_audit.py --dot
# writes build/architecture/module_graph.dot
```

To fail CI on warnings too:

```bash
python3 Dev/Tools/Scripts/architecture_audit.py --fail-on-warn
```

What it checks:
- Local module import graph (by parsing `import ...` in Swift files)
- Circular references at module-import level
- Forbidden module imports (layer inversion)
- Duplicate `.swift` basenames (reuse smell)
- Duplicate type names across modules (heuristic)

## Permanent anti-bloat rules (enforced)

Goal: the repo should trend smaller over time.

Rules:
1. Every refactor must:
	- Delete at least one file, **or**
	- Reduce total lines of code (net LOC).
2. Adding a file requires:
	- Naming the file it replaces.
3. No new ViewModel unless:
	- Replacing an existing one.
4. No new Store unless:
	- Replacing derived state.

### How the repo enforces this

Run:

```bash
python3 Dev/Tools/Scripts/architecture_audit.py --anti-bloat
```

To also include untracked files (local-only, before staging):

```bash
python3 Dev/Tools/Scripts/architecture_audit.py --anti-bloat --include-untracked
```

By default it compares against `origin/main` when available, otherwise `HEAD~1`.
You can override:

```bash
python3 Dev/Tools/Scripts/architecture_audit.py --anti-bloat --base origin/main
```

### “Replaces:” marker format

When you add a new code file (`.swift`, `.py`, `.sh`), include a marker near the top:

```
Replaces: RuntimePackages/.../OldThing.swift
```

The audit expects that the replaced path is deleted/renamed-away, or shrinks (more deletions than additions) in the same change.

It also flags any newly-added `*ViewModel` or `*Store` type declarations unless an existing one is removed in the same diff.

### Optional: quick size tracking

The anti-bloat audit prints net LOC delta. For a quick snapshot of the current size:

```bash
python3 Dev/Tools/Scripts/architecture_audit.py --metrics
```

If you want a long-term history, run it periodically and paste the output into a log/issue.

## CI recommendation

Add a CI step:

```bash
python3 Dev/Tools/Scripts/architecture_audit.py --fail-on-warn
```

…and keep the allowlist small (prefer fixing issues rather than expanding exceptions).
