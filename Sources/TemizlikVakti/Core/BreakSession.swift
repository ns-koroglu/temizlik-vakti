import AppKit
import SwiftUI
import CoreGraphics

/// 20-20-20 kuralına göre düzenli göz molası hatırlatıcısı.
/// Temizlik kilidiyle aynı kalkan pencereyi kullanır.
@MainActor
final class BreakSession: ObservableObject {

    static let shared = BreakSession()

    enum Phase: Equatable { case idle, warning, resting, finished }

    @Published private(set) var phase: Phase = .idle
    @Published var remaining: TimeInterval = 0
    @Published var nextBreakAt: Date?
    @Published var pausedUntil: Date?
    @Published var tip: String = ""
    @Published var unlockProgress: Double = 0
    /// Bu molada girdi gerçekten kilitlendi mi (tap kurulamamış olabilir)
    @Published private(set) var strictActive = false
    /// Mola başlamadan önceki geri sayım (sn)
    @Published private(set) var warningRemaining: Double = 0

    private let shield = ShieldController()
    private let warningWindow = BreakWarningWindow()
    /// Mola ekranı açılmadan kaç saniye önce uyarılsın
    private let warningLead: Double = 15
    private let sleepGuard = SleepGuard()
    private var scheduler: Timer?
    private var ticker: Timer?
    private var lastTick = Date()
    private var escapeStart: Date?
    private var keyMonitor: Any?
    private var isStrict = false
    private var totalSeconds: Double = 20

    /// Mola ekranı açık mı (uyarı fazı buna dahil değil)
    var isResting: Bool { phase == .resting || phase == .finished }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / totalSeconds))
    }

    /// Bir sonraki molaya kalan süre (sn), kapalıysa nil.
    var secondsUntilNextBreak: TimeInterval? {
        guard Prefs.shared.breakEnabled, let next = nextBreakAt else { return nil }
        return max(0, next.timeIntervalSinceNow)
    }

    var isPaused: Bool {
        guard let pausedUntil else { return false }
        return pausedUntil > Date()
    }

    // MARK: - Zamanlayıcı

    func startScheduling() {
        guard scheduler == nil else { return }
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }
        RunLoop.main.add(t, forMode: .common)
        scheduler = t
        rescheduleNext()
    }

    func rescheduleNext() {
        let prefs = Prefs.shared
        nextBreakAt = prefs.breakEnabled
            ? Date().addingTimeInterval(Double(max(1, prefs.workMinutes)) * 60)
            : nil
    }

    func pause(hours: Double) {
        if phase == .warning { exitWarning() }
        let until = Date().addingTimeInterval(hours * 3600)
        pausedUntil = until
        // Duraklatma bittiğinde mola anında patlamasın: sayacı da ötele.
        nextBreakAt = until.addingTimeInterval(Double(max(1, Prefs.shared.workMinutes)) * 60)
    }

    func resume() {
        pausedUntil = nil
        rescheduleNext()
    }

    func snooze(minutes: Double) {
        endBreak(completed: false)
        nextBreakAt = Date().addingTimeInterval(minutes * 60)
    }

    private func evaluate() {
        let prefs = Prefs.shared
        guard prefs.breakEnabled else {
            if phase == .warning { exitWarning() }
            nextBreakAt = nil
            return
        }
        // Temizlik oturumu varken araya girme
        if LockSession.shared.isActive {
            if phase == .warning { exitWarning() }
            nextBreakAt = Date().addingTimeInterval(60)
            return
        }
        if isPaused {
            if phase == .warning { exitWarning() }
            return
        }
        guard let next = nextBreakAt else { rescheduleNext(); return }
        let untilBreak = next.timeIntervalSinceNow

        // Uyarı fazındaysak geri sayımı sürdür
        if phase == .warning {
            warningRemaining = max(0, untilBreak)
            if untilBreak <= 0 {
                exitWarning()
                startBreak()
            }
            return
        }

        guard phase == .idle else { return }
        guard untilBreak <= warningLead else { return }

        // Kullanıcı zaten başında değilse mola gösterme
        if prefs.breakSkipWhenIdle, idleSeconds() > 120 {
            nextBreakAt = Date().addingTimeInterval(60)
            return
        }
        enterWarning(remaining: max(1, untilBreak))
    }

    // MARK: - Ön uyarı

    private func enterWarning(remaining: Double) {
        guard phase == .idle else { return }
        phase = .warning
        warningRemaining = remaining
        warningWindow.show(session: self)
        Sounds.tick()
    }

    private func exitWarning() {
        guard phase == .warning else { return }
        warningWindow.hide()
        warningRemaining = 0
        phase = .idle
    }

    /// Uyarıdaki "Şimdi başla"
    func startBreakNow() {
        exitWarning()
        startBreak()
    }

    /// Uyarıdaki "5 dk sonra"
    func snoozeFromWarning(minutes: Double) {
        exitWarning()
        nextBreakAt = Date().addingTimeInterval(minutes * 60)
    }

    /// Kilit oturumu başlarken uyarı ekranı kalmasın.
    func cancelWarning() {
        guard phase == .warning else { return }
        exitWarning()
        nextBreakAt = Date().addingTimeInterval(60)
    }

    private func idleSeconds() -> Double {
        guard let anyType = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyType)
    }

    // MARK: - Mola

    func startBreak() {
        guard phase == .idle, !LockSession.shared.isActive else { return }
        let prefs = Prefs.shared
        Sounds.enabled = prefs.sounds
        isStrict = prefs.breakStrict && Permissions.hasAccessibility
        totalSeconds = Double(max(5, prefs.breakSeconds))
        remaining = totalSeconds
        unlockProgress = 0
        escapeStart = nil
        tip = Snark.random(from: T.s.breakTips, avoiding: nil)
        phase = .resting

        // Önce kilidi kur: başarısız olursa yumuşak moda düşüp kalkanı
        // etkileşimli açmalıyız (aksi hâlde Ertele/Atla düğmeleri ölü kalıyordu).
        if isStrict {
            let locker = InputLocker.shared
            locker.onEscapeChanged = { [weak self] down in
                guard let self else { return }
                self.escapeStart = down ? Date() : nil
                if !down { self.unlockProgress = 0 }
            }
            locker.onFailsafeUnlock = { [weak self] in self?.endBreak(completed: false) }
            if !locker.start(owner: "break", unlockHold: Prefs.shared.unlockHold) {
                locker.onEscapeChanged = nil
                locker.onFailsafeUnlock = nil
                isStrict = false
            }
        }
        strictActive = isStrict

        shield.show(interactive: !isStrict) { isPrimary in
            AnyView(BreakScreenView(isPrimary: isPrimary)
                .environmentObject(BreakSession.shared)
                .environmentObject(Prefs.shared)
                .environmentObject(L10n.shared))
        }

        if !isStrict {
            NSApp.activate(ignoringOtherApps: true)
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard event.keyCode == 53 else { return event }   // esc
                MainActor.assumeIsolated { self?.endBreak(completed: false) }
                return nil
            }
        }

        sleepGuard.begin()
        Sounds.tick()

        lastTick = Date()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        guard phase == .resting else { return }
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTick), 1.0)   // uykudan dönüşte sıçramasın
        lastTick = now
        remaining = max(0, remaining - dt)

        if let start = escapeStart {
            unlockProgress = min(1, now.timeIntervalSince(start) / max(0.5, Prefs.shared.unlockHold))
            if unlockProgress >= 1 { endBreak(completed: false); return }
        }
        if remaining <= 0 { endBreak(completed: true) }
    }

    func endBreak(completed: Bool) {
        guard phase == .resting else { return }
        ticker?.invalidate(); ticker = nil
        if isStrict {
            InputLocker.shared.stop(owner: "break")
            InputLocker.shared.onEscapeChanged = nil
            InputLocker.shared.onFailsafeUnlock = nil
        }
        strictActive = false
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        sleepGuard.end()
        escapeStart = nil
        unlockProgress = 0

        if completed {
            Stats.shared.recordBreak()
            phase = .finished
            tip = Snark.random(from: T.s.breakDone, avoiding: tip)
            Sounds.unlock()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                guard let self, self.phase == .finished else { return }
                self.shield.hide()
                self.phase = .idle
                self.rescheduleNext()
            }
        } else {
            shield.hide()
            phase = .idle
            rescheduleNext()
        }
    }

    func abort() {
        if phase == .warning { exitWarning(); return }
        guard phase != .idle else { return }
        ticker?.invalidate(); ticker = nil
        if isStrict { InputLocker.shared.stop(owner: "break") }
        strictActive = false
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        sleepGuard.end()
        shield.hide()
        phase = .idle
    }

    /// Yalnızca tasarım önizlemesi için (--render break).
    func configureForRender(remaining: Double, total: Double) {
        totalSeconds = total
        self.remaining = remaining
        self.warningRemaining = 12
        tip = T.s.breakTips.first ?? ""
        phase = .resting
    }

    /// Geri sayım metni — saat/dakika kısaltmaları seçili dilden gelir.
    static func countdown(_ seconds: TimeInterval, _ strings: TVStrings? = nil) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total >= 3600 {
            let format = (strings ?? T.s).countdownHoursMinutes
            return String(format: format, total / 3600, (total % 3600) / 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
