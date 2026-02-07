import SwiftUI
import UIKit
import SafariLikeCoreKit
import SafariLikeContracts
struct DownloadsPopoverView: View {
    @ObservedObject var chrome: BrowserChromeState
    @State private var previewFile: DownloadFile? = nil
    init(chrome: BrowserChromeState) {
        self.chrome = chrome
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Downloads")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button {
                    chrome.isDownloadsPresented = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            if let msg = chrome.downloads.lastErrorMessage {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !chrome.downloads.activeDownloads.isEmpty {
                ActiveDownloadsSection(downloads: chrome.downloads)
            }
            if chrome.downloads.files.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("No downloads yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 30)
            } else {
                List {
                    ForEach(chrome.downloads.files) { f in
                        Button {
                            previewFile = f
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(f.name)
                                    .lineLimit(1)
                                HStack(spacing: 10) {
                                    Text(f.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                                    Text(byteCountString(f.sizeBytes))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .contextMenu {
                            Button("Preview") {
                                previewFile = f
                            }
                            Button("Share…") {
                                chrome.shareDownloadFile(f)
                            }
                            Button("Open in Files") {
                                UIApplication.shared.open(f.url)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minWidth: 360, minHeight: 360)
        .onAppear {
            self.chrome.downloads.refresh()
        }
        .sheet(item: $previewFile) { file in
            QuickLookPreview(url: file.url)
        }
        .modifier(DetentsIfAvailable())
    }
    private func byteCountString(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }
}
private struct DetentsIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}
private struct ActiveDownloadsSection: View {
    let downloads: any DownloadProviding
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("In Progress")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(downloads.activeDownloads) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.filename)
                            .lineLimit(1)
                        Spacer()
                        Text(statusLabel(item.status))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if item.status == .failed, let msg = item.errorMessage, !msg.isEmpty {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    ProgressView(value: item.progress)
                    HStack(spacing: 12) {
                        if item.status == .failed {
                            Button("Retry") { downloads.resumeDownload(id: item.id) }
                        } else if item.status == .paused {
                            Button("Resume") { downloads.resumeDownload(id: item.id) }
                        } else if item.status == .downloading {
                            Button("Pause") { downloads.pauseDownload(id: item.id) }
                        }
                        Button("Cancel", role: .destructive) {
                            downloads.cancelDownload(id: item.id)
                        }
                        Spacer()
                        Text(percentString(item.progress))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
    private func percentString(_ progress: Double) -> String {
        let pct = max(0, min(1, progress)) * 100
        return String(format: "%.0f%%", pct)
    }
    private func statusLabel(_ status: DownloadStatus) -> String {
        switch status {
        case .queued: return "Queued"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .finished: return "Finished"
        case .failed: return "Failed"
        case .canceled: return "Canceled"
        @unknown default: return "Unknown"
        }
    }
}
