import SwiftUI

public struct ChromeEventRouter<Content: View>: View {
    @ObservedObject public var domain: ChromeDomain
    let content: (ChromeViewState, @escaping (ChromeEvent) -> Void) -> Content

    public init(domain: ChromeDomain, @ViewBuilder content: @escaping (ChromeViewState, @escaping (ChromeEvent) -> Void) -> Content) {
        self.domain = domain
        self.content = content
    }

    public var body: some View {
        content(domain.state) { event in
            domain.dispatch(event)
        }
    }
}
