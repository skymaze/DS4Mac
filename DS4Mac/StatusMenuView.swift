import AppKit
import SwiftUI

struct StatusMenuView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            controls
            Divider()
            diagnostics
            Divider()
            footer
        }
        .frame(width: 300)
        .padding(14)
        .onAppear {
            AppWindowPresenter.activate()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: appModel.status.systemImage)
                    .foregroundStyle(statusColor)
                Text("DS4")
                    .font(.headline)
                Spacer()
                Text(appModel.status.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(appModel.config.localAPIBaseAddress)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    appModel.start()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .disabled(!appModel.canStartService)

                Button {
                    appModel.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!appModel.canStopService)
            }

            Button {
                appModel.restart()
            } label: {
                Label("Restart", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!appModel.canStopService)
        }
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 8) {
            if case .failed(let message) = appModel.status {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                appModel.copyServiceAddress()
            } label: {
                Label("Copy Address", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }

            Button {
                appModel.revealLogsFolder()
            } label: {
                Label("Show Logs Folder", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                AppWindowPresenter.showSettings {
                    openSettings()
                }
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Spacer()

            Button {
                appModel.quit()
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
    }

    private var statusColor: Color {
        switch appModel.status {
        case .stopped: .secondary
        case .starting, .stopping: .orange
        case .running: .green
        case .failed: .red
        }
    }
}
