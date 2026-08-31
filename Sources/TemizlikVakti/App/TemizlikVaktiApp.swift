import SwiftUI

@main
struct TemizlikVaktiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var prefs = Prefs.shared
    @StateObject private var session = LockSession.shared
    @StateObject private var breaks = BreakSession.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView()
                .environmentObject(prefs)
                .environmentObject(session)
                .environmentObject(breaks)
        } label: {
            Image(systemName: session.isActive || breaks.isResting ? "sparkles.rectangle.stack.fill" : "sparkles")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(prefs)
                .environmentObject(breaks)
        }
    }
}
