import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case auto
    case en
    case zhHans

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: String(localized: "Auto (System)")
        case .en: "English"
        case .zhHans: "简体中文"
        }
    }

    var appleLanguageCode: String? {
        switch self {
        case .auto: nil
        case .en: "en"
        case .zhHans: "zh-Hans"
        }
    }
}

enum AppPreferences {
    private static let configKey = "DS4Mac.serverConfig.v1"
    private static let languageKey = "DS4Mac.appLanguage"

    static var appLanguage: AppLanguage {
        get {
            guard let raw = UserDefaults.standard.string(forKey: languageKey),
                  let lang = AppLanguage(rawValue: raw) else { return .auto }
            return lang
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
            if let code = newValue.appleLanguageCode {
                UserDefaults.standard.set([code], forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            }
        }
    }

    static func applyLanguage() {
        if let code = appLanguage.appleLanguageCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
    }

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
