import Foundation

enum AppPreferences {
    private static let configKey = "DS4Mac.serverConfig.v1"

    static func loadConfig() -> ServerConfig {
        guard let data = UserDefaults.standard.data(forKey: configKey) else {
            return ServerConfig.defaults()
        }
        do {
            return try JSONDecoder().decode(ServerConfig.self, from: data)
        } catch {
            return ServerConfig.defaults()
        }
    }

    static func saveConfig(_ config: ServerConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: configKey)
    }
}
