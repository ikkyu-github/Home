import Combine
import Foundation
import SwiftUI
import SafariLikeCoreKit
@MainActor
public final class CrashGuard: ObservableObject {
    public nonisolated struct Config: Sendable {
        public var crashWindowMinutes: Double = 5
        public var crashThreshold: Int = 3
        public var crashWindow: TimeInterval { crashWindowMinutes * 60 }
        public init() {}
    }
    public enum LaunchAction: String, Sendable {
        case openWithTabsSafeRestore
        case openBlank
    }
    private enum Keys {
        static let lastLaunchTimestamp = "CrashGuard.lastLaunchTimestamp"
        static let consecutiveCrashCount = "CrashGuard.consecutiveCrashCount"
        static let lastExitWasClean = "CrashGuard.lastExitWasClean"
    }
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let config: Config
    @Published public private(set) var isInSafeMode: Bool = false
    @Published public private(set) var consecutiveCrashCount: Int = 0
    @Published public private(set) var lastLaunchTimestamp: Date?
    @Published public private(set) var lastExitWasClean: Bool = true
    @Published public private(set) var selectedLaunchAction: LaunchAction? = nil
    public func consumeSelectedLaunchAction() -> LaunchAction? {
        let action = selectedLaunchAction
        selectedLaunchAction = nil
        return action
    }
    public init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        config: Config = .init()
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.config = config
        let storedTimestamp = defaults.object(forKey: Keys.lastLaunchTimestamp) as? Date
        self.lastLaunchTimestamp = storedTimestamp
        if defaults.object(forKey: Keys.consecutiveCrashCount) == nil {
            self.consecutiveCrashCount = 0
        } else {
            self.consecutiveCrashCount = defaults.integer(forKey: Keys.consecutiveCrashCount)
        }
        if defaults.object(forKey: Keys.lastExitWasClean) == nil {
            self.lastExitWasClean = true
        } else {
            self.lastExitWasClean = defaults.bool(forKey: Keys.lastExitWasClean)
        }
    }
    // MARK: - Launch Evaluation
    /// Call as early as possible during app startup.
    public func evaluateOnAppStart(now: Date = Date()) {
        let previousLaunch = (defaults.object(forKey: Keys.lastLaunchTimestamp) as? Date)
        let previousExitWasClean: Bool = {
            if defaults.object(forKey: Keys.lastExitWasClean) == nil { return true }
            return defaults.bool(forKey: Keys.lastExitWasClean)
        }()
        let withinWindow: Bool = {
            guard let previousLaunch else { return false }
            return now.timeIntervalSince(previousLaunch) < config.crashWindow
        }()
        if previousExitWasClean == false && withinWindow {
            consecutiveCrashCount = max(0, defaults.integer(forKey: Keys.consecutiveCrashCount)) + 1
        } else {
            consecutiveCrashCount = 0
        }
        defaults.set(consecutiveCrashCount, forKey: Keys.consecutiveCrashCount)
        defaults.set(now, forKey: Keys.lastLaunchTimestamp)
        lastLaunchTimestamp = now
        lastExitWasClean = false
        // Mark current run as not-clean immediately.
        defaults.set(false, forKey: Keys.lastExitWasClean)
        isInSafeMode = consecutiveCrashCount >= config.crashThreshold
        selectedLaunchAction = nil
    }
    // MARK: - Lifecycle Markers
    /// Call this after session persistence flush is requested (best-effort).
    public func markCleanExitAfterBestEffortFlush(delayNanoseconds: UInt64 = 350_000_000) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            markExitWasClean()
        }
    }
    public func markExitWasClean() {
        defaults.set(true, forKey: Keys.lastExitWasClean)
        lastExitWasClean = true
    }
    /// Marks the current run as "not clean" again (e.g. when returning to foreground).
    public func markRunningNotClean() {
        defaults.set(false, forKey: Keys.lastExitWasClean)
        lastExitWasClean = false
    }
    // MARK: - Safe Mode Actions
    public func chooseOpenWithTabsSafeRestore() {
        selectedLaunchAction = .openWithTabsSafeRestore
        exitSafeModeForThisLaunch()
    }
    public func chooseOpenBlank() {
        selectedLaunchAction = .openBlank
        exitSafeModeForThisLaunch()
    }
    private func exitSafeModeForThisLaunch() {
        isInSafeMode = false
        consecutiveCrashCount = 0
        defaults.set(0, forKey: Keys.consecutiveCrashCount)
        defaults.set(false, forKey: Keys.lastExitWasClean)
        lastExitWasClean = false
    }
    /// Deletes persisted session data that can commonly become corrupt.
    public func resetSessionDataBestEffort() {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let journalRoot = documentsURL.appendingPathComponent("SessionJournal", isDirectory: true)
        if fileManager.fileExists(atPath: journalRoot.path) {
            try? fileManager.removeItem(at: journalRoot)
        }
        let prefixes = [
            "session_",          // BrowserCore session store
        ]
        if let items = try? fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil) {
            for url in items {
                let name = url.lastPathComponent
                guard name.hasSuffix(".json") else { continue }
                if prefixes.contains(where: { name.hasPrefix($0) }) {
                    try? fileManager.removeItem(at: url)
                }
            }
        }
        consecutiveCrashCount = 0
        defaults.set(0, forKey: Keys.consecutiveCrashCount)
    }
}
public struct CrashRecoveryView: View {
    @EnvironmentObject private var crashGuard: CrashGuard
    @State private var showingResetConfirm: Bool = false
    public init() {}
    public var body: some View {
        VStack(spacing: 14) {
            Text("Safe Mode")
                .font(.system(size: 28, weight: .bold))
            Text("The app detected repeated crashes during startup.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button("Open with Tabs (Safe Restore)") {
                    crashGuard.chooseOpenWithTabsSafeRestore()
                }
                .buttonStyle(.borderedProminent)
                Button("Open Blank") {
                    crashGuard.chooseOpenBlank()
                }
                .buttonStyle(.bordered)
                Button("Reset Session (Delete Corrupt Data)") {
                    showingResetConfirm = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.top, 8)
            if crashGuard.consecutiveCrashCount > 0 {
                Text("Crash count: \(crashGuard.consecutiveCrashCount)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .alert("Reset session data?", isPresented: $showingResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                crashGuard.resetSessionDataBestEffort()
                crashGuard.chooseOpenBlank()
            }
        } message: {
            Text("This will delete saved tabs/windows state and may remove corrupted session snapshots.")
        }
    }
}
