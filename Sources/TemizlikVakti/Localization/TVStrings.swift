import Foundation

/// Uygulamanın tüm metinleri. Her dil bu yapının **tamamını** doldurmak zorunda;
/// yeni alan eklenince çeviri dosyaları derlenmez, böylece eksik çeviri kalmaz.
struct TVStrings: Sendable {
    // Menü paneli
    let tagline: String
    let tabCleaning: String
    let tabBreak: String
    let durationLabel: String
    let themeLabel: String
    let startCleaning: String
    let cleaningInProgress: String
    let previewButton: String
    let unlockHintMenu: String        // %@ = saniye
    let settings: String
    let quit: String
    let language: String
    let systemLanguage: String        // %@

    // Süre seçenekleri
    let secondsChoice: String         // %d
    let minutesChoice: String         // %d
    let unlimited: String

    // Temalar
    let themeDarkShort: String
    let themeLightShort: String
    let themeColorShort: String
    let themeDarkLong: String
    let themeLightLong: String
    let themeColorLong: String

    // İzin kartı
    let permissionTitle: String
    let permissionBody: String
    let permissionRequest: String
    let permissionOpenSettings: String
    let permissionRelaunch: String
    let permissionStaleNote: String
    let permissionGranted: String
    let permissionMissing: String

    // Kilit ekranı
    let unlockHold: String
    let unlockHolding: String
    let lockFooterNote: String
    let unlimitedSession: String
    let allClean: String
    let perfectRun: String
    let sessionSummary: String        // %@ süre, %d girdi

    // Easter egg mesajları
    let eggParty: String
    let eggAnnoyed: String
    let eggDizzy: String
    let eggSleepy: String
    let eggCaps: String
    let eggSecret: String

    // Mola
    let breakTitle: String
    let breakOver: String
    let breakSnooze: String
    let breakSkip: String
    let breakEscHint: String
    let breakStrictHint: String
    let breakStrictUnlock: String
    let breakToggle: String
    let breakWork: String
    let breakLength: String
    let breakStrictMode: String
    let breakSkipWhenIdle: String
    let breakNow: String
    let breakPauseHour: String
    let breakResume: String
    let breakRuleNote: String
    let breakDisabled: String
    let breakPaused: String            // %@ kalan süre
    let breakNext: String              // %@ kalan süre
    let breakScheduling: String

    // Ayarlar penceresi
    let settingsSession: String
    let settingsAppearance: String
    let settingsGeneral: String
    let settingsDuration: String
    let settingsPreroll: String        // %d
    let settingsUnlockHold: String     // %@
    let settingsTheme: String
    let settingsShowMascot: String
    let settingsSnark: String
    let settingsBubbles: String
    let settingsHideCursor: String
    let settingsSounds: String
    let settingsLaunchAtLogin: String
    let settingsRefresh: String
    let settingsOpenSettings: String
    let settingsEasterEggNote: String
    let settingsShortcutNote: String
    let settingsBreakSection: String
    let settingsBreakNote: String      // %d dakika, %d saniye

    // Metin listeleri
    let snark: [String]
    let preroll: [String]
    let blocked: [String]
    let finished: [String]
    let breakTips: [String]
    let breakDone: [String]
}

extension TVStrings {
    static let table: [AppLanguage: TVStrings] = [
        .tr: .turkish, .en: .english, .de: .german, .es: .spanish, .fr: .french,
        .it: .italian, .pt: .portuguese, .ru: .russian, .zh: .chinese, .ja: .japanese
    ]
}
