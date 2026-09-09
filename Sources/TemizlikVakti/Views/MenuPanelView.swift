import SwiftUI

struct MenuPanelView: View {
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var session: LockSession
    @EnvironmentObject var breaks: BreakSession
    @EnvironmentObject var l10n: L10n
    @State private var permissionOK = Permissions.hasAccessibility
    @State private var tab = 0
    /// Yayıncı body içinde yaratılırsa her yeniden çizimde sıfırlanır.
    private let permissionTicker = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private var s: TVStrings { l10n.s }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Picker("", selection: $tab) {
                Text(s.tabCleaning).tag(0)
                Text(s.tabBreak).tag(1)
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            if !permissionOK && tab == 0 { permissionCard }

            if tab == 0 { cleaningTab } else { breakTab }

            Divider()

            HStack(spacing: 10) {
                SettingsLink {
                    Label(s.settings, systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))

                Spacer()

                languageMenu

                Button(s.quit) { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { permissionOK = Permissions.hasAccessibility }
        .onReceive(permissionTicker) { _ in
            permissionOK = Permissions.hasAccessibility
        }
    }

    // MARK: - Başlık

    private var header: some View {
        HStack(spacing: 10) {
            MascotView(mood: .ready, size: 44, liveMouse: true)
                .frame(width: 58, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("Temizlik Vakti")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text(s.tagline)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var languageMenu: some View {
        Menu {
            Picker("", selection: $l10n.selection) {
                Text(String(format: s.systemLanguage, l10n.systemResolvedName))
                    .tag(L10n.systemKey)
                Divider()
                ForEach(AppLanguage.allCases) { lang in
                    Text("\(lang.flag)  \(lang.nativeName)").tag(lang.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "globe")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 26)
        .help(s.language)
    }

    // MARK: - Temizlik sekmesi

    @ViewBuilder
    private var cleaningTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(s.durationLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Picker("", selection: $prefs.duration) {
                ForEach(Prefs.durationChoices(s), id: \.value) { choice in
                    Text(choice.label).tag(choice.value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            Text(s.themeLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Picker("", selection: $prefs.theme) {
                ForEach(ShieldTheme.allCases) { t in Text(t.short(s)).tag(t) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }

        Button(action: startCleaning) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text(session.isActive ? s.cleaningInProgress : s.startCleaning)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .disabled(session.isActive || !permissionOK)

        Button {
            MenuBarPanel.dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { session.startPreview() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "eye")
                Text(s.previewButton)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(session.isActive)

        Text(.init(String(format: s.unlockHintMenu, l10n.number(prefs.unlockHold))))
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Mola sekmesi

    @ViewBuilder
    private var breakTab: some View {
        Toggle(isOn: $prefs.breakEnabled) {
            Text(s.breakToggle)
                .font(.system(size: 13, weight: .medium))
        }
        .toggleStyle(.switch)
        .onChange(of: prefs.breakEnabled) { _, _ in breaks.rescheduleNext() }

        statusLine

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(s.breakWork).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $prefs.workMinutes) {
                    ForEach(Prefs.workChoices(s), id: \.value) { c in Text(c.label).tag(c.value) }
                }
                .labelsHidden().pickerStyle(.menu).frame(width: 130)
                .onChange(of: prefs.workMinutes) { _, _ in breaks.rescheduleNext() }
            }
            HStack {
                Text(s.breakLength).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $prefs.breakSeconds) {
                    ForEach(Prefs.breakChoices(s), id: \.value) { c in Text(c.label).tag(c.value) }
                }
                .labelsHidden().pickerStyle(.menu).frame(width: 130)
            }
        }
        .disabled(!prefs.breakEnabled)

        Toggle(isOn: $prefs.breakStrict) {
            Text(s.breakStrictMode).font(.system(size: 12))
        }
        .toggleStyle(.checkbox)
        .disabled(!prefs.breakEnabled || !permissionOK)

        HStack(spacing: 8) {
            Button {
                MenuBarPanel.dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { breaks.startBreak() }
            } label: {
                Label(s.breakNow, systemImage: "eye").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(breaks.isResting || session.isActive)

            if breaks.isPaused {
                Button(s.breakResume) { breaks.resume() }
            } else {
                Button(s.breakPauseHour) { breaks.pause(hours: 1) }
                    .disabled(!prefs.breakEnabled)
            }
        }
        .controlSize(.regular)

        Text(s.breakRuleNote)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var statusLine: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .foregroundStyle(prefs.breakEnabled ? .blue : .secondary)
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            }
            .padding(.vertical, 6).padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private var statusIcon: String {
        if !prefs.breakEnabled { return "moon.zzz" }
        if breaks.isPaused { return "pause.circle" }
        return "timer"
    }

    private var statusText: String {
        if !prefs.breakEnabled { return s.breakDisabled }
        if breaks.isPaused, let until = breaks.pausedUntil {
            return String(format: s.breakPaused, BreakSession.countdown(until.timeIntervalSinceNow))
        }
        if let seconds = breaks.secondsUntilNextBreak {
            return String(format: s.breakNext, BreakSession.countdown(seconds))
        }
        return s.breakScheduling
    }

    // MARK: - İzin kartı

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(s.permissionTitle, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
            Text(s.permissionBody)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(s.permissionRequest) {
                    Permissions.requestAccessibility()
                    permissionOK = Permissions.hasAccessibility
                }
                Button(s.permissionOpenSettings) { Permissions.openAccessibilitySettings() }
                Button(s.permissionRelaunch) { Permissions.relaunchApp() }
            }
            .font(.system(size: 11))
            .controlSize(.small)

            Text(s.permissionStaleNote)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func startCleaning() {
        MenuBarPanel.dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            session.start()
            permissionOK = Permissions.hasAccessibility
        }
    }
}

/// MenuBarExtra panelini programatik olarak kapatmak için küçük yardımcı.
enum MenuBarPanel {
    @MainActor
    static func dismiss() {
        for window in NSApp.windows {
            let name = String(describing: type(of: window))
            if name.contains("MenuBarExtra") || name.contains("NSStatusBarWindow") {
                window.orderOut(nil)
            }
        }
    }
}
