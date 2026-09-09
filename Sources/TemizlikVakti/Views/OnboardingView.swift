import SwiftUI
import AppKit

/// İlk çalıştırmada bir kez açılan karşılama penceresi.
/// Menü çubuğu uygulaması olduğu için, kurulumdan sonra hiçbir şey görünmüyordu:
/// kullanıcı ne uygulamanın çalıştığını ne de izin gerektiğini fark ediyordu.
@MainActor
enum Onboarding {
    private static var window: NSWindow?

    static var wasShown: Bool { UserDefaults.standard.bool(forKey: "didOnboard") }

    static func presentIfNeeded() {
        guard !wasShown else { return }
        present()
    }

    static func present() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = OnboardingView(onFinish: { finish() })
            .environmentObject(Prefs.shared)
            .environmentObject(L10n.shared)
            .environmentObject(BreakSession.shared)

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 430),
                         styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = "Temizlik Vakti"
        w.isReleasedWhenClosed = false
        w.center()
        w.level = .floating
        w.contentView = NSHostingView(rootView: view)
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func finish() {
        UserDefaults.standard.set(true, forKey: "didOnboard")
        window?.orderOut(nil)
        window = nil
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void

    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var l10n: L10n
    @EnvironmentObject var breaks: BreakSession
    @State private var page = 0
    @State private var permissionOK = Permissions.hasAccessibility
    private let ticker = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private var s: TVStrings { l10n.s }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [Color(red: 0.16, green: 0.11, blue: 0.35),
                                        Color(red: 0.09, green: 0.24, blue: 0.42)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                MascotView(mood: page == 2 ? .happy : .wiping, size: 96)
                    .accessibilityHidden(true)
            }
            .frame(height: 150)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Text(pageBody)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if page == 1 { permissionControls }
                if page == 2 { optionControls }

                Spacer(minLength: 0)

                HStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                    .accessibilityHidden(true)
                    Spacer()
                    if page < 2 {
                        Button(s.onboardSkip) { onFinish() }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        Button(s.onboardNext) { withAnimation { page += 1 } }
                            .keyboardShortcut(.defaultAction)
                    } else {
                        Button(s.onboardDone) { onFinish() }
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 460, height: 430)
        .onReceive(ticker) { _ in
            guard !permissionOK else { return }
            permissionOK = Permissions.hasAccessibility
        }
    }

    private var title: String {
        [s.onboardWelcomeTitle, s.onboardPermissionTitle, s.onboardBreakTitle][page]
    }

    private var pageBody: String {
        [s.onboardWelcomeBody, s.onboardPermissionBody, s.onboardBreakBody][page]
    }

    private var permissionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(permissionOK ? s.permissionGranted : s.permissionMissing,
                  systemImage: permissionOK ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(permissionOK ? .green : .orange)
                .accessibilityLabel(permissionOK ? s.permissionGranted : s.permissionMissing)

            HStack {
                Button(s.permissionRequest) {
                    Permissions.requestAccessibility()
                    permissionOK = Permissions.hasAccessibility
                }
                Button(s.permissionOpenSettings) { Permissions.openAccessibilitySettings() }
                Button(s.permissionRelaunch) { Permissions.relaunchApp() }
            }
            .controlSize(.small)
        }
        .padding(.top, 4)
    }

    private var optionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(s.breakToggle, isOn: $prefs.breakEnabled)
                .onChange(of: prefs.breakEnabled) { _, _ in breaks.rescheduleNext() }
            Toggle(s.settingsLaunchAtLogin, isOn: $prefs.launchAtLogin)
        }
        .toggleStyle(.switch)
        .padding(.top, 4)
    }
}
