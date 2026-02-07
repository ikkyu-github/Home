import Foundation
import SafariLikeContracts

public enum InvariantEnforcer {
    /// Asserts a core invariant.
    ///
    /// - In DEBUG: fails fast (crash-only) with rich context.
    /// - In RELEASE: records a telemetry event and returns `false`.
    @discardableResult
    public static func assertInvariant(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String,
        category: CrashCategory,
        context: @autoclosure () -> CrashContextSnapshot?,
        telemetry: (any TelemetryRecording)? = nil
    ) -> Bool {
        if condition() { return true }

        let msg = message()
        let snapshot = context()

        let event = TelemetryEvent(
            type: .parityAuditRun,
            sceneID: snapshot?.sceneID,
            attributes: Self.makeInvariantAttributes(category: category, message: msg, context: snapshot)
        )
        telemetry?.record(event)

        #if DEBUG
        // Crash-only in DEBUG: make the failure obvious and actionable.
        let rendered = renderFailure(category: category, message: msg, context: snapshot)
        preconditionFailure(rendered)
        #else
        // RELEASE: fail-safe path; caller chooses recovery.
        return false
        #endif
    }

    private static func makeInvariantAttributes(
        category: CrashCategory,
        message: String,
        context: CrashContextSnapshot?
    ) -> [String: String] {
        var attrs: [String: String] = [
            "event": "invariantViolation",
            "category": category.rawValue,
            "message": String(message.prefix(160))
        ]
        if let context {
            attrs["activeTabCount"] = String(context.activeTabCount)
            attrs["activeWebViewCount"] = String(context.activeWebViewCount)
            attrs["memoryPressureLevel"] = context.memoryPressureLevel.rawValue
            if let action = context.lastUserAction {
                attrs["lastUserAction"] = String(action.prefix(80))
            }
        }
        return attrs
    }

    private static func renderFailure(category: CrashCategory, message: String, context: CrashContextSnapshot?) -> String {
        var lines: [String] = []
        lines.append("[Invariant] \(category.rawValue): \(message)")
        if let context {
            lines.append("sceneID=\(context.sceneID)")
            lines.append("activeTabCount=\(context.activeTabCount)")
            lines.append("activeWebViewCount=\(context.activeWebViewCount)")
            lines.append("memoryPressureLevel=\(context.memoryPressureLevel.rawValue)")
            if let action = context.lastUserAction {
                lines.append("lastUserAction=\(action)")
            }
        }
        return lines.joined(separator: " | ")
    }
}
