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
        case .stopped: "Stopped"
        case .starting: "Starting"
        case .running: "Running"
        case .stopping: "Stopping"
        case .failed: "Needs attention"
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
        case .running, .starting: true
        case .stopped, .stopping, .failed: false
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
    }

    func start(config: ServerConfig) {
        guard status.canStart else { return }
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
                        self.status = .failed("The service started but did not become ready in time.")
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
            }
        }
    }

    func stopForAppTermination() {
        pendingRestartConfig = nil
        guard let process, process.isRunning else { return }
        logStore.append("Stopping DS4 service because DS4Mac is quitting.")
        process.terminate()
    }

    func restart(config: ServerConfig) {
        guard process != nil else {
            start(config: config)
            return
        }
        pendingRestartConfig = config
        stop()
    }

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
        process = nil
        if case .stopping = status {
            status = .stopped
            logStore.append("DS4 service stopped.")
        } else {
            let code = terminatedProcess.terminationStatus
            let reason = terminationDescription(for: terminatedProcess)
            status = code == 0 ? .stopped : .failed("The service \(reason) with code \(code). See ds4-server.log for details.")
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

    private func cleanupPipes() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        errorPipe = nil
    }
}
