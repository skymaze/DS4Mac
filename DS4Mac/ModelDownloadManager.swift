import Combine
import Foundation

enum ModelFileStatus {
    case notDownloaded
    case downloading(progress: Double, downloadedBytes: Int64, expectedBytes: Int64)
    case completed
    case failed(String)

}

@MainActor
final class ModelDownloadManager: NSObject, ObservableObject {
    @Published var activeDownloads: [String: ActiveDownload] = [:]

    struct ActiveDownload {
        var downloadedBytes: Int64
        var expectedBytes: Int64
    }

    var modelDirectory: URL {
        AppDirectories.models
    }

    var mainModelDirectory: URL {
        AppDirectories.mainModels
    }

    var mtpModelDirectory: URL {
        AppDirectories.mtpModels
    }

    private var urlSession: URLSession!
    private var tasks: [String: URLSessionDataTask] = [:]
    private var fileHandles: [String: FileHandle] = [:]

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = false
        config.timeoutIntervalForResource = 86400
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - File paths

    func destinationURL(for model: ModelInfo) -> URL {
        let base = model.isMTP ? AppDirectories.mtpModels : AppDirectories.mainModels
        return base
            .appendingPathComponent(model.repo, isDirectory: true)
            .appendingPathComponent(model.filename)
    }

    func partURL(for model: ModelInfo) -> URL {
        var url = destinationURL(for: model)
        url.appendPathExtension("part")
        return url
    }

    // MARK: - Status

    func status(for model: ModelInfo) -> ModelFileStatus {
        if let active = activeDownloads[model.key] {
            let progress = active.expectedBytes > 0
                ? min(Double(active.downloadedBytes) / Double(active.expectedBytes), 1)
                : 0
            return .downloading(progress: progress, downloadedBytes: active.downloadedBytes, expectedBytes: active.expectedBytes)
        }

        let dest = destinationURL(for: model)
        if FileManager.default.fileExists(atPath: dest.path) {
            let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0
            if size >= model.expectedBytes / 2 {
                return .completed
            }
        }

        let part = partURL(for: model)
        if FileManager.default.fileExists(atPath: part.path) {
            _ = try? FileManager.default.removeItem(at: part)
        }

        return .notDownloaded
    }

    func completedModel(for key: String) -> URL? {
        guard let model = ModelCatalog.recommended.first(where: { $0.key == key }) else { return nil }
        let dest = destinationURL(for: model)
        guard FileManager.default.fileExists(atPath: dest.path) else { return nil }
        let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0
        guard size >= model.expectedBytes / 2 else { return nil }
        return dest
    }

    // MARK: - Download actions

    func startDownload(for model: ModelInfo) {
        guard activeDownloads[model.key] == nil else { return }

        let dest = destinationURL(for: model)
        if FileManager.default.fileExists(atPath: dest.path) {
            let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0
            if size >= model.expectedBytes / 2 {
                return
            }
        }

        let part = partURL(for: model)
        try? FileManager.default.createDirectory(at: part.deletingLastPathComponent(), withIntermediateDirectories: true)

        let existingBytes: Int64
        if FileManager.default.fileExists(atPath: part.path) {
            existingBytes = (try? FileManager.default.attributesOfItem(atPath: part.path)[.size] as? Int64) ?? 0
        } else {
            FileManager.default.createFile(atPath: part.path, contents: nil)
            existingBytes = 0
        }

        var request = URLRequest(url: model.url)
        if existingBytes > 0 {
            request.setValue("bytes=\(existingBytes)-", forHTTPHeaderField: "Range")
        }

        activeDownloads[model.key] = ActiveDownload(
            downloadedBytes: existingBytes,
            expectedBytes: model.expectedBytes
        )

        let task = urlSession.dataTask(with: request)
        tasks[model.key] = task
        task.resume()
    }

    func cancelDownload(modelKey: String) {
        tasks[modelKey]?.cancel()
        tasks[modelKey] = nil
        closeHandle(for: modelKey)
        activeDownloads[modelKey] = nil

        if let model = ModelCatalog.recommended.first(where: { $0.key == modelKey }) {
            try? FileManager.default.removeItem(at: partURL(for: model))
        }
    }

    // MARK: - File handle management

    private func handle(for modelKey: String) -> FileHandle? {
        if let existing = fileHandles[modelKey] {
            return existing
        }
        guard let model = ModelCatalog.recommended.first(where: { $0.key == modelKey }) else { return nil }
        let part = partURL(for: model)
        guard let handle = try? FileHandle(forWritingTo: part) else { return nil }
        _ = try? handle.seekToEnd()
        fileHandles[modelKey] = handle
        return handle
    }

    private func closeHandle(for modelKey: String) {
        try? fileHandles[modelKey]?.close()
        fileHandles[modelKey] = nil
    }
}

// MARK: - URLSessionDataDelegate

extension ModelDownloadManager: URLSessionDataDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        completionHandler(.allow)
    }

    nonisolated func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        Task { @MainActor in
            guard let modelKey = tasks.first(where: { $0.value == dataTask })?.key,
                  var active = activeDownloads[modelKey],
                  let handle = handle(for: modelKey) else { return }

            try? handle.write(contentsOf: data)
            active.downloadedBytes += Int64(data.count)
            activeDownloads[modelKey] = active
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        Task { @MainActor in
            guard let modelKey = tasks.first(where: { $0.value == task })?.key else { return }
            tasks[modelKey] = nil
            closeHandle(for: modelKey)

            guard let model = ModelCatalog.recommended.first(where: { $0.key == modelKey }) else { return }

            if let error {
                let nsError = error as NSError
                let isCancelled = nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
                if !isCancelled {
                    activeDownloads[modelKey] = nil
                }
                return
            }

            let dest = destinationURL(for: model)
            let part = partURL(for: model)
            try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            _ = try? FileManager.default.replaceItemAt(dest, withItemAt: part)
            activeDownloads[modelKey] = nil
        }
    }
}
