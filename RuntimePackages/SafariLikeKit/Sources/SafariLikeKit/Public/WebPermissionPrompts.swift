import Foundation
import SafariLikeCoreKit
import SwiftUI
public typealias WebPermissionKind = SafariLikeCoreKit.WebPermissionKind
public typealias WebPermissionPromptRequest = SafariLikeCoreKit.WebPermissionPromptRequest
public typealias WebPermissionPromptDecision = SafariLikeCoreKit.WebPermissionPromptDecision
public typealias WebPermissionPromptResponse = SafariLikeCoreKit.WebPermissionPromptResponse
public extension Notification.Name {
    /// object: WebPermissionPromptRequest
    static let webPermissionPromptRequested = Notification.Name("webPermissionPromptRequested")
    /// object: WebPermissionPromptResponse
    static let webPermissionPromptResponded = Notification.Name("webPermissionPromptResponded")
}
public extension View {
    /// Presents SafariLikeKit's web permission prompts as a SwiftUI `Alert`.
    ///
    /// This keeps permission prompt UI out of the app target.
    func safariLikeWebPermissionPrompts() -> some View {
        modifier(WebPermissionPromptAlertModifier())
    }
}
private struct WebPermissionPromptAlertModifier: ViewModifier {
    @State private var activePrompt: WebPermissionPromptRequest?
    @State private var queuedPrompts: [WebPermissionPromptRequest] = []
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .webPermissionPromptRequested)) { note in
                guard let request = note.object as? WebPermissionPromptRequest else { return }
                guard request.host.isEmpty == false else { return }
                if activePrompt == nil {
                    activePrompt = request
                } else {
                    queuedPrompts.append(request)
                }
            }
            .alert(
                isPresented: Binding(
                    get: { activePrompt != nil },
                    set: { isPresented in
                        if !isPresented { activePrompt = nil }
                    }
                )
            ) {
                guard let request = activePrompt else {
                    return Alert(title: Text("Permission"), message: Text(""), dismissButton: .default(Text("OK")))
                }
                let title = "Allow \(request.host) to \(request.kind.promptVerb) \(request.kind.title)?"
                return Alert(
                    title: Text(title),
                    message: Text("You can change this later in Website Settings."),
                    primaryButton: .default(Text("Allow")) {
                        respond(to: request, decision: .allow)
                    },
                    secondaryButton: .destructive(Text("Deny")) {
                        respond(to: request, decision: .deny)
                    }
                )
            }
    }
    private func respond(to request: WebPermissionPromptRequest, decision: WebPermissionPromptDecision) {
        NotificationCenter.default.post(
            name: .webPermissionPromptResponded,
            object: WebPermissionPromptResponse(id: request.id, decision: decision)
        )
        if queuedPrompts.isEmpty == false {
            activePrompt = queuedPrompts.removeFirst()
        } else {
            activePrompt = nil
        }
    }
}
