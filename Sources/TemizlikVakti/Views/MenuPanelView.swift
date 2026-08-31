import SwiftUI

struct MenuPanelView: View {
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var session: LockSession
    @EnvironmentObject var breaks: BreakSession
    @State private var permissionOK = Permissions.hasAccessibility
    @State private var tab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Picker("", selection: $tab) {
                Text("Temizlik").tag(0)
                Text("Mola").tag(1)
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            if !permissionOK && tab == 0 { permissionCard }

            if tab == 0 { cleaningTab } else { breakTab }

            Divider()

            HStack {
                SettingsLink {
                    Label("Ayarlar…", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))

                Spacer()

                Button("Çıkış") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { permissionOK = Permissions.hasAccessibility }
        // İzin verildiği anda uyarı kartı kendiliğinden kaybolsun
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            if !permissionOK { permissionOK = Permissions.hasAccessibility }
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
                Text("Mac'ini sil, tuşlara basma derdi yok.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Temizlik sekmesi

    @ViewBuilder
    private var cleaningTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Temizlik süresi")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Picker("", selection: $prefs.duration) {
                ForEach(Prefs.durationChoices, id: \.value) { choice in
                    Text(choice.label).tag(choice.value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            Text("Ekran teması")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Picker("", selection: $prefs.theme) {
                ForEach(ShieldTheme.allCases) { t in Text(t.short).tag(t) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }

        Button(action: startCleaning) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text(session.isActive ? "Temizlik sürüyor…" : "Temizliğe Başla")
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
                Text("Önizle (kilitlemeden)")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(session.isActive)

        Text("Kilidi açmak için **esc** tuşunu \(String(format: "%.1f", prefs.unlockHold)) sn basılı tut.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }

    // MARK: - Mola sekmesi

    @ViewBuilder
    private var breakTab: some View {
        Toggle(isOn: $prefs.breakEnabled) {
            Text("Göz molası hatırlatıcısı")
                .font(.system(size: 13, weight: .medium))
        }
        .toggleStyle(.switch)
        .onChange(of: prefs.breakEnabled) { _, _ in breaks.rescheduleNext() }

        statusLine

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Çalışma").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $prefs.workMinutes) {
                    ForEach(Prefs.workChoices, id: \.value) { c in Text(c.label).tag(c.value) }
                }
                .labelsHidden().pickerStyle(.menu).frame(width: 130)
                .onChange(of: prefs.workMinutes) { _, _ in breaks.rescheduleNext() }
            }
            HStack {
                Text("Mola").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $prefs.breakSeconds) {
                    ForEach(Prefs.breakChoices, id: \.value) { c in Text(c.label).tag(c.value) }
                }
                .labelsHidden().pickerStyle(.menu).frame(width: 130)
            }
        }
        .disabled(!prefs.breakEnabled)

        Toggle(isOn: $prefs.breakStrict) {
            Text("Katı mod — molada girişi kilitle")
                .font(.system(size: 12))
        }
        .toggleStyle(.checkbox)
        .disabled(!prefs.breakEnabled || !permissionOK)

        HStack(spacing: 8) {
            Button {
                MenuBarPanel.dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { breaks.startBreak() }
            } label: {
                Label("Şimdi mola", systemImage: "eye")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(breaks.isResting || session.isActive)

            if breaks.isPaused {
                Button("Devam") { breaks.resume() }
            } else {
                Button("1 sa duraklat") { breaks.pause(hours: 1) }
                    .disabled(!prefs.breakEnabled)
            }
        }
        .controlSize(.regular)

        Text("20-20-20: her 20 dakikada bir, 20 saniye boyunca ~6 metre uzağa bak.")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
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
        if !prefs.breakEnabled { return "Hatırlatıcı kapalı" }
        if breaks.isPaused, let until = breaks.pausedUntil {
            return "Duraklatıldı — \(BreakSession.countdown(until.timeIntervalSinceNow)) kaldı"
        }
        if let s = breaks.secondsUntilNextBreak {
            return "Sonraki mola: \(BreakSession.countdown(s))"
        }
        return "Planlanıyor…"
    }

    // MARK: - İzin kartı

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Erişilebilirlik izni gerekli", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
            Text("Klavye ve trackpad'i kilitleyebilmek için Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik listesinde Temizlik Vakti'ne izin ver.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            HStack {
                Button("İzin İste") {
                    Permissions.requestAccessibility()
                    permissionOK = Permissions.hasAccessibility
                }
                Button("Ayarları Aç") { Permissions.openAccessibilitySettings() }
                Button("Yeniden Başlat") { Permissions.relaunchApp() }
            }
            .font(.system(size: 11))
            .controlSize(.small)

            Text("İzni verdiğin hâlde bu uyarı kalıyorsa uygulamayı yeniden başlat; macOS eski izin kaydını bazen ancak o zaman tazeler.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
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
