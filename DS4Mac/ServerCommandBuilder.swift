import Foundation

struct ServerLaunchDescriptor: Equatable {
    let executableURL: URL
    let currentDirectoryURL: URL?
    let arguments: [String]
    let environment: [String: String]

    var displayCommand: String {
        ([executableURL.path] + arguments)
            .map(Self.shellQuoted)
            .joined(separator: " ")
    }

    nonisolated private static func shellQuoted(_ value: String) -> String {
        let safeCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/._-:=,+"))
        if value.rangeOfCharacter(from: safeCharacters.inverted) == nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum ServerLaunchError: LocalizedError, Equatable {
    case missingServiceEngine
    case serviceEngineNotFound(String)
    case missingModel
    case modelNotFound(String)
    case fileNotFound(flag: String, path: String)
    case invalidPort
    case invalidValue(flag: String, value: String)
    case storageUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingServiceEngine:
            String(localized: "The service engine is not bundled yet. Choose a ds4 service engine in Settings.")
        case .serviceEngineNotFound(let path):
            String(format: String(localized: "The selected service engine could not be found: %@"), path)
        case .missingModel:
            String(localized: "Choose a model file before starting the service.")
        case .modelNotFound(let path):
            String(format: String(localized: "The selected model file could not be found: %@"), path)
        case .fileNotFound(let flag, let path):
            String(format: String(localized: "The file configured for %@ could not be found: %@"), flag, path)
        case .invalidPort:
            String(localized: "Choose a network port between 1024 and 65535.")
        case .invalidValue(let flag, let value):
            String(format: String(localized: "The value for %@ is invalid: %@"), flag, value)
        case .storageUnavailable(let path):
            String(format: String(localized: "The storage folder could not be prepared: %@"), path)
        }
    }
}

@MainActor
struct ServerCommandBuilder {
    var bundledServerURL: (String) -> URL?

    init(bundledServerURL: ((String) -> URL?)? = nil) {
        self.bundledServerURL = bundledServerURL ?? Self.defaultBundledServerURL
    }

    func build(config: ServerConfig) throws -> ServerLaunchDescriptor {
        let executableURL = try resolveExecutableURL(config: config)
        let modelURL = try resolveModelURL(config: config)
        guard (1024...65535).contains(config.port) else {
            throw ServerLaunchError.invalidPort
        }
        try validatePositive(config.ctxTokens, flag: "--ctx")
        try validatePositive(config.defaultOutputTokens, flag: "--tokens")
        try validateNonNegative(config.cpuThreads, flag: "--threads")
        try validatePositive(config.mtpDraftTokens, flag: "--mtp-draft")
        try validatePositive(config.kvDiskSpaceMB, flag: "--kv-disk-space-mb")
        try validatePositive(config.kvCacheMinTokens, flag: "--kv-cache-min-tokens")
        try validateNonNegative(config.kvCacheColdMaxTokens, flag: "--kv-cache-cold-max-tokens")
        try validateNonNegative(config.kvCacheContinuedIntervalTokens, flag: "--kv-cache-continued-interval-tokens")
        try validateNonNegative(config.kvCacheBoundaryTrimTokens, flag: "--kv-cache-boundary-trim-tokens")
        try validateNonNegative(config.kvCacheBoundaryAlignTokens, flag: "--kv-cache-boundary-align-tokens")
        try validatePositive(config.toolMemoryMaxIds, flag: "--tool-memory-max-ids")
        guard config.mtpMargin >= 0 else {
            throw ServerLaunchError.invalidValue(flag: "--mtp-margin", value: String(config.mtpMargin))
        }
        if config.kvCacheColdMaxTokens > 0 && config.kvCacheColdMaxTokens < config.kvCacheMinTokens {
            throw ServerLaunchError.invalidValue(
                flag: "--kv-cache-cold-max-tokens",
                value: String(config.kvCacheColdMaxTokens)
            )
        }

        try prepareStorage(config: config)

        let chdir = config.customChdirPath
            ?? findDS4SourceDir(executableDir: executableURL.deletingLastPathComponent())
            ?? executableURL.deletingLastPathComponent().path
        var arguments = [
            "--chdir", chdir,
            "--model", modelURL.path,
            "--ctx", String(config.ctxTokens),
            "--tokens", String(config.defaultOutputTokens),
            "--host", config.bindHost,
            "--port", String(config.port)
        ]

        if let backend = config.backend.argumentValue {
            arguments += ["--backend", backend]
        }
        if config.cpuThreads > 0 {
            arguments += ["--threads", String(config.cpuThreads)]
        }
        if let mtpURL = try resolveOptionalFile(config.mtpPath, flag: "--mtp") {
            arguments += [
                "--mtp", mtpURL.path,
                "--mtp-draft", String(config.mtpDraftTokens),
                "--mtp-margin", String(config.mtpMargin)
            ]
        }
        if config.kvCacheEnabled {
            arguments += [
                "--kv-disk-dir", config.kvCacheDirectory,
                "--kv-disk-space-mb", String(config.kvDiskSpaceMB)
            ]
            if config.kvCacheMinTokens != ServerConfig.defaultKVCacheMinTokens {
                arguments += ["--kv-cache-min-tokens", String(config.kvCacheMinTokens)]
            }
            if config.kvCacheColdMaxTokens != ServerConfig.defaultKVCacheColdMaxTokens {
                arguments += ["--kv-cache-cold-max-tokens", String(config.kvCacheColdMaxTokens)]
            }
            if config.kvCacheContinuedIntervalTokens != ServerConfig.defaultKVCacheContinuedIntervalTokens {
                arguments += [
                    "--kv-cache-continued-interval-tokens",
                    String(config.kvCacheContinuedIntervalTokens)
                ]
            }
            if config.kvCacheBoundaryTrimTokens != ServerConfig.defaultKVCacheBoundaryTrimTokens {
                arguments += ["--kv-cache-boundary-trim-tokens", String(config.kvCacheBoundaryTrimTokens)]
            }
            if config.kvCacheBoundaryAlignTokens != ServerConfig.defaultKVCacheBoundaryAlignTokens {
                arguments += ["--kv-cache-boundary-align-tokens", String(config.kvCacheBoundaryAlignTokens)]
            }
            if config.kvCacheRejectDifferentQuant {
                arguments.append("--kv-cache-reject-different-quant")
            }
        }
        if config.disableExactDSMLToolReplay {
            arguments.append("--disable-exact-dsml-tool-replay")
        }
        if config.toolMemoryMaxIds != ServerConfig.defaultToolMemoryMaxIds {
            arguments += ["--tool-memory-max-ids", String(config.toolMemoryMaxIds)]
        }
        if config.warmWeights {
            arguments.append("--warm-weights")
        }
        if config.qualityMode {
            arguments.append("--quality")
        }
        if config.browserClientsEnabled {
            arguments.append("--cors")
        }
        if config.diagnosticsEnabled {
            arguments += ["--trace", config.diagnosticsFilePath]
        }

        return ServerLaunchDescriptor(
            executableURL: executableURL,
            currentDirectoryURL: URL(fileURLWithPath: chdir, isDirectory: true),
            arguments: arguments,
            environment: sidecarEnvironment()
        )
    }

    private func resolveExecutableURL(config: ServerConfig) throws -> URL {
        switch config.serverEngine {
        case .custom:
            guard let path = config.customServerPath?.nilIfEmpty else {
                throw ServerLaunchError.missingServiceEngine
            }
            guard FileManager.default.fileExists(atPath: path) else {
                throw ServerLaunchError.serviceEngineNotFound(path)
            }
            return URL(fileURLWithPath: path)

        case .automatic:
            let name = HardwareDetector.supportsSME ? "ds4-server-m4" : "ds4-server"
            if let url = bundledServerURL(name), FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            if name != "ds4-server", let url = bundledServerURL("ds4-server"), FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            throw ServerLaunchError.missingServiceEngine

        case .bundledMetal:
            if let url = bundledServerURL("ds4-server"), FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            throw ServerLaunchError.missingServiceEngine

        case .bundledMetalM4:
            if let url = bundledServerURL("ds4-server-m4"), FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            if let url = bundledServerURL("ds4-server"), FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            throw ServerLaunchError.missingServiceEngine
        }
    }

    private func resolveModelURL(config: ServerConfig) throws -> URL {
        guard let path = config.modelPath?.nilIfEmpty else {
            throw ServerLaunchError.missingModel
        }
        guard FileManager.default.fileExists(atPath: path) else {
            throw ServerLaunchError.modelNotFound(path)
        }
        return URL(fileURLWithPath: path)
    }

    private func resolveOptionalFile(_ path: String?, flag: String) throws -> URL? {
        guard let path = path?.nilIfEmpty else { return nil }
        guard FileManager.default.fileExists(atPath: path) else {
            throw ServerLaunchError.fileNotFound(flag: flag, path: path)
        }
        return URL(fileURLWithPath: path)
    }

    private func prepareStorage(config: ServerConfig) throws {
        do {
            try AppDirectories.ensureCreated()
            if config.kvCacheEnabled {
                guard let kvCacheDirectory = config.kvCacheDirectory.nilIfEmpty else {
                    throw ServerLaunchError.invalidValue(flag: "--kv-disk-dir", value: config.kvCacheDirectory)
                }
                try FileManager.default.createDirectory(
                    at: URL(fileURLWithPath: kvCacheDirectory, isDirectory: true),
                    withIntermediateDirectories: true
                )
            }
            if config.diagnosticsEnabled {
                let diagnosticsURL = URL(fileURLWithPath: config.diagnosticsFilePath)
                try FileManager.default.createDirectory(
                    at: diagnosticsURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
            }
        } catch let error as ServerLaunchError {
            throw error
        } catch {
            throw ServerLaunchError.storageUnavailable(config.kvCacheDirectory)
        }
    }

    private func validatePositive(_ value: Int, flag: String) throws {
        guard value > 0 else {
            throw ServerLaunchError.invalidValue(flag: flag, value: String(value))
        }
    }

    private func validateNonNegative(_ value: Int, flag: String) throws {
        guard value >= 0 else {
            throw ServerLaunchError.invalidValue(flag: flag, value: String(value))
        }
    }

    private func findDS4SourceDir(executableDir: URL) -> String? {
        if FileManager.default.fileExists(atPath: executableDir.appendingPathComponent("metal").path) {
            return executableDir.path
        }
        #if DEBUG
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let vendored = repoRoot.appendingPathComponent("Vendor/ds4")
        if FileManager.default.fileExists(atPath: vendored.appendingPathComponent("metal").path) {
            return vendored.path
        }
        let sibling = repoRoot
            .deletingLastPathComponent()
            .appendingPathComponent("ds4")
        if FileManager.default.fileExists(atPath: sibling.appendingPathComponent("metal").path) {
            return sibling.path
        }
        #endif
        return nil
    }

    private func sidecarEnvironment() -> [String: String] {
        [
            "DS4_LOCK_FILE": AppDirectories.applicationSupport
                .appendingPathComponent("ds4.lock")
                .path
        ]
    }

    static func defaultBundledServerURL(name: String) -> URL? {
        if let url = Bundle.main.url(forAuxiliaryExecutable: name) {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: nil) {
            return url
        }
        #if DEBUG
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let vendored = repoRoot.appendingPathComponent("Vendor/ds4/\(name)")
        if FileManager.default.fileExists(atPath: vendored.path) {
            return vendored
        }
        let sibling = repoRoot
            .deletingLastPathComponent()
            .appendingPathComponent("ds4/\(name)")
        if FileManager.default.fileExists(atPath: sibling.path) {
            return sibling
        }
        #endif
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
