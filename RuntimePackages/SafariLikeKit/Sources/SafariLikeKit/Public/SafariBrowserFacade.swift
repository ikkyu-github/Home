// SafariBrowserFacade.swift
// Public API for SafariLikeKit
import Foundation
import SafariLikeCoreKit
protocol SafariBrowserSession {
    func openTab(url: URL)
    func closeTab(id: UUID)
}
struct SafariBrowserConfiguration {
    init() {}
}
