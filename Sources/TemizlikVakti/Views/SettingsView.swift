import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var breaks: BreakSession
    @State private var permissionOK = Permissions.hasAccessibility

    var body: some View {
        TabView {
            cleaning
                .tabItem { Label("Temizlik", systemImage: "sparkles") }
            breakTab
                .tabItem { Label("Mola", systemImage: "eye") }
            general
                .tabItem { Label("Genel", systemImage: "gearshape") }
        }
        .frame(width: 480, height: 520)
        .onAppear { permissionOK = Permissions.hasAccessibility }
    }

    // MARK: Temizlik

    private var cleaning: some View {
        Form {
            Section("Oturum") {
                Picker("Süre", selection: $prefs.duration) {
                    ForEach(Prefs.durationChoices, id: \.value) { c in Text(c.label).tag(c.value) }
                }
                Stepper(value: $prefs.preroll, in: 0...10) {
                    Text("Başlangıç geri sayımı: \(prefs.preroll) sn")
                }
                VStack(alignment: .leading) {
                    Text("Kilidi açmak için esc basılı tutma: \(String(format: "%.1f", prefs.unlockHold)) sn")
                    Slider(value: $prefs.unlockHold, in: 0.5...5.0, step: 0.5)
                }
            }

            Section("Görünüm") {
                Picker("Tema", selection: $prefs.theme) {
                    ForEach(ShieldTheme.allCases) { t in Text(t.title).tag(t) }
                }
                Toggle("Maskotu göster", isOn: $prefs.mascot)
                Toggle("Laf sokan yorumlar", isOn: $prefs.snark)
                Toggle("Sabun köpükleri", isOn: $prefs.bubbles)
                Toggle("İmleci gizle", isOn: $prefs.hideCursor)
                Toggle("Ses efektleri", isOn: $prefs.sounds)
            }

            Section {
                Text("""
                Maskot, kilitliyken bile trackpad hareketlerini izleyip gözleriyle seni takip eder. \
                Gizli numaralar var: klasik hile kodunu gir, "temiz" yaz, ya da bir süre hiçbir şeye \
                dokunma ve ne olduğunu gör.
                """)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Mola

    private var breakTab: some View {
        Form {
            Section("Göz molası (20-20-20)") {
                Toggle("Hatırlatıcı açık", isOn: $prefs.breakEnabled)
                    .onChange(of: prefs.breakEnabled) { _, _ in breaks.rescheduleNext() }
                Picker("Çalışma süresi", selection: $prefs.workMinutes) {
                    ForEach(Prefs.workChoices, id: \.value) { c in Text(c.label).tag(c.value) }
                }
                .onChange(of: prefs.workMinutes) { _, _ in breaks.rescheduleNext() }
                Picker("Mola süresi", selection: $prefs.breakSeconds) {
                    ForEach(Prefs.breakChoices, id: \.value) { c in Text(c.label).tag(c.value) }
                }
                Toggle("Katı mod — molada girişi kilitle", isOn: $prefs.breakStrict)
                Toggle("Bilgisayar başında değilsem molayı atla", isOn: $prefs.breakSkipWhenIdle)
            }

            Section {
                HStack {
                    Button("Şimdi mola ver") { breaks.startBreak() }
                        .disabled(breaks.isResting || LockSession.shared.isActive)
                    if breaks.isPaused {
                        Button("Duraklatmayı kaldır") { breaks.resume() }
                    } else {
                        Button("1 saat duraklat") { breaks.pause(hours: 1) }
                            .disabled(!prefs.breakEnabled)
                    }
                }
            }

            Section {
                Text("""
                Her \(prefs.workMinutes) dakikada bir \(prefs.breakSeconds) saniyelik mola ekranı açılır. \
                Katı mod kapalıyken molayı esc ile geçebilir ya da 5 dakika erteleyebilirsin.
                """)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Genel

    private var general: some View {
        Form {
            Section {
                Toggle("Girişte başlat", isOn: $prefs.launchAtLogin)
                HStack {
                    Label(permissionOK ? "Erişilebilirlik izni verildi" : "Erişilebilirlik izni yok",
                          systemImage: permissionOK ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(permissionOK ? .green : .orange)
                    Spacer()
                    Button("Ayarları Aç") { Permissions.openAccessibilitySettings() }
                    Button("Yenile") { permissionOK = Permissions.hasAccessibility }
                }
            }

            Section {
                Text("""
                Kısayol: Kontrol + Seçenek + Komut + C ile temizliği başlatabilirsin.
                Güç düğmesi, Touch ID ve bazı donanım tuşları macOS tarafından korunur; \
                bunlar kilitlenemez. Uygulama kapanırsa kilit anında açılır.
                """)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
