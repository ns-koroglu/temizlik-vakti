import Foundation

/// Desteklenen diller. Varsayılan ve geri düşüş dili her zaman Türkçe.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case tr, en, de, es, fr, it, pt, ru, zh, ja

    var id: String { rawValue }

    /// Dilin kendi adı (dil listesinde böyle görünür)
    var nativeName: String {
        switch self {
        case .tr: return "Türkçe"
        case .en: return "English"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .ru: return "Русский"
        case .zh: return "简体中文"
        case .ja: return "日本語"
        }
    }

    var flag: String {
        switch self {
        case .tr: return "🇹🇷"
        case .en: return "🇬🇧"
        case .de: return "🇩🇪"
        case .es: return "🇪🇸"
        case .fr: return "🇫🇷"
        case .it: return "🇮🇹"
        case .pt: return "🇵🇹"
        case .ru: return "🇷🇺"
        case .zh: return "🇨🇳"
        case .ja: return "🇯🇵"
        }
    }

    /// Sistem dil etiketlerinde bu dile işaret eden ön ekler
    var localeTags: [String] {
        switch self {
        case .tr: return ["tr"]
        case .en: return ["en"]
        case .de: return ["de"]
        case .es: return ["es", "ca", "gl"]
        case .fr: return ["fr"]
        case .it: return ["it"]
        case .pt: return ["pt"]
        case .ru: return ["ru"]
        case .zh: return ["zh"]
        case .ja: return ["ja"]
        }
    }

    /// Sistem dilini eşleştirir; listede yoksa Türkçe döner.
    static func fromSystem() -> AppLanguage {
        let preferred = (UserDefaults.standard.stringArray(forKey: "AppleLanguages")
                         ?? Locale.preferredLanguages)
        for tag in preferred {
            let primary = tag.split(separator: "-").first.map(String.init)?.lowercased() ?? ""
            if let match = AppLanguage.allCases.first(where: { $0.localeTags.contains(primary) }) {
                return match
            }
        }
        return .tr
    }
}
