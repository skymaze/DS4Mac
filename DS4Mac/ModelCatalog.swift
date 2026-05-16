import Foundation

enum ModelType: String, Codable, CaseIterable {
    case main
    case mtp
}

struct ModelInfo: Identifiable {
    var id: String { key }
    let key: String
    let name: String
    let url: URL
    let expectedBytes: Int64
    let isMTP: Bool

    var repo: String {
        let parts = url.pathComponents
        guard parts.count >= 5 else { return "models" }
        let user = parts[parts.count - 5]
        let repoName = parts[parts.count - 4]
        return "\(user)/\(repoName)"
    }

    var filename: String {
        url.lastPathComponent
    }
}

enum ModelCatalog {
    private static let baseURL = "https://huggingface.co/antirez/deepseek-v4-gguf/resolve/main"

    static let recommended: [ModelInfo] = [
        ModelInfo(
            key: "q2-imatrix",
            name: String(localized: "DeepSeek V4 Flash (q2-imatrix)"),
            url: URL(string: "\(baseURL)/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf")!,
            expectedBytes: 81_000_000_000,
            isMTP: false
        ),
        ModelInfo(
            key: "q4-imatrix",
            name: String(localized: "DeepSeek V4 Flash (q4-imatrix)"),
            url: URL(string: "\(baseURL)/DeepSeek-V4-Flash-Q4KExperts-F16HC-F16Compressor-F16Indexer-Q8Attn-Q8Shared-Q8Out-chat-v2-imatrix.gguf")!,
            expectedBytes: 153_000_000_000,
            isMTP: false
        ),
        ModelInfo(
            key: "mtp",
            name: String(localized: "DeepSeek V4 Flash (MTP draft model)"),
            url: URL(string: "\(baseURL)/DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf")!,
            expectedBytes: 3_500_000_000,
            isMTP: true
        )
    ]
}
