import SwiftUI

/// Aktif dili tutar. "system" seçiliyken sistem diline uyar,
/// sistem dili desteklenmiyorsa Türkçe kullanılır.
@MainActor
final class L10n: ObservableObject {
    static let shared = L10n()
    static let systemKey = "system"

    @Published var selection: String {
        didSet {
            UserDefaults.standard.set(selection, forKey: "language")
            refresh()
        }
    }

    @Published private(set) var current: AppLanguage = .tr
    @Published private(set) var s: TVStrings = .turkish

    private init() {
        selection = UserDefaults.standard.string(forKey: "language") ?? L10n.systemKey
        refresh()
        NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    private func refresh() {
        let language = (selection == L10n.systemKey)
            ? AppLanguage.fromSystem()
            : (AppLanguage(rawValue: selection) ?? .tr)
        current = language
        s = TVStrings.table[language] ?? .turkish
    }

    var systemResolvedName: String { AppLanguage.fromSystem().nativeName }

    /// Ondalık ayırıcı dile göre değişir (tr/de/fr: "2,5" — en: "2.5").
    func number(_ value: Double, digits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: current.rawValue)
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(digits)f", value)
    }
}

/// Kısa erişim
enum T {
    @MainActor static var s: TVStrings { L10n.shared.s }
}
