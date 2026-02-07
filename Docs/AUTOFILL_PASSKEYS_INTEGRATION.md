# Autofill / Passwords / Passkeys Integration (System-First)

This repo integrates iOS system Autofill (Passwords) and Passkeys for `WKWebView` **without** implementing a custom password manager.

## Goals

- Use Apple’s secure system features (Passwords + Passkeys) as the credential source.
- Avoid handling/storing credentials or form contents in app code.
- Keep strict layering:
  - SafariLikeContracts: SSOT models
  - BrowserCore: deterministic policy + best-effort status (no platform APIs)
  - SafariLikeCoreKit: WebKit + AuthenticationServices adapters
  - SafariLikeKit: UI and wiring

## Required iOS setup (notes)

### 1) Entitlements / Associated Domains

For a **browser** hosting arbitrary websites in `WKWebView`:

- Web passkeys (WebAuthn) are primarily handled by WebKit + the system.
- App-level `ASAuthorizationPlatformPublicKeyCredentialProvider` flows generally require the app to claim the relying party via Associated Domains, which is **not feasible** for arbitrary sites.

Therefore:

- This project does **not** require Associated Domains to enable passkeys for websites visited in the browser.
- If the app later adds first-party sign-in to a known domain, that specific use-case may require:
  - `webcredentials:` and/or `applinks:` associated domains

### 2) Do not disable Autofill-sensitive WebKit features

The CoreKit config intentionally:

- Uses `WKWebsiteDataStore.default()` for regular
- Uses `WKWebsiteDataStore.nonPersistent()` for private
- Avoids disabling features that would prevent system Autofill

## Manual smoke checklist

- Password Autofill:
  - Visit a known login site.
  - Tap username/password field and confirm iOS Passwords suggestions appear.

- Passkeys:
  - Visit a known site with passkeys configured.
  - Confirm the passkey prompt appears when using the site’s sign-in.

- Private mode:
  - Confirm the app does not persist any Autofill-related hints.
  - Confirm no helper form observer scripts are installed in private tabs.
