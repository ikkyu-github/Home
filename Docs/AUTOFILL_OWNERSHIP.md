# Autofill / Passwords / Passkeys – File Ownership

## SafariLikeContracts (SSOT)

- RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/Autofill/AutofillModels.swift
- RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/WebsitePreferences/WebsitePreferences.swift (adds per-site `autofillEnabled`)

## BrowserCore (Domain)

- RuntimePackages/BrowserCore/Sources/BrowserCore/Autofill/FormFillPolicyEngine.swift
- RuntimePackages/BrowserCore/Sources/BrowserCore/Autofill/AutofillStatusService.swift

## SafariLikeCoreKit (WebKit runtime)

- RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Autofill/AppleAutofillSystemChecker.swift
- RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/TabWebStore/TabWebStore+ScriptMessageHandler.swift (minimal form probe)
- RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Diagnostics/CoreKitMetrics.swift (aggregate counters)

## SafariLikeKit (Composition/UI)

- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/BrowserEnvironment.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SafariLikeFactory.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Stores/CoreStoreFactory.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Views/WebsiteSettingsView.swift (per-site Autofill toggle + debug entry)
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Debug/AutofillDebugView.swift (DEBUG only)

## App target

- App/AppSettings.swift (global `app.autofill.enabled`)
- App/Views/SettingsView.swift (global UI toggle)
