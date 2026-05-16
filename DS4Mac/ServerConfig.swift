import Foundation

enum ServerBackend: String, CaseIterable, Codable, Identifiable {
    case automatic
    case metal
    case cuda
    case cpu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Default"
        case .metal: "metal"
        case .cuda: "cuda"
        case .cpu: "cpu"
        }
    }

    var argumentValue: String? {
        switch self {
        case .automatic: nil
        case .metal, .cuda, .cpu: rawValue
        }
    }
}

enum ServerEngine: String, CaseIterable, Codable, Identifiable {
    case automatic
    case bundledMetal
    case bundledMetalM4
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: String(localized: "Automatic")
        case .bundledMetal: String(localized: "Metal (bundled)")
        case .bundledMetalM4: String(localized: "Metal M4+ (bundled)")
        case .custom: String(localized: "Custom...")
        }
    }
}

struct ServerConfig: Codable, Equatable {
    static let defaultContextTokens = 100_000
    static let defaultOutputTokens = 393_216
    static let defaultKVDiskDirectory = "/tmp/ds4-kv"
    static let defaultKVDiskSpaceMB = 8_192
    static let defaultKVCacheMinTokens = 512
    static let defaultKVCacheColdMaxTokens = 30_000
    static let defaultKVCacheContinuedIntervalTokens = 10_000
    static let defaultKVCacheBoundaryTrimTokens = 32
    static let defaultKVCacheBoundaryAlignTokens = 2_048
    static let defaultToolMemoryMaxIds = 100_000

    var customServerPath: String?
    var serverEngine: ServerEngine
    var modelPath: String?
    var mtpPath: String?
    var backend: ServerBackend
    var bindHost: String
    var port: Int
    var ctxTokens: Int
    var defaultOutputTokens: Int
    var cpuThreads: Int
    var mtpDraftTokens: Int
    var mtpMargin: Double
    var kvCacheEnabled: Bool
    var kvCacheDirectory: String
    var kvDiskSpaceMB: Int
    var kvCacheMinTokens: Int
    var kvCacheColdMaxTokens: Int
    var kvCacheContinuedIntervalTokens: Int
    var kvCacheBoundaryTrimTokens: Int
    var kvCacheBoundaryAlignTokens: Int
    var kvCacheRejectDifferentQuant: Bool
    var disableExactDSMLToolReplay: Bool
    var toolMemoryMaxIds: Int
    var warmWeights: Bool
    var qualityMode: Bool
    var browserClientsEnabled: Bool
    var diagnosticsEnabled: Bool
    var diagnosticsFilePath: String

    static func defaults() -> ServerConfig {
        ServerConfig(
            customServerPath: nil,
            serverEngine: .automatic,
            modelPath: nil,
            mtpPath: nil,
            backend: .automatic,
            bindHost: "127.0.0.1",
            port: 8000,
            ctxTokens: Self.defaultContextTokens,
            defaultOutputTokens: Self.defaultOutputTokens,
            cpuThreads: 0,
            mtpDraftTokens: 1,
            mtpMargin: 3,
            kvCacheEnabled: true,
            kvCacheDirectory: Self.defaultKVDiskDirectory,
            kvDiskSpaceMB: Self.defaultKVDiskSpaceMB,
            kvCacheMinTokens: Self.defaultKVCacheMinTokens,
            kvCacheColdMaxTokens: Self.defaultKVCacheColdMaxTokens,
            kvCacheContinuedIntervalTokens: Self.defaultKVCacheContinuedIntervalTokens,
            kvCacheBoundaryTrimTokens: Self.defaultKVCacheBoundaryTrimTokens,
            kvCacheBoundaryAlignTokens: Self.defaultKVCacheBoundaryAlignTokens,
            kvCacheRejectDifferentQuant: false,
            disableExactDSMLToolReplay: false,
            toolMemoryMaxIds: Self.defaultToolMemoryMaxIds,
            warmWeights: false,
            qualityMode: false,
            browserClientsEnabled: false,
            diagnosticsEnabled: false,
            diagnosticsFilePath: AppDirectories.logs.appendingPathComponent("ds4-trace.txt").path
        )
    }

    init(
        customServerPath: String?,
        serverEngine: ServerEngine,
        modelPath: String?,
        mtpPath: String?,
        backend: ServerBackend,
        bindHost: String,
        port: Int,
        ctxTokens: Int,
        defaultOutputTokens: Int,
        cpuThreads: Int,
        mtpDraftTokens: Int,
        mtpMargin: Double,
        kvCacheEnabled: Bool,
        kvCacheDirectory: String,
        kvDiskSpaceMB: Int,
        kvCacheMinTokens: Int,
        kvCacheColdMaxTokens: Int,
        kvCacheContinuedIntervalTokens: Int,
        kvCacheBoundaryTrimTokens: Int,
        kvCacheBoundaryAlignTokens: Int,
        kvCacheRejectDifferentQuant: Bool,
        disableExactDSMLToolReplay: Bool,
        toolMemoryMaxIds: Int,
        warmWeights: Bool,
        qualityMode: Bool,
        browserClientsEnabled: Bool,
        diagnosticsEnabled: Bool,
        diagnosticsFilePath: String
    ) {
        self.customServerPath = customServerPath
        self.serverEngine = serverEngine
        self.modelPath = modelPath
        self.mtpPath = mtpPath
        self.backend = backend
        self.bindHost = bindHost
        self.port = port
        self.ctxTokens = ctxTokens
        self.defaultOutputTokens = defaultOutputTokens
        self.cpuThreads = cpuThreads
        self.mtpDraftTokens = mtpDraftTokens
        self.mtpMargin = mtpMargin
        self.kvCacheEnabled = kvCacheEnabled
        self.kvCacheDirectory = kvCacheDirectory
        self.kvDiskSpaceMB = kvDiskSpaceMB
        self.kvCacheMinTokens = kvCacheMinTokens
        self.kvCacheColdMaxTokens = kvCacheColdMaxTokens
        self.kvCacheContinuedIntervalTokens = kvCacheContinuedIntervalTokens
        self.kvCacheBoundaryTrimTokens = kvCacheBoundaryTrimTokens
        self.kvCacheBoundaryAlignTokens = kvCacheBoundaryAlignTokens
        self.kvCacheRejectDifferentQuant = kvCacheRejectDifferentQuant
        self.disableExactDSMLToolReplay = disableExactDSMLToolReplay
        self.toolMemoryMaxIds = toolMemoryMaxIds
        self.warmWeights = warmWeights
        self.qualityMode = qualityMode
        self.browserClientsEnabled = browserClientsEnabled
        self.diagnosticsEnabled = diagnosticsEnabled
        self.diagnosticsFilePath = diagnosticsFilePath
    }

    init(from decoder: Decoder) throws {
        let defaults = Self.defaults()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        customServerPath = try container.decodeIfPresent(String.self, forKey: .customServerPath) ?? defaults.customServerPath

        if let engine = try container.decodeIfPresent(ServerEngine.self, forKey: .serverEngine) {
            serverEngine = engine
        } else if let path = customServerPath, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            serverEngine = .custom
        } else {
            serverEngine = .automatic
        }

        modelPath = try container.decodeIfPresent(String.self, forKey: .modelPath) ?? defaults.modelPath
        mtpPath = try container.decodeIfPresent(String.self, forKey: .mtpPath) ?? defaults.mtpPath
        backend = try container.decodeIfPresent(ServerBackend.self, forKey: .backend) ?? defaults.backend
        if let host = try container.decodeIfPresent(String.self, forKey: .bindHost) {
            bindHost = host
        } else if let legacyAccess = try container.decodeIfPresent(String.self, forKey: .hostAccess) {
            bindHost = legacyAccess == "localNetwork" ? "0.0.0.0" : "127.0.0.1"
        } else {
            bindHost = defaults.bindHost
        }
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? defaults.port

        if let legacyContext = try container.decodeIfPresent(Int.self, forKey: .contextPreset) {
            ctxTokens = Self.normalizedContextTokens(legacyContext)
        } else {
            ctxTokens = try container.decodeIfPresent(Int.self, forKey: .ctxTokens) ?? defaults.ctxTokens
        }

        defaultOutputTokens = try container.decodeIfPresent(Int.self, forKey: .defaultOutputTokens) ?? defaults.defaultOutputTokens
        cpuThreads = try container.decodeIfPresent(Int.self, forKey: .cpuThreads) ?? defaults.cpuThreads
        mtpDraftTokens = try container.decodeIfPresent(Int.self, forKey: .mtpDraftTokens) ?? defaults.mtpDraftTokens
        mtpMargin = try container.decodeIfPresent(Double.self, forKey: .mtpMargin) ?? defaults.mtpMargin
        kvCacheEnabled = try container.decodeIfPresent(Bool.self, forKey: .kvCacheEnabled) ?? defaults.kvCacheEnabled
        let decodedKVCacheDirectory = try container.decodeIfPresent(String.self, forKey: .kvCacheDirectory) ?? defaults.kvCacheDirectory
        kvCacheDirectory = Self.normalizedKVCacheDirectory(decodedKVCacheDirectory)

        if let legacyGB = try container.decodeIfPresent(Int.self, forKey: .kvCacheSizeGB) {
            kvDiskSpaceMB = max(legacyGB, 1) * 1024
        } else {
            kvDiskSpaceMB = try container.decodeIfPresent(Int.self, forKey: .kvDiskSpaceMB) ?? defaults.kvDiskSpaceMB
        }

        kvCacheMinTokens = try container.decodeIfPresent(Int.self, forKey: .kvCacheMinTokens) ?? defaults.kvCacheMinTokens
        kvCacheColdMaxTokens = try container.decodeIfPresent(Int.self, forKey: .kvCacheColdMaxTokens) ?? defaults.kvCacheColdMaxTokens
        kvCacheContinuedIntervalTokens = try container.decodeIfPresent(Int.self, forKey: .kvCacheContinuedIntervalTokens) ?? defaults.kvCacheContinuedIntervalTokens
        kvCacheBoundaryTrimTokens = try container.decodeIfPresent(Int.self, forKey: .kvCacheBoundaryTrimTokens) ?? defaults.kvCacheBoundaryTrimTokens
        kvCacheBoundaryAlignTokens = try container.decodeIfPresent(Int.self, forKey: .kvCacheBoundaryAlignTokens) ?? defaults.kvCacheBoundaryAlignTokens
        kvCacheRejectDifferentQuant = try container.decodeIfPresent(Bool.self, forKey: .kvCacheRejectDifferentQuant) ?? defaults.kvCacheRejectDifferentQuant
        disableExactDSMLToolReplay = try container.decodeIfPresent(Bool.self, forKey: .disableExactDSMLToolReplay) ?? defaults.disableExactDSMLToolReplay
        toolMemoryMaxIds = try container.decodeIfPresent(Int.self, forKey: .toolMemoryMaxIds) ?? defaults.toolMemoryMaxIds
        warmWeights = try container.decodeIfPresent(Bool.self, forKey: .warmWeights) ?? defaults.warmWeights
        qualityMode = try container.decodeIfPresent(Bool.self, forKey: .qualityMode) ?? defaults.qualityMode
        browserClientsEnabled = try container.decodeIfPresent(Bool.self, forKey: .browserClientsEnabled) ?? defaults.browserClientsEnabled
        diagnosticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .diagnosticsEnabled) ?? defaults.diagnosticsEnabled
        diagnosticsFilePath = try container.decodeIfPresent(String.self, forKey: .diagnosticsFilePath) ?? defaults.diagnosticsFilePath
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(customServerPath, forKey: .customServerPath)
        try container.encode(serverEngine, forKey: .serverEngine)
        try container.encodeIfPresent(modelPath, forKey: .modelPath)
        try container.encodeIfPresent(mtpPath, forKey: .mtpPath)
        try container.encode(backend, forKey: .backend)
        try container.encode(bindHost, forKey: .bindHost)
        try container.encode(port, forKey: .port)
        try container.encode(ctxTokens, forKey: .ctxTokens)
        try container.encode(defaultOutputTokens, forKey: .defaultOutputTokens)
        try container.encode(cpuThreads, forKey: .cpuThreads)
        try container.encode(mtpDraftTokens, forKey: .mtpDraftTokens)
        try container.encode(mtpMargin, forKey: .mtpMargin)
        try container.encode(kvCacheEnabled, forKey: .kvCacheEnabled)
        try container.encode(kvCacheDirectory, forKey: .kvCacheDirectory)
        try container.encode(kvDiskSpaceMB, forKey: .kvDiskSpaceMB)
        try container.encode(kvCacheMinTokens, forKey: .kvCacheMinTokens)
        try container.encode(kvCacheColdMaxTokens, forKey: .kvCacheColdMaxTokens)
        try container.encode(kvCacheContinuedIntervalTokens, forKey: .kvCacheContinuedIntervalTokens)
        try container.encode(kvCacheBoundaryTrimTokens, forKey: .kvCacheBoundaryTrimTokens)
        try container.encode(kvCacheBoundaryAlignTokens, forKey: .kvCacheBoundaryAlignTokens)
        try container.encode(kvCacheRejectDifferentQuant, forKey: .kvCacheRejectDifferentQuant)
        try container.encode(disableExactDSMLToolReplay, forKey: .disableExactDSMLToolReplay)
        try container.encode(toolMemoryMaxIds, forKey: .toolMemoryMaxIds)
        try container.encode(warmWeights, forKey: .warmWeights)
        try container.encode(qualityMode, forKey: .qualityMode)
        try container.encode(browserClientsEnabled, forKey: .browserClientsEnabled)
        try container.encode(diagnosticsEnabled, forKey: .diagnosticsEnabled)
        try container.encode(diagnosticsFilePath, forKey: .diagnosticsFilePath)
    }

    var localServiceRootURL: URL {
        URL(string: "http://127.0.0.1:\(port)")!
    }

    var localAPIBaseAddress: String {
        "http://127.0.0.1:\(port)/v1"
    }

    static func normalizedContextTokens(_ value: Int) -> Int {
        value == 32_768 ? defaultContextTokens : value
    }

    static func normalizedKVCacheDirectory(_ path: String) -> String {
        if path == defaultKVDiskDirectory {
            return path
        }
        if path.hasSuffix("/Application Support/DS4Mac/KVCache") {
            return defaultKVDiskDirectory
        }
        return path
    }

    private enum CodingKeys: String, CodingKey {
        case customServerPath
        case serverEngine
        case modelPath
        case mtpPath
        case backend
        case bindHost
        case hostAccess  // legacy
        case port
        case contextPreset
        case ctxTokens
        case defaultOutputTokens
        case cpuThreads
        case mtpDraftTokens
        case mtpMargin
        case kvCacheEnabled
        case kvCacheDirectory
        case kvCacheSizeGB
        case kvDiskSpaceMB
        case kvCacheMinTokens
        case kvCacheColdMaxTokens
        case kvCacheContinuedIntervalTokens
        case kvCacheBoundaryTrimTokens
        case kvCacheBoundaryAlignTokens
        case kvCacheRejectDifferentQuant
        case disableExactDSMLToolReplay
        case toolMemoryMaxIds
        case warmWeights
        case qualityMode
        case browserClientsEnabled
        case diagnosticsEnabled
        case diagnosticsFilePath
    }
}

enum AppDirectories {
    static var applicationSupport: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("DS4Mac", isDirectory: true)
    }

    static var mainModels: URL {
        applicationSupport.appendingPathComponent("Models/main", isDirectory: true)
    }

    static var mtpModels: URL {
        applicationSupport.appendingPathComponent("Models/mtp", isDirectory: true)
    }

    static var models: URL {
        applicationSupport.appendingPathComponent("Models", isDirectory: true)
    }

    static var logs: URL {
        let root = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("Logs/DS4Mac", isDirectory: true)
    }

    static func ensureCreated() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: applicationSupport, withIntermediateDirectories: true)
        try fm.createDirectory(at: mainModels, withIntermediateDirectories: true)
        try fm.createDirectory(at: mtpModels, withIntermediateDirectories: true)
        try fm.createDirectory(at: logs, withIntermediateDirectories: true)
    }
}
