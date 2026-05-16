import Combine
import Foundation

struct LogLine: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let message: String
}

final class LogStore: ObservableObject {
    @Published private(set) var lines: [LogLine] = []

    let fileURL: URL
    private let limit: Int

    init(limit: Int = 500, fileURL: URL = AppDirectories.logs.appendingPathComponent("ds4-server.log")) {
        self.limit = limit
        self.fileURL = fileURL
        try? AppDirectories.ensureCreated()
    }

    func append(_ message: String) {
        let clean = message.trimmingCharacters(in: .newlines)
        guard !clean.isEmpty else { return }
        var newLines: [LogLine] = []
        for line in clean.components(separatedBy: .newlines) where !line.isEmpty {
            newLines.append(LogLine(timestamp: Date(), message: line))
        }
        lines.append(contentsOf: newLines)
        if lines.count > limit {
            lines.removeFirst(lines.count - limit)
        }
        appendToDisk(newLines)
    }

    func clear() {
        lines.removeAll()
        try? AppDirectories.ensureCreated()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
            try? handle.truncate(atOffset: 0)
            try? handle.close()
        } else {
            _ = FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    var text: String {
        lines.map(\.message).joined(separator: "\n")
    }

    private func appendToDisk(_ newLines: [LogLine]) {
        guard !newLines.isEmpty else { return }
        try? AppDirectories.ensureCreated()
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            _ = FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        let text = newLines
            .map { "[\(Self.timestampFormatter.string(from: $0.timestamp))] \($0.message)" }
            .joined(separator: "\n") + "\n"
        if let data = text.data(using: .utf8) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
        try? handle.close()
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
