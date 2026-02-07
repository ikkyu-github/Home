import Foundation
import SafariLikeContracts

/// Local-only telemetry engine with a bounded in-memory ring buffer.
///
/// Privacy:
/// - Attributes are sanitized to reduce the chance of PII/URL leakage.
/// - This does not perform networking.
public final class TelemetryEngine: @unchecked Sendable, TelemetryRecording {
    public struct Configuration: Sendable {
        public var capacity: Int
        public var persistence: Persistence?

        public init(capacity: Int = 256, persistence: Persistence? = nil) {
            self.capacity = max(32, capacity)
            self.persistence = persistence
        }
    }

    public enum Persistence: Sendable {
        /// Persist to a file URL (DEBUG-only behavior; ignored in RELEASE).
        case file(url: URL)
    }

    private let lock = NSLock()
    private var events: [TelemetryEvent] = []
    private let config: Configuration

    public init(configuration: Configuration = .init()) {
        self.config = configuration
        #if DEBUG
        if let persistence = configuration.persistence {
            restoreIfPossible(persistence)
        }
        #endif
    }

    public func record(_ event: TelemetryEvent) {
        let sanitized = TelemetrySanitizer.sanitize(event)
        lock.lock()
        defer { lock.unlock() }

        events.append(sanitized)
        if events.count > config.capacity {
            events.removeFirst(events.count - config.capacity)
        }

        #if DEBUG
        if let persistence = config.persistence {
            persistBestEffort(persistence)
        }
        #endif
    }

    public func snapshot() -> [TelemetryEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    #if DEBUG
    private func persistBestEffort(_ persistence: Persistence) {
        switch persistence {
        case let .file(url):
            do {
                let data = try JSONEncoder().encode(events)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: [.atomic])
            } catch {
                // Best-effort only; never crash for telemetry persistence.
            }
        }
    }

    private func restoreIfPossible(_ persistence: Persistence) {
        switch persistence {
        case let .file(url):
            guard let data = try? Data(contentsOf: url) else { return }
            guard let decoded = try? JSONDecoder().decode([TelemetryEvent].self, from: data) else { return }
            events = Array(decoded.suffix(config.capacity))
        }
    }
    #endif
}

public enum TelemetrySanitizer {
    /// Returns a sanitized, privacy-safe variant of the event.
    public static func sanitize(_ event: TelemetryEvent) -> TelemetryEvent {
        var sanitized = event
        sanitized.attributes = sanitizeAttributes(event.attributes)
        sanitized.sceneID = sanitizeSceneID(event.sceneID)
        return sanitized
    }

    public static func sanitizeSceneID(_ sceneID: String?) -> String? {
        guard let sceneID else { return nil }
        // Keep sceneID stable but avoid accidental long/structured identifiers.
        let trimmed = sceneID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        return String(trimmed.prefix(80))
    }

    public static func sanitizeAttributes(_ attributes: [String: String]) -> [String: String] {
        guard attributes.isEmpty == false else { return [:] }

        var out: [String: String] = [:]
        out.reserveCapacity(attributes.count)

        for (rawKey, rawValue) in attributes {
            let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty { continue }

            // Hard-forbid keys likely to contain user data.
            let keyLower = key.lowercased()
            if TelemetryPIIRule.forbiddenKeySubstrings.contains(where: { keyLower.contains($0) }) {
                continue
            }

            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { continue }

            // Drop values that look like URLs or contain obvious URL delimiters.
            let vLower = value.lowercased()
            if vLower.contains("://") || vLower.hasPrefix("http") || vLower.contains("www.") {
                continue
            }

            // Keep bounded string sizes to avoid accidental payloads.
            out[key] = String(value.prefix(180))
        }

        return out
    }
}
