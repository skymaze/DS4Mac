import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView {
            serviceTab
                .tabItem {
                    Label("Service", systemImage: "server.rack")
                }
            runtimeTab
                .tabItem {
                    Label("Runtime", systemImage: "speedometer")
                }
            storageTab
                .tabItem {
                    Label("KV Cache", systemImage: "externaldrive")
                }
            logsTab
                .tabItem {
                    Label("Logs", systemImage: "doc.text")
                }
        }
        .frame(width: 660, height: 560)
        .padding(20)
    }

    private var serviceTab: some View {
        Form {
            Section("Service Engine") {
                LabeledContent("Engine") {
                    HStack {
                        Text(engineDescription)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Choose...") {
                            chooseServiceEngine()
                        }
                    }
                }
            }

            Section("Model") {
                pathRow("--model", path: appModel.config.modelPath, emptyText: "No model selected") {
                    chooseModel()
                }
                pathRow("--mtp", path: appModel.config.mtpPath, emptyText: "Not set") {
                    chooseMTPModel()
                }
                LabeledContent("--mtp-draft") {
                    Stepper(value: $appModel.config.mtpDraftTokens, in: 1...16, step: 1) {
                        Text("\(appModel.config.mtpDraftTokens)")
                            .monospacedDigit()
                    }
                    .frame(width: 140)
                }
                LabeledContent("--mtp-margin") {
                    doubleField(value: $appModel.config.mtpMargin, placeholder: "3")
                }
            }

            Section("HTTP API") {
                Picker("--host", selection: $appModel.config.hostAccess) {
                    ForEach(HostAccess.allCases) { access in
                        Text(access.title).tag(access)
                    }
                }
                LabeledContent("--port") {
                    integerField(value: $appModel.config.port, placeholder: "8000")
                }
                Toggle("--cors", isOn: $appModel.config.browserClientsEnabled)
            }
        }
    }

    private var runtimeTab: some View {
        Form {
            Section("Model and Runtime") {
                LabeledContent("--ctx") {
                    integerField(value: $appModel.config.ctxTokens, placeholder: "100000")
                }
                LabeledContent("--tokens") {
                    integerField(value: $appModel.config.defaultOutputTokens, placeholder: "393216")
                }
                LabeledContent("--threads") {
                    integerField(value: $appModel.config.cpuThreads, placeholder: "0")
                }
                Picker("--backend", selection: $appModel.config.backend) {
                    ForEach(ServerBackend.allCases) { backend in
                        Text(backend.title).tag(backend)
                    }
                }
                Toggle("--warm-weights", isOn: $appModel.config.warmWeights)
                Toggle("--quality", isOn: $appModel.config.qualityMode)
            }
        }
    }

    private var storageTab: some View {
        Form {
            Section("Disk KV Cache") {
                Toggle("--kv-disk-dir", isOn: $appModel.config.kvCacheEnabled)
                pathRow("", path: appModel.config.kvCacheDirectory, emptyText: ServerConfig.defaultKVDiskDirectory) {
                    chooseKVCacheFolder()
                }
                LabeledContent("--kv-disk-space-mb") {
                    integerField(value: $appModel.config.kvDiskSpaceMB, placeholder: "8192")
                }
            }

            Section("KV Cache Options") {
                LabeledContent("--kv-cache-min-tokens") {
                    integerField(value: $appModel.config.kvCacheMinTokens, placeholder: "512")
                }
                LabeledContent("--kv-cache-cold-max-tokens") {
                    integerField(value: $appModel.config.kvCacheColdMaxTokens, placeholder: "30000")
                }
                LabeledContent("--kv-cache-continued-interval-tokens") {
                    integerField(value: $appModel.config.kvCacheContinuedIntervalTokens, placeholder: "10000")
                }
                LabeledContent("--kv-cache-boundary-trim-tokens") {
                    integerField(value: $appModel.config.kvCacheBoundaryTrimTokens, placeholder: "32")
                }
                LabeledContent("--kv-cache-boundary-align-tokens") {
                    integerField(value: $appModel.config.kvCacheBoundaryAlignTokens, placeholder: "2048")
                }
                Toggle("--kv-cache-reject-different-quant", isOn: $appModel.config.kvCacheRejectDifferentQuant)
                Toggle("--disable-exact-dsml-tool-replay", isOn: $appModel.config.disableExactDSMLToolReplay)
                LabeledContent("--tool-memory-max-ids") {
                    integerField(value: $appModel.config.toolMemoryMaxIds, placeholder: "100000")
                }
            }

            Section("Trace") {
                Toggle("--trace", isOn: $appModel.config.diagnosticsEnabled)
                pathRow("", path: appModel.config.diagnosticsFilePath, emptyText: "ds4-trace.txt") {
                    chooseDiagnosticsFile()
                }
            }
        }
    }

    private var logsTab: some View {
        LogsPane(logStore: appModel.logStore) {
            appModel.revealLogsFolder()
        }
    }

    private var engineDescription: String {
        if let custom = pathSummary(appModel.config.customServerPath) {
            return custom
        }
        if ServerCommandBuilder.defaultBundledServerURL() != nil {
            return "Bundled engine"
        }
        return "No bundled engine found"
    }

    private func chooseServiceEngine() {
        guard let url = openFile(allowedExtensions: nil) else { return }
        appModel.config.customServerPath = url.path
    }

    private func chooseModel() {
        guard let url = openFile(allowedExtensions: ["gguf"]) else { return }
        appModel.config.modelPath = url.path
    }

    private func chooseMTPModel() {
        guard let url = openFile(allowedExtensions: ["gguf"]) else { return }
        appModel.config.mtpPath = url.path
    }

    private func chooseKVCacheFolder() {
        guard let url = openDirectory() else { return }
        appModel.config.kvCacheDirectory = url.path
    }

    private func chooseDiagnosticsFile() {
        let panel = NSSavePanel()
        panel.title = "Choose Trace File"
        panel.nameFieldStringValue = "ds4-trace.txt"
        panel.allowedContentTypes = []
        if panel.runModal() == .OK, let url = panel.url {
            appModel.config.diagnosticsFilePath = url.path
        }
    }

    private func openFile(allowedExtensions: [String]?) -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if let allowedExtensions {
            panel.allowedContentTypes = allowedExtensions.compactMap { UTType(filenameExtension: $0) }
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func openDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func pathSummary(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func pathRow(
        _ label: String,
        path: String?,
        emptyText: String,
        choose: @escaping () -> Void
    ) -> some View {
        LabeledContent(label) {
            HStack {
                Text(pathSummary(path) ?? emptyText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                Button("Choose...") {
                    choose()
                }
            }
        }
    }

    private func integerField(value: Binding<Int>, placeholder: String) -> some View {
        TextField(placeholder, value: value, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
            .monospacedDigit()
    }

    private func doubleField(value: Binding<Double>, placeholder: String) -> some View {
        TextField(placeholder, value: value, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
            .monospacedDigit()
    }
}

private struct LogsPane: View {
    @ObservedObject var logStore: LogStore
    let showFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Logs")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    logStore.clear()
                }
                Button("Show Folder") {
                    showFolder()
                }
            }

            LabeledContent("ds4-server.log") {
                Text(logStore.fileURL.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            ScrollView {
                Text(logStore.text.isEmpty ? "No logs yet." : logStore.text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
