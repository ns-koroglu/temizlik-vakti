import SwiftUI

@main
struct TemizlikVaktiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var prefs = Prefs.shared
    @StateObject private var session = LockSession.shared
    @StateObject private var breaks = BreakSession.shared
    @StateObject private var l10n = L10n.shared

    /// Menü çubuğu simgesi durumu göstersin: kilit/mola, duraklatılmış hatırlatıcı,
    /// yaklaşan mola. Eskiden yalnızca iki hâl vardı ve biri kalkanın altında kalıyordu.
    private var menuBarSymbol: String {
        if session.isActive || breaks.isResting { return "sparkles.rectangle.stack.fill" }
        if breaks.phase == .warning { return "eye.circle.fill" }
        if prefs.breakEnabled && breaks.isPaused { return "moon.zzz" }
        return "sparkles"
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView()
                .environmentObject(prefs)
                .environmentObject(session)
                .environmentObject(breaks)
                .environmentObject(l10n)
        } label: {
            Image(systemName: menuBarSymbol)
                .accessibilityLabel("Temizlik Vakti")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(prefs)
                .environmentObject(breaks)
                .environmentObject(l10n)
                .environmentObject(breaks)
                .environmentObject(l10n)
        }
    }
}
