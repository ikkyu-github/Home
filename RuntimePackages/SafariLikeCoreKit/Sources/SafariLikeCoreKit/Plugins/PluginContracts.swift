import SafariLikeContracts

// This file now focuses on shared plugin manifest and high-level
// contracts. Core primitives like `PluginCapability`, navigation
// types, errors, and context protocols live in dedicated files:
// - PluginCapability.swift
// - NavigationTypes.swift
// - PluginError.swift
// - NavigationReadContext.swift

// MARK: - Resource Plugin Manifest

/// Compile-time / resource plugin manifest description.
///
/// This is intentionally WebKit-agnostic and encodes only metadata
/// + high-level permissions. Swift plugins are still registered via
/// `CompileTimePluginRegistry` + a per-window runtime host/registry, while resource plugins (JS/CSS/content-blocker
/// rules) use this manifest and are applied by the host.
public typealias PluginManifest = SafariLikeContracts.PluginManifest

// WebsitePreferencesProviding lives in SafariLikeContracts.

