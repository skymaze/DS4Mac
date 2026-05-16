import Foundation

struct ServerHealthChecker {
    func waitUntilReady(rootURL: URL, timeout: TimeInterval = 180) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await isReady(rootURL: rootURL) {
                return true
            }
            try? await Task.sleep(for: .seconds(1))
        }
        return false
    }

    func isReady(rootURL: URL) async -> Bool {
        let url = rootURL.appendingPathComponent("v1/models")
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }
}
