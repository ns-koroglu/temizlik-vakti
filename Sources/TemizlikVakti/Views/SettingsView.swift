import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var breaks: BreakSession
    @EnvironmentObject var l10n: L10n
    @State private var permissionOK = Permissions.hasAccessibility

    private var s: TVStrings { l10n.s }

    var body: some View {
        TabView {
            cleaning
                .tabItem { Label(s.tabCleaning, systemImage: "sparkles") }
            breakTab
                .tabItem { Label(s.tabBreak, systemImage: "eye") }
            general
                .tabItem { Label(s.settingsGeneral, systemImage: "gearshape") }
        }
        .frame(width: 500, height: 540)
        .onAppear { permissionOK = Permissions.hasAccessibility }
    }

    private var cleaning: some View {
        Form {
            Section(s.settingsSession) {
                Picker(s.settingsDuration, selection: $prefs.duration) {
                    ForEach(Prefs.durationChoices(s), id: \.value) { c in Text(c.label).tag(c.value) }
                }
                Stepper(value: $prefs.preroll, in: 0...10) {
                    Text(String(format: s.settingsPreroll, prefs.preroll))
                }
                VStack(alignment: .leading) {
                    Text(String(format: s.settingsUnlockHold, l10n.number(prefs.unlockHold)))
                    Slider(value: $prefs.unlockHold, in: 0.5...5.0, step: 0.5)
                }
            }

            Section(s.settingsAppearance) {
                Picker(s.settingsTheme, selection: $prefs.theme) {
                    ForEach(ShieldTheme.allCases) { t in Text(t.title(s)).tag(t) }
                }
                Toggle(s.settingsShowMascot, isOn: $prefs.mascot)
                Toggle(s.settingsSnark, isOn: $prefs.snark)
                Toggle(s.settingsBubbles, isOn: $prefs.bubbles)
                Toggle(s.settingsHideCursor, isOn: $prefs.hideCursor)
                Toggle(s.settingsSounds, isOn: $prefs.sounds)
            }

            Section {
                Text(s.settingsEasterEggNote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var breakTab: some View {
        Form {
            Section(s.settingsBreakSection) {
                Toggle(s.breakToggle, isOn: $prefs.breakEnabled)
                    .onChange(of: prefs.breakEnabled) { _, _ in breaks.rescheduleNext() }
                Picker(s.breakWork, selection: $prefs.workMinutes) {
                    ForEach(Prefs.workChoices(s), id: \.value) { c in Text(c.label).tag(c.value) }
                }
                .onChange(of: prefs.workMinutes) { _, _ in breaks.rescheduleNext() }
                Picker(s.breakLength, selection: $prefs.breakSeconds) {
                    ForEach(Prefs.breakChoices(s), id: \.value) { c in Text(c.label).tag(c.value) }
                }
                Toggle(s.breakStrictMode, isOn: $prefs.breakStrict)
                Toggle(s.breakSkipWhenIdle, isOn: $prefs.breakSkipWhenIdle)
            }

            Section {
                HStack {
                    Button(s.breakNow) { breaks.startBreak() }
                        .disabled(breaks.isResting || LockSession.shared.isActive)
                    if breaks.isPaused {
                        Button(s.breakResume) { breaks.resume() }
                    } else {
                        Button(s.breakPauseHour) { breaks.pause(hours: 1) }
                            .disabled(!prefs.breakEnabled)
                    }
                }
            }

            Section {
                Text(String(format: s.settingsBreakNote, prefs.workMinutes, prefs.breakSeconds))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var general: some View {
        Form {
            Section {
                Picker(s.language, selection: $l10n.selection) {
                    Text(String(format: s.systemLanguage, l10n.systemResolvedName))
                        .tag(L10n.systemKey)
                    Divider()
                    ForEach(AppLanguage.allCases) { lang in
                        Text("\(lang.flag)  \(lang.nativeName)").tag(lang.rawValue)
                    }
                }
                Toggle(s.settingsLaunchAtLogin, isOn: $prefs.launchAtLogin)
                HStack {
                    Label(permissionOK ? s.permissionGranted : s.permissionMissing,
                          systemImage: permissionOK ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(permissionOK ? .green : .orange)
                    Spacer()
                    Button(s.settingsOpenSettings) { Permissions.openAccessibilitySettings() }
                    Button(s.settingsRefresh) { permissionOK = Permissions.hasAccessibility }
                }
            }

            Section {
                Text(s.settingsShortcutNote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
