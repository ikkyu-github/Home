import Foundation
import CoreGraphics

extension TabWebStore {
    // MARK: - Observers, Related, Companion
    internal func setupObservers() {
        // Currently no external observers to register.
        // Future NotificationCenter/KVO observers should be added here.
    }

    internal func teardownObservers() {
        pendingScrollSuggestTask?.cancel()
        pendingScrollSuggestTask = nil

        companionTask?.cancel()
        companionTask = nil
    }

    /// Scroll hint from the app layer to drive related extraction.
    ///
    /// - Parameters:
    ///   - contentOffsetY: Current vertical content offset.
    ///   - panVelocityY: Current vertical pan velocity.
    public func requestRelatedSuggestionsFromScrollIfNeeded(
        contentOffsetY: CGFloat,
        panVelocityY: CGFloat
    ) {
        // Background throttling: avoid expensive JS extraction work when not foreground.
        if performanceTier != .foreground {
            teardownObservers()
            return
        }

        guard role == .primary,
              onCompanionItems != nil,
              !isInvalidated,
              !isLoading
        else { return }

        let y = contentOffsetY
        latestScrollSuggestY = y

        let pageKey = (currentURL?.absoluteString ?? "") + "|" + pageTitle
        if pageKey != lastSuggestedPageKey {
            lastSuggestedPageKey = pageKey
            lastScrollSuggestAt = 0
            lastScrollSuggestY = y
        }

        pendingScrollSuggestTask?.cancel()
        let capturedVelocityY = panVelocityY
        pendingScrollSuggestTask = Timing.scheduleOnMain(after: Timing.policy.scrollSuggestDebounceSeconds) { [weak self] in
            guard let self, !self.isInvalidated, !Task.isCancelled else { return }

            let now = CFAbsoluteTimeGetCurrent()
            if (now - self.lastScrollSuggestAt) < 0.55 { return }
            if abs(self.latestScrollSuggestY - self.lastScrollSuggestY) < 160 { return }

            if abs(capturedVelocityY) > 1400 { return }

            self.lastScrollSuggestAt = now
            self.lastScrollSuggestY = self.latestScrollSuggestY

            self.extractRelatedLinksNearViewport { items in
                Task { @MainActor [weak self] in
                    self?.onCompanionItems?(items)
                }
            }
        }
    }

    internal func publishCompanionItemsIfNeeded() {
        // Background throttling: avoid expensive JS extraction work when not foreground.
        if performanceTier != .foreground {
            teardownObservers()
            return
        }

          guard role == .primary,
              onCompanionItems != nil,
              !isInvalidated,
              !Task.isCancelled
        else { return }

        if bypassSmartSplitOnce {
            bypassSmartSplitOnce = false
            return
        }

        companionTask?.cancel()
        companionTask = runTask { @MainActor [weak self] in
            guard let self, !self.isInvalidated, !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled, !self.isInvalidated else { return }

            self.extractRelatedLinksNearViewport { items in
                Task { @MainActor [weak self] in
                    self?.onCompanionItems?(items)
                }
            }
        }
    }

    private func extractRelatedLinksNearViewport(
        completion: @escaping ([CompanionItem]) -> Void
    ) {
        let js = RelatedLinkExtractor.javascript(maxItems: 24)
        guard let handle = webViewHandle, handle.isAlive else { return }
        handle.evaluateJavaScript(js) { value, _ in
            let json = (value as? String) ?? "[]"
            let items = RelatedLinkExtractor.decode(json: json)
            completion(items)
        }
    }
}
