import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingClearKVCacheConfirmation = false

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
        .frame(width: 760, height: 640)
        .padding(20)
    }

    private var serviceTab: some View {
        SettingsPage {
            SettingsSection("Service Engine") {
                SettingRow(
                    "Engine",
                    description: engineDescription
                ) {
                    Picker("", selection: $appModel.config.serverEngine) {
                        ForEach(ServerEngine.allCases) { engine in
                            Text(engine.title).tag(engine)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }

                if appModel.config.serverEngine == .custom {
                    SettingRow(
                        "Custom Path",
                        description: String(localized: "Path to a custom ds4-server executable.")
                    ) {
                        pathControl(
                            displayText: pathSummary(appModel.config.customServerPath) ?? String(localized: "No executable selected"),
                            fullPath: appModel.config.customServerPath
                        ) {
                            chooseServiceEngine()
                        }
                    }
                }
            }

            SettingsSection("Model") {
                SettingRow(
                    "--model",
                    description: String(localized: "Main GGUF model loaded by ds4-server before accepting API requests.")
                ) {
                    pathControl(
                        displayText: pathSummary(appModel.config.modelPath) ?? String(localized: "No model selected"),
                        fullPath: appModel.config.modelPath
                    ) {
                        chooseModel()
                    }
                }

                SettingRow(
                    "--mtp",
                    description: String(localized: "Optional GGUF draft model for speculative decoding.")
                ) {
                    pathControl(
                        displayText: pathSummary(appModel.config.mtpPath) ?? String(localized: "Not set"),
                        fullPath: appModel.config.mtpPath
                    ) {
                        chooseMTPModel()
                    }
                }

                SettingRow(
                    "--mtp-draft",
                    description: String(localized: "Number of draft tokens to propose when the MTP model is enabled.")
                ) {
                    Stepper(value: $appModel.config.mtpDraftTokens, in: 1...16, step: 1) {
                        Text("\(appModel.config.mtpDraftTokens)")
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }
                    .frame(width: 150, alignment: .leading)
                }

                SettingRow(
                    "--mtp-margin",
                    description: String(localized: "Minimum confidence margin used when accepting speculative draft tokens.")
                ) {
                    doubleField(value: $appModel.config.mtpMargin, placeholder: "3")
                }
            }

            SettingsSection("HTTP API") {
                SettingRow(
                    "--host",
                    description: String(localized: "Bind address for the local API server. Keep 127.0.0.1 for local-only access.")
                ) {
                    Picker("", selection: $appModel.config.hostAccess) {
                        ForEach(HostAccess.allCases) { access in
                            Text(access.title).tag(access)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }

                SettingRow(
                    "--port",
                    description: String(localized: "TCP port for the OpenAI-compatible local API.")
                ) {
                    integerField(value: $appModel.config.port, placeholder: "8000")
                }

                SettingRow(
                    "--cors",
                    description: String(localized: "Allow browser-based clients to call the local service.")
                ) {
                    Toggle("", isOn: $appModel.config.browserClientsEnabled)
                        .labelsHidden()
                }
            }
        }
    }

    private var runtimeTab: some View {
        SettingsPage {
            SettingsSection("Model and Runtime") {
                SettingRow(
                    "--ctx",
                    description: String(localized: "Maximum context window, in tokens. Larger values use more memory.")
                ) {
                    integerField(value: $appModel.config.ctxTokens, placeholder: "100000")
                }

                SettingRow(
                    "--tokens",
                    description: String(localized: "Default generation budget when a client does not provide max tokens.")
                ) {
                    integerField(value: $appModel.config.defaultOutputTokens, placeholder: "393216")
                }

                SettingRow(
                    "--threads",
                    description: String(localized: "CPU worker thread count. Use 0 to let ds4 choose automatically.")
                ) {
                    integerField(value: $appModel.config.cpuThreads, placeholder: "0")
                }

                SettingRow(
                    "--backend",
                    description: String(localized: "Inference backend. Default lets ds4 choose the best available backend.")
                ) {
                    Picker("", selection: $appModel.config.backend) {
                        ForEach(ServerBackend.allCases) { backend in
                            Text(backendTitle(backend)).tag(backend)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }

                SettingRow(
                    "--warm-weights",
                    description: String(localized: "Touch model weights during startup to reduce first-request latency.")
                ) {
                    Toggle("", isOn: $appModel.config.warmWeights)
                        .labelsHidden()
                }

                SettingRow(
                    "--quality",
                    description: String(localized: "Prefer stricter quality paths where ds4 supports them.")
                ) {
                    Toggle("", isOn: $appModel.config.qualityMode)
                        .labelsHidden()
                }
            }
        }
    }

    private var storageTab: some View {
        SettingsPage {
            SettingsSection("Disk KV Cache") {
                SettingRow(
                    "--kv-disk-dir",
                    description: String(localized: "Enable disk-backed KV checkpoints and choose where cache files are stored.")
                ) {
                    Toggle("", isOn: $appModel.config.kvCacheEnabled)
                        .labelsHidden()
                }

                SettingRow(
                    "Cache Folder",
                    description: String(localized: "Folder used for ds4 disk KV cache files.")
                ) {
                    pathControl(
                        displayText: appModel.config.kvCacheDirectory,
                        fullPath: appModel.config.kvCacheDirectory
                    ) {
                        chooseKVCacheFolder()
                    }
                }

                SettingRow(
                    "--kv-disk-space-mb",
                    description: String(localized: "Maximum disk budget for KV cache files, in megabytes.")
                ) {
                    integerField(value: $appModel.config.kvDiskSpaceMB, placeholder: "8192")
                }

                SettingRow(
                    "Cache Usage",
                    description: String(localized: "Shows the current on-disk cache size. Stop the service before clearing it.")
                ) {
                    kvCacheUsageControl
                }
            }

            SettingsSection("KV Cache Options") {
                SettingRow(
                    "--kv-cache-min-tokens",
                    description: String(localized: "Smallest prefix length that ds4 will store as a reusable checkpoint.")
                ) {
                    integerField(value: $appModel.config.kvCacheMinTokens, placeholder: "512")
                }

                SettingRow(
                    "--kv-cache-cold-max-tokens",
                    description: String(localized: "Largest prompt prefix considered for the first cold checkpoint.")
                ) {
                    integerField(value: $appModel.config.kvCacheColdMaxTokens, placeholder: "30000")
                }

                SettingRow(
                    "--kv-cache-continued-interval-tokens",
                    description: String(localized: "Interval for additional checkpoints as a long prompt continues.")
                ) {
                    integerField(value: $appModel.config.kvCacheContinuedIntervalTokens, placeholder: "10000")
                }

                SettingRow(
                    "--kv-cache-boundary-trim-tokens",
                    description: String(localized: "Tail tokens trimmed before aligning checkpoint boundaries.")
                ) {
                    integerField(value: $appModel.config.kvCacheBoundaryTrimTokens, placeholder: "32")
                }

                SettingRow(
                    "--kv-cache-boundary-align-tokens",
                    description: String(localized: "Token chunk size used when aligning cache checkpoint boundaries.")
                ) {
                    integerField(value: $appModel.config.kvCacheBoundaryAlignTokens, placeholder: "2048")
                }

                SettingRow(
                    "--kv-cache-reject-different-quant",
                    description: String(localized: "Reject cache reuse when quantization metadata differs.")
                ) {
                    Toggle("", isOn: $appModel.config.kvCacheRejectDifferentQuant)
                        .labelsHidden()
                }

                SettingRow(
                    "--disable-exact-dsml-tool-replay",
                    description: String(localized: "Disable exact replay of DSML tool memory during compatible cache reuse.")
                ) {
                    Toggle("", isOn: $appModel.config.disableExactDSMLToolReplay)
                        .labelsHidden()
                }

                SettingRow(
                    "--tool-memory-max-ids",
                    description: String(localized: "Maximum number of tool-memory identifiers retained by ds4.")
                ) {
                    integerField(value: $appModel.config.toolMemoryMaxIds, placeholder: "100000")
                }
            }

            SettingsSection("Trace") {
                SettingRow(
                    "--trace",
                    description: String(localized: "Write a ds4 trace file for debugging rendered prompts and cache behavior.")
                ) {
                    Toggle("", isOn: $appModel.config.diagnosticsEnabled)
                        .labelsHidden()
                }

                SettingRow(
                    "Trace File",
                    description: String(localized: "Destination file used when trace logging is enabled.")
                ) {
                    pathControl(
                        displayText: pathSummary(appModel.config.diagnosticsFilePath) ?? "ds4-trace.txt",
                        fullPath: appModel.config.diagnosticsFilePath
                    ) {
                        chooseDiagnosticsFile()
                    }
                }
            }
        }
        .onAppear {
            appModel.refreshKVCacheUsage()
        }
        .onChange(of: appModel.config.kvCacheDirectory) { _, _ in
            appModel.refreshKVCacheUsage()
        }
        .onChange(of: appModel.config.kvDiskSpaceMB) { _, _ in
            appModel.refreshKVCacheUsage()
        }
        .alert("Clear KV Cache?", isPresented: $showingClearKVCacheConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Cache", role: .destructive) {
                appModel.clearKVCache()
            }
        } message: {
            Text("This removes all files in the configured KV cache folder.")
        }
    }

    private var logsTab: some View {
        LogsPane(logStore: appModel.logStore) {
            appModel.revealLogsFolder()
        }
    }

    private var kvCacheUsageControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(appModel.kvCacheUsageText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    appModel.refreshKVCacheUsage()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(appModel.isRefreshingKVCacheUsage)

                Button(role: .destructive) {
                    showingClearKVCacheConfirmation = true
                } label: {
                    Label("Clear Cache", systemImage: "trash")
                }
                .disabled(!appModel.canClearKVCache)
            }

            if let error = appModel.kvCacheStorageError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let fraction = appModel.kvCacheUsageFraction {
                ProgressView(value: fraction)
                    .frame(maxWidth: 360)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var engineDescription: String {
        switch appModel.config.serverEngine {
        case .automatic:
            if HardwareDetector.supportsSME {
                return String(localized: "Automatically selects the M4+ optimized engine for this Mac.")
            }
            return String(localized: "Automatically selects the baseline Metal engine for this Mac.")
        case .bundledMetal:
            return String(localized: "Uses the bundled ds4-server built for all Apple Silicon Macs.")
        case .bundledMetalM4:
            return String(localized: "Uses the bundled ds4-server optimized for M4 and later.")
        case .custom:
            if let path = pathSummary(appModel.config.customServerPath) {
                return path
            }
            return String(localized: "Select a custom ds4-server executable.")
        }
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
        panel.title = String(localized: "Choose Trace File")
        panel.nameFieldStringValue = "ds4-trace.txt"
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

    private func pathControl(
        displayText: String,
        fullPath: String?,
        choose: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Text(displayText)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .help(fullPath?.isEmpty == false ? fullPath! : displayText)

            Button("Choose...") {
                choose()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func integerField(value: Binding<Int>, placeholder: String) -> some View {
        TextField(placeholder, value: value, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 130)
            .monospacedDigit()
    }

    private func doubleField(value: Binding<Double>, placeholder: String) -> some View {
        TextField(placeholder, value: value, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 130)
            .monospacedDigit()
    }

    private func backendTitle(_ backend: ServerBackend) -> LocalizedStringKey {
        switch backend {
        case .automatic: "Default"
        case .metal: "metal"
        case .cuda: "cuda"
        case .cpu: "cpu"
        }
    }
}

private struct SettingsPage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content
            }
            .padding(.vertical, 8)
            .padding(.trailing, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    private let title: LocalizedStringKey
    private let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(spacing: 0) {
                content
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingRow<Control: View>: View {
    private let title: LocalizedStringKey
    private let description: String
    private let control: Control

    init(
        _ title: LocalizedStringKey,
        description: String,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.description = description
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 270, alignment: .leading)

            control
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
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
                if logStore.text.isEmpty {
                    Text("No logs yet.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                } else {
                    Text(logStore.text)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(10)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
