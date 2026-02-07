import Foundation
import SafariLikeCoreKit
actor OmniboxSuggestionEngine {
    struct HistoryItemSnapshot: Sendable {
        let title: String
        let urlString: String
        let visitedAt: Date
    }
    struct BookmarkSnapshot: Sendable {
        let title: String
        let urlString: String
        let createdAt: Date
        let updatedAt: Date
    }
    struct ReadingListItemSnapshot: Sendable {
        let title: String
        let urlString: String
    }
    func compute(
        query: String,
        historyItems: [HistoryItemSnapshot],
        bookmarkItems: [BookmarkSnapshot],
        readingListItems: [ReadingListItemSnapshot],
        now: Date = Date()
    ) -> [SplitBrowserViewModel.OmniboxSuggestion] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var candidates: [(item: SplitBrowserViewModel.OmniboxSuggestion, score: Double)] = []
        let queryLower = q.lowercased()
        let queryWords = queryLower.split(separator: " ").filter { !$0.isEmpty }
        // Domain popularity from history
        var domainCounts: [String: Int] = [:]
        domainCounts.reserveCapacity(min(64, historyItems.count))
        for item in historyItems {
            if Task.isCancelled { return [] }
            if let host = URL(string: item.urlString)?.host {
                domainCounts[host, default: 0] += 1
            }
        }
        func calculateMatchScore(text: String, query: String, isTitle: Bool) -> Double {
            if Task.isCancelled { return 0 }
            let textLower = text.lowercased()
            var score = 0.0
            if textLower.hasPrefix(query) { score += isTitle ? 25.0 : 20.0 }
            let wordPattern = "\\b\(NSRegularExpression.escapedPattern(for: query))"
            if let regex = try? NSRegularExpression(pattern: wordPattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: textLower, range: NSRange(textLower.startIndex..., in: textLower))
                score += Double(matches.count) * (isTitle ? 15.0 : 12.0)
            }
            var consecutiveCount = 0
            var maxConsecutive = 0
            for (i, queryChar) in query.enumerated() {
                if Task.isCancelled { return 0 }
                if i < textLower.count {
                    let textIndex = textLower.index(textLower.startIndex, offsetBy: i)
                    if textLower[textIndex] == queryChar {
                        consecutiveCount += 1
                        maxConsecutive = max(maxConsecutive, consecutiveCount)
                    } else {
                        consecutiveCount = 0
                    }
                }
            }
            if maxConsecutive >= 2 { score += Double(maxConsecutive) * 2.0 }
            if textLower.contains(query) && score == 0 { score += isTitle ? 8.0 : 5.0 }
            if query.count <= 3 && !textLower.hasPrefix(query) && score > 0 { score *= 0.7 }
            return score
        }
        // History suggestions
        for item in historyItems.prefix(100) {
            if Task.isCancelled { return [] }
            let titleScore = calculateMatchScore(text: item.title, query: queryLower, isTitle: true)
            let urlScore = calculateMatchScore(text: item.urlString, query: queryLower, isTitle: false)
            let matchScore = max(titleScore, urlScore)
            guard matchScore > 0 else { continue }
            let hoursSinceVisit = now.timeIntervalSince(item.visitedAt) / (60 * 60)
            let recencyScore: Double
            if hoursSinceVisit < 1 { recencyScore = 100.0 }
            else if hoursSinceVisit < 24 { recencyScore = 90.0 * exp(-hoursSinceVisit / 12.0) }
            else if hoursSinceVisit < 168 { recencyScore = 70.0 * exp(-(hoursSinceVisit - 24) / 72.0) }
            else if hoursSinceVisit < 720 { recencyScore = 40.0 * exp(-(hoursSinceVisit - 168) / 275.0) }
            else { recencyScore = max(5.0, 20.0 * exp(-(hoursSinceVisit - 720) / 8760.0)) }
            var domainBonus = 0.0
            if let host = URL(string: item.urlString)?.host, let count = domainCounts[host], count > 1 {
                domainBonus = min(15.0, Double(count - 1) * 3.0)
            }
            var urlStructureBonus = 0.0
            if let url = URL(string: item.urlString), q.count <= 4 {
                let pathComponents = url.pathComponents.filter { $0 != "/" }
                if pathComponents.count <= 1 { urlStructureBonus = 8.0 }
            }
            var multiWordBonus = 0.0
            if queryWords.count > 1 {
                var matchedWords = 0
                let titleLower = item.title.lowercased()
                let urlLower = item.urlString.lowercased()
                for word in queryWords {
                    if Task.isCancelled { return [] }
                    if titleLower.contains(word) || urlLower.contains(word) {
                        matchedWords += 1
                    }
                }
                if matchedWords == queryWords.count { multiWordBonus = 10.0 }
                else if matchedWords > 0 { multiWordBonus = Double(matchedWords) * 3.0 }
            }
            let finalScore = recencyScore + domainBonus + urlStructureBonus + multiWordBonus + matchScore
            candidates.append((
                item: .init(
                    title: item.title.isEmpty ? item.urlString : item.title,
                    subtitle: item.urlString,
                    urlString: item.urlString,
                    query: nil,
                    kind: .history
                ),
                score: finalScore
            ))
        }
        // Bookmarks
        for bm in bookmarkItems.prefix(100) {
            if Task.isCancelled { return [] }
            let titleScore = calculateMatchScore(text: bm.title, query: queryLower, isTitle: true)
            let urlScore = calculateMatchScore(text: bm.urlString, query: queryLower, isTitle: false)
            let matchScore = max(titleScore, urlScore)
            guard matchScore > 0 else { continue }
            let hoursSinceUpdate = now.timeIntervalSince(bm.updatedAt) / (60 * 60)
            let hoursSinceCreated = now.timeIntervalSince(bm.createdAt) / (60 * 60)
            let baseScore = 60.0
            var recencyBonus = 0.0
            if hoursSinceUpdate < 24 { recencyBonus = 25.0 }
            else if hoursSinceUpdate < 168 { recencyBonus = 15.0 }
            else if hoursSinceUpdate < 720 { recencyBonus = 8.0 }
            let ageBonus = min(5.0, hoursSinceCreated / (24 * 30))
            var urlStructureBonus = 0.0
            if let url = URL(string: bm.urlString), q.count <= 4 {
                let pathComponents = url.pathComponents.filter { $0 != "/" }
                if pathComponents.count <= 1 { urlStructureBonus = 6.0 }
            }
            var multiWordBonus = 0.0
            if queryWords.count > 1 {
                var matchedWords = 0
                let titleLower = bm.title.lowercased()
                let urlLower = bm.urlString.lowercased()
                for word in queryWords {
                    if Task.isCancelled { return [] }
                    if titleLower.contains(word) || urlLower.contains(word) {
                        matchedWords += 1
                    }
                }
                if matchedWords == queryWords.count { multiWordBonus = 8.0 }
                else if matchedWords > 0 { multiWordBonus = Double(matchedWords) * 2.5 }
            }
            let finalScore = baseScore + recencyBonus + ageBonus + urlStructureBonus + multiWordBonus + matchScore
            candidates.append((
                item: .init(
                    title: bm.title.isEmpty ? bm.urlString : bm.title,
                    subtitle: bm.urlString,
                    urlString: bm.urlString,
                    query: nil,
                    kind: .bookmark
                ),
                score: finalScore
            ))
        }
        // Reading list
        for rl in readingListItems.prefix(100) {
            if Task.isCancelled { return [] }
            let titleScore = calculateMatchScore(text: rl.title, query: queryLower, isTitle: true)
            let urlScore = calculateMatchScore(text: rl.urlString, query: queryLower, isTitle: false)
            let matchScore = max(titleScore, urlScore)
            guard matchScore > 0 else { continue }
            let baseScore = 30.0
            var urlStructureBonus = 0.0
            if let url = URL(string: rl.urlString), q.count <= 4 {
                let pathComponents = url.pathComponents.filter { $0 != "/" }
                if pathComponents.count <= 1 { urlStructureBonus = 4.0 }
            }
            var multiWordBonus = 0.0
            if queryWords.count > 1 {
                var matchedWords = 0
                let titleLower = rl.title.lowercased()
                let urlLower = rl.urlString.lowercased()
                for word in queryWords {
                    if Task.isCancelled { return [] }
                    if titleLower.contains(word) || urlLower.contains(word) {
                        matchedWords += 1
                    }
                }
                if matchedWords == queryWords.count { multiWordBonus = 6.0 }
                else if matchedWords > 0 { multiWordBonus = Double(matchedWords) * 2.0 }
            }
            let finalScore = baseScore + urlStructureBonus + multiWordBonus + matchScore
            candidates.append((
                item: .init(
                    title: rl.title.isEmpty ? rl.urlString : rl.title,
                    subtitle: rl.urlString,
                    urlString: rl.urlString,
                    query: nil,
                    kind: .readingList
                ),
                score: finalScore
            ))
        }
        let topSuggestions = candidates
            .sorted { $0.score > $1.score }
            .prefix(6)
            .map { $0.item }
        var out = Array(topSuggestions)
        out.append(.init(title: "Search \(q)", subtitle: nil, urlString: nil, query: q, kind: .search))
        return out
    }
}
