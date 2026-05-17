import Combine
import Darwin
import Foundation

enum ServerStatus: Equatable {
    case stopped
    case starting
    case running
    case stopping
    case failed(String)

    var title: String {
        switch self {
        case .stopped: String(localized: "Stopped")
        case .starting: String(localized: "Starting")
        case .running: String(localized: "Running")
        case .stopping: String(localized: "Stopping")
        case .failed: String(localized: "Needs attention")
        }
    }

    var systemImage: String {
        switch self {
        case .stopped: "circle"
        case .starting: "clock"
        case .running: "checkmark.circle.fill"
        case .stopping: "pause.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    var canStart: Bool {
        switch self {
        case .stopped, .failed: true
        case .starting, .running, .stopping: false
        }
    }

    var canStop: Bool {
        switch self {
        case .running, .starting, .failed: true
        case .stopped, .stopping: false
        }
    }
}

final class ServerProcessManager: ObservableObject {
    @Published private(set) var status: ServerStatus = .stopped

    private let logStore: LogStore
    private let commandBuilder: ServerCommandBuilder
    private let healthChecker: ServerHealthChecker
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var pendingRestartConfig: ServerConfig?

    init(
        logStore: LogStore,
        commandBuilder: ServerCommandBuilder? = nil,
        healthChecker: ServerHealthChecker = ServerHealthChecker()
    ) {
        self.logStore = logStore
        self.commandBuilder = commandBuilder ?? ServerCommandBuilder()
        self.healthChecker = healthChecker
        reapOrphanedProcesses()
    }

    var isServiceProcessRunning: Bool {
        process?.isRunning == true
    }

    // MARK: - Public API

    func start(config: ServerConfig) {
        guard status.canStart else { return }
        guard !isServiceProcessRunning else {
            status = .failed(String(localized: "Stop the current service process before starting a new one."))
            return
        }

        do {
            let descriptor = try commandBuilder.build(config: config)
            let launchedProcess = Process()
            let stdout = Pipe()
            let stderr = Pipe()

            launchedProcess.executableURL = descriptor.executableURL
            launchedProcess.currentDirectoryURL = descriptor.currentDirectoryURL
            launchedProcess.arguments = descriptor.arguments
            launchedProcess.standardOutput = stdout
            launchedProcess.standardError = stderr
            launchedProcess.environment = ProcessInfo.processInfo.environment.merging(descriptor.environment) { _, new in
                new
            }

            attach(pipe: stdout, label: "stdout")
            attach(pipe: stderr, label: "stderr")

            launchedProcess.terminationHandler = { [weak self] process in
                Task { @MainActor in
                    self?.handleTermination(process)
                }
            }

            status = .starting
            logStore.append("Starting DS4 service.")
            logStore.append("Command: \(descriptor.displayCommand)")
            if let currentDirectoryURL = descriptor.currentDirectoryURL {
                logStore.append("Working directory: \(currentDirectoryURL.path)")
            }
            for (name, value) in descriptor.environment.sorted(by: { $0.key < $1.key }) {
                logStore.append("Environment: \(name)=\(value)")
            }
            try launchedProcess.run()
            process = launchedProcess
            outputPipe = stdout
            errorPipe = stderr
            logStore.append("DS4 service process id: \(launchedProcess.processIdentifier)")

            Task {
                let ready = await healthChecker.waitUntilReady(rootURL: config.localServiceRootURL)
                await MainActor.run {
                    guard self.process?.processIdentifier == launchedProcess.processIdentifier else { return }
                    if ready {
                        self.status = .running
                        self.logStore.append("DS4 service is ready.")
                    } else if launchedProcess.isRunning {
                        self.status = .failed(String(localized: "The service started but did not become ready in time."))
                        self.logStore.append("Readiness check timed out for \(config.localServiceRootURL.absoluteString).")
                    }
                }
            }
        } catch {
            status = .failed(error.localizedDescription)
            logStore.append(error.localizedDescription)
        }
    }

    func stop() {
        guard let process else {
            status = .stopped
            return
        }
        guard process.isRunning else {
            cleanupPipes()
            self.process = nil
            status = .stopped
            return
        }

        status = .stopping
        logStore.append("Stopping DS4 service.")
        process.terminate()

        Task {
            try? await Task.sleep(for: .seconds(5))
            await MainActor.run {
                if process.isRunning {
                    _ = kill(process.processIdentifier, SIGKILL)
                    self.logStore.append("The service did not stop cleanly, so it was force stopped.")
                }
                self.removeLockFile()
            }
        }
    }

    func stopForAppTermination() {
        pendingRestartConfig = nil
        guard let process, process.isRunning else { return }
        logStore.append("Stopping DS4 service because DS4Mac is quitting.")
        process.terminate()
        // Block until the process exits, with a timeout to avoid hanging app termination.
        let deadline = DispatchTime.now() + .seconds(3)
        while process.isRunning && DispatchTime.now() < deadline {
            usleep(100_000)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
            usleep(200_000)
        }
        cleanupPipes()
        removeLockFile()
    }

    func restart(config: ServerConfig) {
        guard process != nil else {
            start(config: config)
            return
        }
        pendingRestartConfig = config
        stop()
    }

    // MARK: - Orphan reaping

    /// Kill any ds4-server processes left over from a previous session (crash, force quit, etc.).
    private func reapOrphanedProcesses() {
        guard let pids = ds4ServerPIDs(), !pids.isEmpty else { return }
        for pid in pids {
            logStore.append("Reaping orphaned ds4-server process (pid \(pid)).")
            kill(pid, SIGTERM)
        }
        usleep(500_000)
        for pid in pids {
            if kill(pid, 0) == 0 {
                kill(pid, SIGKILL)
            }
        }
        removeLockFile()
    }

    private func ds4ServerPIDs() -> [pid_t]? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "ds4-server"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !output.isEmpty else { return nil }
        return output.split(separator: "\n").compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }
    }

    // MARK: - Process lifecycle

    private func attach(pipe: Pipe, label: String) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let message = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.logStore.append("[\(label)] \(message)")
            }
        }
    }

    private func handleTermination(_ terminatedProcess: Process) {
        guard process?.processIdentifier == terminatedProcess.processIdentifier else { return }
        drainPipes()
        cleanupPipes()
        removeLockFile()
        process = nil
        if case .stopping = status {
            status = .stopped
            logStore.append("DS4 service stopped.")
        } else {
            let code = terminatedProcess.terminationStatus
            let reason = terminationDescription(for: terminatedProcess)
            status = code == 0 ? .stopped : .failed(
                String(
                    format: String(localized: "The service %@ with code %@. See ds4-server.log for details."),
                    reason,
                    String(code)
                )
            )
            logStore.append("DS4 service \(reason) with code \(code).")
        }
        if let config = pendingRestartConfig {
            pendingRestartConfig = nil
            start(config: config)
        }
    }

    private func terminationDescription(for process: Process) -> String {
        switch process.terminationReason {
        case .exit: "exited"
        case .uncaughtSignal: "was terminated by signal"
        @unknown default: "stopped"
        }
    }

    private func drainPipes() {
        drain(pipe: outputPipe, label: "stdout")
        drain(pipe: errorPipe, label: "stderr")
    }

    private func drain(pipe: Pipe?, label: String) {
        guard let data = pipe?.fileHandleForReading.availableData,
              !data.isEmpty,
              let message = String(data: data, encoding: .utf8)
        else {
            return
        }
        logStore.append("[\(label)] \(message)")
    }

    private func removeLockFile() {
        let path = AppDirectories.applicationSupport.appendingPathComponent("ds4.lock").path
        _ = try? FileManager.default.removeItem(atPath: path)
    }

    private func cleanupPipes() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        errorPipe = nil
    }
}
