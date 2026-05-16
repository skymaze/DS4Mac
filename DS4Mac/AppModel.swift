import AppKit
import Combine
import Foundation

final class AppModel: ObservableObject {
    @Published var config: ServerConfig {
        didSet {
            AppPreferences.saveConfig(config)
        }
    }
    @Published private(set) var status: ServerStatus = .stopped

    let logStore: LogStore
    let processManager: ServerProcessManager

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let logs = LogStore()
        self.config = AppPreferences.loadConfig()
        self.logStore = logs
        self.processManager = ServerProcessManager(logStore: logs)

        processManager.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.status = status
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

    func revealLogsFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([AppDirectories.logs])
    }

    func quit() {
        processManager.stopForAppTermination()
        NSApplication.shared.terminate(nil)
    }
}
