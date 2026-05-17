import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

final class AppModel: ObservableObject {
    @Published var config: ServerConfig {
        didSet {
            AppPreferences.saveConfig(config)
        }
    }
    @Published private(set) var status: ServerStatus = .stopped
    @Published private(set) var kvCacheUsedBytes: Int64 = 0
    @Published private(set) var isRefreshingKVCacheUsage = false
    @Published private(set) var kvCacheStorageError: String?

    let logStore: LogStore
    let processManager: ServerProcessManager
    let modelDownloadManager: ModelDownloadManager

    private var cancellables: Set<AnyCancellable> = []
    private var kvCacheTask: Task<Void, Never>?

    init() {
        let logs = LogStore()
        self.config = AppPreferences.loadConfig()
        self.logStore = logs
        self.processManager = ServerProcessManager(logStore: logs)
        self.modelDownloadManager = ModelDownloadManager()

        processManager.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.status = status
            }
            .store(in: &cancellables)

        modelDownloadManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.processManager.stopForAppTermination()
            }
            .store(in: &cancellables)
    }

    func start() {
        processManager.start(config: config)
    }

    func stop() {
        processManager.stop()
    }

    func restart() {
        processManager.restart(config: config)
    }

    func copyServiceAddress() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(config.localAPIBaseAddress, forType: .string)
    }

    var canStartService: Bool {
        status.canStart && !processManager.isServiceProcessRunning
    }

    var canStopService: Bool {
        status.canStop || processManager.isServiceProcessRunning
    }

    var canClearKVCache: Bool {
        !processManager.isServiceProcessRunning
    }

    var kvCacheUsageFraction: Double? {
        let limit = Int64(config.kvDiskSpaceMB) * 1024 * 1024
        guard limit > 0 else { return nil }
        return min(Double(kvCacheUsedBytes) / Double(limit), 1)
    }

    var kvCacheUsageText: String {
        if isRefreshingKVCacheUsage {
            return String(localized: "Calculating...")
        }
        let used = Self.byteFormatter.string(fromByteCount: kvCacheUsedBytes)
        let limit = Self.byteFormatter.string(fromByteCount: Int64(config.kvDiskSpaceMB) * 1024 * 1024)
        return String(format: String(localized: "%@ used of %@"), used, limit)
    }

    func refreshKVCacheUsage() {
        kvCacheTask?.cancel()
        let directory = URL(fileURLWithPath: config.kvCacheDirectory, isDirectory: true)
        isRefreshingKVCacheUsage = true
        kvCacheStorageError = nil

        kvCacheTask = Task {
            let result = await Task.detached(priority: .utility) {
                Result {
                    try DirectoryStorage.sizeOfDirectory(at: directory)
                }
            }.value

            guard !Task.isCancelled else { return }

            switch result {
            case .success(let bytes):
                kvCacheUsedBytes = bytes
                kvCacheStorageError = nil
            case .failure(let error):
                kvCacheStorageError = error.localizedDescription
            }
            isRefreshingKVCacheUsage = false
        }
    }

    func clearKVCache() {
        guard canClearKVCache else {
            kvCacheStorageError = String(localized: "Stop the service before clearing the KV cache.")
            return
        }

        kvCacheTask?.cancel()
        let directory = URL(fileURLWithPath: config.kvCacheDirectory, isDirectory: true)
        isRefreshingKVCacheUsage = true
        kvCacheStorageError = nil

        kvCacheTask = Task {
            let result = await Task.detached(priority: .utility) {
                Result {
                    try DirectoryStorage.removeContents(of: directory)
                    return try DirectoryStorage.sizeOfDirectory(at: directory)
                }
            }.value

            guard !Task.isCancelled else { return }

            switch result {
            case .success(let bytes):
                kvCacheUsedBytes = bytes
                kvCacheStorageError = nil
                logStore.append("KV cache cleared.")
            case .failure(let error):
                kvCacheStorageError = error.localizedDescription
                logStore.append("Failed to clear KV cache: \(error.localizedDescription)")
            }
            isRefreshingKVCacheUsage = false
        }
    }

    func resetConfig() {
        config = ServerConfig.defaults()
    }

    func saveConfigToFile() {
        let panel = NSSavePanel()
        panel.title = String(localized: "Save Configuration")
        panel.nameFieldStringValue = "DS4Mac-config.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: url)
    }

    func loadConfigFromFile() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Load Configuration")
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode(ServerConfig.self, from: data) else { return }
        config = loaded
    }

    func revealLogsFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([AppDirectories.logs])
    }

    func quit() {
        processManager.stopForAppTermination()
        NSApplication.shared.terminate(nil)
    }

    func revealModelsFolder() {
        NSWorkspace.shared.activateFileViewerSelecting(
            [modelDownloadManager.modelDirectory]
        )
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter
    }()
}
