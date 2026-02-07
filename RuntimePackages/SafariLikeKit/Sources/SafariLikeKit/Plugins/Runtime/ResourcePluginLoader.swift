import Foundation
import SafariLikeCoreKit
/// Represents a fully resolved resource plugin on disk.
///
/// This is a domain-layer type that pairs a decoded
/// `PluginManifest` with concrete file URLs for any
/// content rule lists, user scripts, or style sheets.
struct ResourcePluginPackage {
    struct ResolvedUserScript {
        let definition: PluginManifest.UserScript
        let url: URL
    }
    struct ResolvedStyleSheet {
        let definition: PluginManifest.StyleSheet
        let url: URL
    }
    let manifest: PluginManifest
    let baseURL: URL
    /// Resolved JSON content rule list files.
    let contentRuleListURLs: [URL]
    /// Resolved JS user scripts.
    let userScripts: [ResolvedUserScript]
    /// Resolved CSS style sheets.
    let styleSheets: [ResolvedStyleSheet]
}
/// Loader responsible for discovering and validating
/// resource plugins from well-known locations.
///
/// Current search order:
/// 1. App bundle (read-only, built-in plugins)
/// 2. Documents/Plugins/{pluginID}/ (user-installed plugins)
///
/// Each plugin directory is expected to contain a
/// `manifest.json` file conforming to `PluginManifest`.
struct ResourcePluginLoader {
    /// Maximum allowable size (in bytes) for any single
    /// resource file referenced by a plugin.
    static let maxResourceSize: Int64 = 5 * 1024 * 1024 // 5 MB
    /// Upper bounds to avoid unbounded injection per plugin.
    static let maxRuleListsPerPlugin = 8
    static let maxUserScriptsPerPlugin = 16
    static let maxStyleSheetsPerPlugin = 16
    /// Discover resource plugins from both bundle and documents.
    func loadAllPlugins() async -> [ResourcePluginPackage] {
        var packages: [ResourcePluginPackage] = []
        packages.append(contentsOf: loadFromBundle())
        packages.append(contentsOf: loadFromDocuments())
        return packages
    }
    // MARK: - Bundle
    private func loadFromBundle() -> [ResourcePluginPackage] {
        guard let pluginsURL = Bundle.main.resourceURL?.appendingPathComponent("Plugins") else {
            return []
        }
        return loadFromDirectory(pluginsURL)
    }
    // MARK: - Documents
    private func loadFromDocuments() -> [ResourcePluginPackage] {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsURL = urls.first else { return [] }
        let pluginsURL = documentsURL.appendingPathComponent("Plugins", isDirectory: true)
        return loadFromDirectory(pluginsURL)
    }
    // MARK: - Core Loading
    private func loadFromDirectory(_ root: URL) -> [ResourcePluginPackage] {
        var results: [ResourcePluginPackage] = []
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for entry in contents {
                guard isDirectory(entry) else { continue }
                if let package = loadPackage(at: entry) {
                    results.append(package)
                }
            }
        } catch {
            // Discovery errors are non-fatal; invalid directories are ignored.
        }
        return results
    }
    private func loadPackage(at url: URL) -> ResourcePluginPackage? {
        let manifestURL = url.appendingPathComponent("manifest.json", isDirectory: false)
        guard let data = try? Data(contentsOf: manifestURL) else {
            return nil
        }
        // Basic size guard on the manifest itself.
        if Int64(data.count) > Self.maxResourceSize {
            return nil
        }
        do {
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
            // Resolve and validate referenced resources.
            let contentRuleListURLs = resolveRuleLists(manifest, baseURL: url)
            let userScripts = resolveUserScripts(manifest, baseURL: url)
            let styleSheets = resolveStyleSheets(manifest, baseURL: url)
            return ResourcePluginPackage(
                manifest: manifest,
                baseURL: url,
                contentRuleListURLs: contentRuleListURLs,
                userScripts: userScripts,
                styleSheets: styleSheets
            )
        } catch {
            return nil
        }
    }
    // MARK: - Helpers
    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
    private func resolveRuleLists(_ manifest: PluginManifest, baseURL: URL) -> [URL] {
        guard let names = manifest.contentRuleLists, !names.isEmpty else { return [] }
        return names.prefix(Self.maxRuleListsPerPlugin).compactMap { name in
            guard let fileURL = safeJoin(baseURL: baseURL, relativePath: name) else { return nil }
            guard validateFile(url: fileURL) else { return nil }
            return fileURL
        }
    }
    private func resolveUserScripts(_ manifest: PluginManifest, baseURL: URL) -> [ResourcePluginPackage.ResolvedUserScript] {
        guard let scripts = manifest.userScripts, !scripts.isEmpty else { return [] }
        return scripts.prefix(Self.maxUserScriptsPerPlugin).compactMap { script in
            guard let fileURL = safeJoin(baseURL: baseURL, relativePath: script.path) else { return nil }
            guard validateFile(url: fileURL) else { return nil }
            return ResourcePluginPackage.ResolvedUserScript(definition: script, url: fileURL)
        }
    }
    private func resolveStyleSheets(_ manifest: PluginManifest, baseURL: URL) -> [ResourcePluginPackage.ResolvedStyleSheet] {
        guard let styles = manifest.styleSheets, !styles.isEmpty else { return [] }
        return styles.prefix(Self.maxStyleSheetsPerPlugin).compactMap { style in
            guard let fileURL = safeJoin(baseURL: baseURL, relativePath: style.path) else { return nil }
            guard validateFile(url: fileURL) else { return nil }
            return ResourcePluginPackage.ResolvedStyleSheet(definition: style, url: fileURL)
        }
    }
    /// Join base and relative path while preventing directory traversal
    /// outside of the plugin directory.
    private func safeJoin(baseURL: URL, relativePath: String) -> URL? {
        // Disallow absolute paths and traversal segments.
        guard !relativePath.hasPrefix("/") else { return nil }
        if relativePath.contains("..") { return nil }
        let candidate = baseURL.appendingPathComponent(relativePath)
        // Ensure the resulting path still lies under the base directory.
        let base = baseURL.standardizedFileURL.path
        let path = candidate.standardizedFileURL.path
        guard path.hasPrefix(base) else { return nil }
        return candidate
    }
    /// Validate that file exists and is within size limits.
    private func validateFile(url: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return false }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { return false }
            if let size = values.fileSize {
                return Int64(size) <= Self.maxResourceSize
            }
            return true
        } catch {
            return false
        }
    }
}
