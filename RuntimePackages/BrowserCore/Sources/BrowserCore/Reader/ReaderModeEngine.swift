import Foundation
import SafariLikeContracts

public protocol ReaderContentExtracting: Sendable {
    func isReaderAvailable() async -> Bool
    func extract() async throws -> ReaderContentModel
}

public actor ReaderModeEngine {
    public struct TabState: Sendable {
        public var isAvailable: Bool
        public var isEnabled: Bool
        public var content: ReaderContentModel?

        public init(isAvailable: Bool = false, isEnabled: Bool = false, content: ReaderContentModel? = nil) {
            self.isAvailable = isAvailable
            self.isEnabled = isEnabled
            self.content = content
        }
    }

    private var stateByTabID: [UUID: TabState] = [:]

    public init() {}

    public func state(tabID: UUID) -> TabState {
        stateByTabID[tabID] ?? TabState()
    }

    public func setAvailable(tabID: UUID, isAvailable: Bool) {
        var st = stateByTabID[tabID] ?? TabState()
        st.isAvailable = isAvailable
        if !isAvailable {
            st.isEnabled = false
            st.content = nil
        }
        stateByTabID[tabID] = st
    }

    public func disable(tabID: UUID) {
        var st = stateByTabID[tabID] ?? TabState()
        st.isEnabled = false
        st.content = nil
        stateByTabID[tabID] = st
    }

    public func enable(tabID: UUID, extractor: any ReaderContentExtracting) async -> Bool {
        let available = await extractor.isReaderAvailable()
        setAvailable(tabID: tabID, isAvailable: available)
        guard available else { return false }

        do {
            let content = try await extractor.extract()
            var st = stateByTabID[tabID] ?? TabState()
            st.isEnabled = true
            st.content = content
            stateByTabID[tabID] = st
            return true
        } catch {
            disable(tabID: tabID)
            return false
        }
    }

    public func remove(tabID: UUID) {
        stateByTabID.removeValue(forKey: tabID)
    }
}
