import SwiftUI
import ServiceManagement

enum ShieldTheme: String, CaseIterable, Identifiable {
    case dark, light, gradient
    var id: String { rawValue }
    func title(_ s: TVStrings) -> String {
        switch self {
        case .dark: return s.themeDarkLong
        case .light: return s.themeLightLong
        case .gradient: return s.themeColorLong
        }
    }

    func short(_ s: TVStrings) -> String {
        switch self {
        case .dark: return s.themeDarkShort
        case .light: return s.themeLightShort
        case .gradient: return s.themeColorShort
        }
    }
}

@MainActor
final class Prefs: ObservableObject {
    static let shared = Prefs()
    private let d = UserDefaults.standard

    /// 0 = süresiz (yalnızca elle kilit açma)
    @Published var duration: Int { didSet { d.set(duration, forKey: "duration") } }
    @Published var preroll: Int { didSet { d.set(preroll, forKey: "preroll") } }
    @Published var unlockHold: Double { didSet { d.set(unlockHold, forKey: "unlockHold") } }
    @Published var sounds: Bool { didSet { d.set(sounds, forKey: "sounds") } }
    @Published var mascot: Bool { didSet { d.set(mascot, forKey: "mascot") } }
    @Published var snark: Bool { didSet { d.set(snark, forKey: "snark") } }
    @Published var bubbles: Bool { didSet { d.set(bubbles, forKey: "bubbles") } }
    @Published var theme: ShieldTheme { didSet { d.set(theme.rawValue, forKey: "theme") } }
    @Published var hideCursor: Bool { didSet { d.set(hideCursor, forKey: "hideCursor") } }

    // MARK: Mola Vakti (20-20-20)
    @Published var breakEnabled: Bool { didSet { d.set(breakEnabled, forKey: "breakEnabled") } }
    @Published var workMinutes: Int { didSet { d.set(workMinutes, forKey: "workMinutes") } }
    @Published var breakSeconds: Int { didSet { d.set(breakSeconds, forKey: "breakSeconds") } }
    @Published var breakStrict: Bool { didSet { d.set(breakStrict, forKey: "breakStrict") } }
    @Published var breakSkipWhenIdle: Bool { didSet { d.set(breakSkipWhenIdle, forKey: "breakSkipWhenIdle") } }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Girişte başlatma ayarlanamadı: \(error.localizedDescription)")
            }
        }
    }

    private init() {
        d.register(defaults: [
            "duration": 120, "preroll": 3, "unlockHold": 2.0,
            "sounds": true, "mascot": true, "snark": true, "bubbles": true,
            "theme": ShieldTheme.dark.rawValue, "hideCursor": true,
            "breakEnabled": false, "workMinutes": 20, "breakSeconds": 20,
            "breakStrict": false, "breakSkipWhenIdle": true
        ])
        duration = d.integer(forKey: "duration")
        preroll = d.integer(forKey: "preroll")
        unlockHold = d.double(forKey: "unlockHold")
        sounds = d.bool(forKey: "sounds")
        mascot = d.bool(forKey: "mascot")
        snark = d.bool(forKey: "snark")
        bubbles = d.bool(forKey: "bubbles")
        theme = ShieldTheme(rawValue: d.string(forKey: "theme") ?? "dark") ?? .dark
        hideCursor = d.bool(forKey: "hideCursor")
        breakEnabled = d.bool(forKey: "breakEnabled")
        workMinutes = d.integer(forKey: "workMinutes")
        breakSeconds = d.integer(forKey: "breakSeconds")
        breakStrict = d.bool(forKey: "breakStrict")
        breakSkipWhenIdle = d.bool(forKey: "breakSkipWhenIdle")
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    // MARK: Seçenek listeleri (etiketler seçili dile göre üretilir)

    static func label(seconds: Int, _ s: TVStrings) -> String {
        if seconds == 0 { return s.unlimited }
        if seconds % 60 == 0 && seconds >= 60 {
            let minutes = seconds / 60
            return minutes == 1 ? s.minutesChoiceOne : String(format: s.minutesChoice, minutes)
        }
        return seconds == 1 ? s.secondsChoiceOne : String(format: s.secondsChoice, seconds)
    }

    static let workValues = [10, 20, 30, 45, 60]          // dakika
    static let breakValues = [20, 30, 60, 120]            // saniye
    static let durationValues = [30, 60, 120, 300, 600, 0] // saniye, 0 = süresiz

    static func workChoices(_ s: TVStrings) -> [(label: String, value: Int)] {
        workValues.map { ($0 == 1 ? s.minutesChoiceOne : String(format: s.minutesChoice, $0), $0) }
    }

    static func breakChoices(_ s: TVStrings) -> [(label: String, value: Int)] {
        breakValues.map { (label(seconds: $0, s), $0) }
    }

    static func durationChoices(_ s: TVStrings) -> [(label: String, value: Int)] {
        durationValues.map { (label(seconds: $0, s), $0) }
    }
}
