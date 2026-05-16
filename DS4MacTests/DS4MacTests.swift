import Foundation
import Testing
@testable import DS4Mac

struct DS4MacTests {
    @Test @MainActor func commandUsesDs4ServerFlagNamesAndDefaults() throws {
        let modelURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ds4-test-model.gguf")
        _ = FileManager.default.createFile(atPath: modelURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: modelURL) }

        var config = ServerConfig.defaults()
        config.customServerPath = "/bin/echo"
        config.modelPath = modelURL.path

        let descriptor = try ServerCommandBuilder(bundledServerURL: { nil }).build(config: config)

        #expect(descriptor.environment["DS4_LOCK_FILE"]?.hasSuffix("/Application Support/DS4Mac/ds4.lock") == true)
        #expect(descriptor.arguments == [
            "--model", modelURL.path,
            "--ctx", "100000",
            "--tokens", "393216",
            "--host", "127.0.0.1",
            "--port", "8000",
            "--kv-disk-dir", "/tmp/ds4-kv",
            "--kv-disk-space-mb", "8192"
        ])
    }

    @Test @MainActor func commandIncludesChangedAdvancedFlags() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
        let modelURL = tempDirectory.appendingPathComponent("ds4-test-model.gguf")
        let mtpURL = tempDirectory.appendingPathComponent("ds4-test-mtp.gguf")
        _ = FileManager.default.createFile(atPath: modelURL.path, contents: Data())
        _ = FileManager.default.createFile(atPath: mtpURL.path, contents: Data())
        defer {
            try? FileManager.default.removeItem(at: modelURL)
            try? FileManager.default.removeItem(at: mtpURL)
        }

        var config = ServerConfig.defaults()
        config.customServerPath = "/bin/echo"
        config.modelPath = modelURL.path
        config.mtpPath = mtpURL.path
        config.backend = .metal
        config.cpuThreads = 4
        config.mtpDraftTokens = 2
        config.mtpMargin = 3.5
        config.browserClientsEnabled = true
        config.kvCacheMinTokens = 1024
        config.kvCacheRejectDifferentQuant = true
        config.disableExactDSMLToolReplay = true
        config.toolMemoryMaxIds = 200_000

        let descriptor = try ServerCommandBuilder(bundledServerURL: { nil }).build(config: config)
        let arguments = descriptor.arguments

        #expect(arguments.containsSubsequence(["--backend", "metal"]))
        #expect(arguments.containsSubsequence(["--threads", "4"]))
        #expect(arguments.containsSubsequence(["--mtp", mtpURL.path]))
        #expect(arguments.containsSubsequence(["--mtp-draft", "2"]))
        #expect(arguments.containsSubsequence(["--mtp-margin", "3.5"]))
        #expect(arguments.containsSubsequence(["--kv-cache-min-tokens", "1024"]))
        #expect(arguments.contains("--kv-cache-reject-different-quant"))
        #expect(arguments.contains("--disable-exact-dsml-tool-replay"))
        #expect(arguments.containsSubsequence(["--tool-memory-max-ids", "200000"]))
        #expect(arguments.contains("--cors"))
    }

    @Test @MainActor func legacyDefaultsMigrateToRecommendedServerDefaults() throws {
        let legacyJSON = """
        {
          "customServerPath": null,
          "modelPath": "/tmp/model.gguf",
          "hostAccess": "localOnly",
          "port": 8000,
          "contextPreset": 32768,
          "kvCacheEnabled": true,
          "kvCacheDirectory": "/Users/example/Library/Containers/cn.aixn.DS4Mac/Data/Library/Application Support/DS4Mac/KVCache",
          "kvDiskSpaceMB": 8192
        }
        """

        let config = try JSONDecoder().decode(ServerConfig.self, from: Data(legacyJSON.utf8))

        #expect(config.ctxTokens == 100_000)
        #expect(config.kvCacheDirectory == "/tmp/ds4-kv")
    }

    @Test func explicitContextTokensCanUseOriginalDefault() throws {
        let json = """
        {
          "ctxTokens": 32768,
          "kvCacheDirectory": "/tmp/ds4-kv"
        }
        """

        let config = try JSONDecoder().decode(ServerConfig.self, from: Data(json.utf8))

        #expect(config.ctxTokens == 32_768)
    }

    @Test @MainActor func clearTruncatesDiskLog() throws {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ds4-test-log-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: logURL) }

        let store = LogStore(fileURL: logURL)
        store.append("first line")

        #expect((try Data(contentsOf: logURL)).isEmpty == false)

        store.clear()

        #expect(store.text.isEmpty)
        #expect((try Data(contentsOf: logURL)).isEmpty)
    }
}

private extension Array where Element: Equatable {
    func containsSubsequence(_ candidate: [Element]) -> Bool {
        guard !candidate.isEmpty, candidate.count <= count else { return false }
        return indices.contains { index in
            let end = index + candidate.count
            guard end <= count else { return false }
            return Array(self[index..<end]) == candidate
        }
    }
}
