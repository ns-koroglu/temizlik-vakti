import AppKit
import SwiftUI

@MainActor
final class LockSession: ObservableObject {

    static let shared = LockSession()

    enum Phase: Equatable { case idle, preroll, running, finished }

    enum EasterEgg: Equatable { case party, annoyed, dizzy, sleepy, caps, secret }

    @Published private(set) var phase: Phase = .idle
    @Published var prerollRemaining: Double = 0
    @Published var elapsed: TimeInterval = 0
    @Published var remaining: TimeInterval = 0
    @Published var unlockProgress: Double = 0
    @Published var line: String = ""
    @Published var nudgeLine: String? = nil
    @Published var nudgeCount: Int = 0
    @Published var needsPermission = false
    @Published private(set) var isPreview = false

    // Etkileşim / easter egg durumu
    @Published var gaze: CGVector = .zero        // -1…1 aralığında bakış yönü
    @Published var egg: EasterEgg?
    @Published var eggMessage: String?
    @Published var pokeCount: Int = 0            // yutulan tuş/tık sayısı
    @Published var sparkleBurst: Int = 0         // artınca parıltı patlaması
    @Published var perfectRun = false

    /// 0 ise süresiz oturum
    private(set) var duration: Int = 0
    private var holdSeconds: Double = 2.0

    private let shield = ShieldController()
    private let sleepGuard = SleepGuard()
    private var timer: Timer?
    private var lastTick = Date()
    private var escapeStart: Date?
    private var lastSnark = Date.distantPast
    private var nudgeClearWork: DispatchWorkItem?
    private var cursorHidden = false
    private var previewMonitor: Any?

    // Easter egg defterleri
    private var virtualPoint: CGPoint = .zero
    private var screenSize: CGSize = CGSize(width: 1440, height: 900)
    private var keyHistory: [Int64] = []
    private var pokeTimes: [Date] = []
    private var flipTimes: [Date] = []
    private var lastMoveSign: Double = 0
    private var lastInputAt = Date()
    private var eggUntil: Date?

    private static let konami: [Int64] = [126, 126, 125, 125, 123, 124, 123, 124, 11, 0]
    private static let temiz: [Int64] = [17, 14, 46, 34, 6]   // t e m i z

    var isActive: Bool { phase != .idle }

    var progressFraction: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, elapsed / Double(duration)))
    }

    // MARK: - Başlat / bitir

    func start() {
        guard phase == .idle else { return }
        // Mola ekranı açıkken ikinci bir kalkan açma.
        guard !BreakSession.shared.isResting else { return }
        let prefs = Prefs.shared
        Sounds.enabled = prefs.sounds

        guard Permissions.hasAccessibility else {
            needsPermission = true
            Permissions.requestAccessibility()
            return
        }
        needsPermission = false

        duration = prefs.duration
        holdSeconds = max(0.5, prefs.unlockHold)
        elapsed = 0
        remaining = Double(duration)
        unlockProgress = 0
        escapeStart = nil
        nudgeLine = nil
        prerollRemaining = Double(prefs.preroll)
        resetInteraction()
        phase = prefs.preroll > 0 ? .preroll : .running
        line = phase == .preroll
            ? Snark.random(from: T.s.preroll, avoiding: nil)
            : Snark.random(from: T.s.snark, avoiding: nil)
        lastSnark = Date()

        let locker = InputLocker.shared
        locker.onEscapeChanged = { [weak self] down in
            guard let self else { return }
            self.escapeStart = down ? Date() : nil
            if !down { self.unlockProgress = 0 }
        }
        locker.onSignal = { [weak self] signal in self?.handle(signal: signal) }
        locker.onFailsafeUnlock = { [weak self] in self?.finish() }

        shield.show { isPrimary in
            AnyView(LockScreenView(isPrimary: isPrimary)
                .environmentObject(LockSession.shared)
                .environmentObject(Prefs.shared)
                .environmentObject(L10n.shared))
        }

        guard locker.start(owner: "lock", unlockHold: holdSeconds) else {
            shield.hide()
            phase = .idle
            needsPermission = true
            Permissions.requestAccessibility()
            return
        }

        sleepGuard.begin()
        if prefs.hideCursor { hideCursor() }
        Sounds.lock()

        lastTick = Date()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Girişi kilitlemeden yalnızca kalkan ekranını gösterir (tema/maskot denemek için).
    func startPreview() {
        guard phase == .idle, !isPreview else { return }
        guard !BreakSession.shared.isResting else { return }
        let prefs = Prefs.shared
        Sounds.enabled = prefs.sounds
        isPreview = true
        duration = prefs.duration
        elapsed = 0
        remaining = Double(duration)
        unlockProgress = 0
        nudgeLine = nil
        resetInteraction()
        phase = .running
        line = Snark.random(from: T.s.snark, avoiding: nil)
        lastSnark = Date()

        shield.show(interactive: true) { isPrimary in
            AnyView(LockScreenView(isPrimary: isPrimary)
                .environmentObject(LockSession.shared)
                .environmentObject(Prefs.shared)
                .environmentObject(L10n.shared))
        }
        NSApp.activate(ignoringOtherApps: true)

        previewMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.endPreview() }
            return nil
        }

        lastTick = Date()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func endPreview() {
        guard isPreview else { return }
        if let previewMonitor { NSEvent.removeMonitor(previewMonitor) }
        previewMonitor = nil
        timer?.invalidate(); timer = nil
        shield.hide()
        phase = .idle
        isPreview = false
    }

    /// Kilidi açar ve kısa bir "bitti" ekranı gösterir.
    func finish(auto: Bool = false) {
        guard phase == .preroll || phase == .running else { return }
        // Önizlemede kilit yok; süre dolduğunda önizlemeyi kapat.
        // (Eskiden finish() çalışıyor, isPreview true kalıyor ve olay izleyicisi sızıyordu.)
        if isPreview { endPreview(); return }
        releaseInput()
        phase = .finished
        unlockProgress = 0
        perfectRun = (pokeCount == 0 && elapsed > 15)
        clearEgg()
        line = perfectRun
            ? T.s.perfectRun
            : Snark.random(from: T.s.finished, avoiding: line)
        nudgeLine = nil
        Sounds.unlock()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self, self.phase == .finished else { return }
            self.shield.hide()
            self.phase = .idle
        }
    }

    /// Menüden ya da acil durumda anında kapat.
    func abort() {
        guard phase != .idle else { return }
        if isPreview { endPreview(); return }
        releaseInput()
        shield.hide()
        phase = .idle
        unlockProgress = 0
    }

    private func releaseInput() {
        timer?.invalidate(); timer = nil
        InputLocker.shared.stop(owner: "lock")
        InputLocker.shared.onEscapeChanged = nil
        InputLocker.shared.onSignal = nil
        InputLocker.shared.onFailsafeUnlock = nil
        sleepGuard.end()
        showCursor()
        escapeStart = nil
    }

    // MARK: - Zamanlayıcı

    private func tick() {
        let now = Date()
        // Uykudan dönüşte duvar saati sıçrar; tek karede oturumu bitirmesin.
        let dt = min(now.timeIntervalSince(lastTick), 1.0)
        lastTick = now

        switch phase {
        case .preroll:
            prerollRemaining -= dt
            if prerollRemaining <= 0 {
                phase = .running
                line = Snark.random(from: T.s.snark, avoiding: nil)
                lastSnark = now
            }
        case .running:
            elapsed += dt
            if duration > 0 {
                remaining = max(0, Double(duration) - elapsed)
                if remaining <= 0 { finish(auto: true); return }
            }
            if Prefs.shared.snark, now.timeIntervalSince(lastSnark) > 6.5 {
                lastSnark = now
                line = Snark.random(from: T.s.snark, avoiding: line)
            }
        default:
            return
        }

        // Easter egg zamanlaması
        if let until = eggUntil, now >= until { clearEgg() }
        if egg == nil, phase == .running, !isPreview, now.timeIntervalSince(lastInputAt) > 45 {
            setEgg(.sleepy, T.s.eggSleepy, seconds: 0)
        }

        // ESC basılı tutma ile kilit açma
        if let start = escapeStart {
            unlockProgress = min(1, now.timeIntervalSince(start) / holdSeconds)
            if unlockProgress >= 1 { finish() }
        }
    }

    private func resetInteraction() {
        gaze = .zero
        egg = nil
        eggMessage = nil
        eggUntil = nil
        pokeCount = 0
        sparkleBurst = 0
        perfectRun = false
        keyHistory.removeAll()
        pokeTimes.removeAll()
        flipTimes.removeAll()
        lastInputAt = Date()
        let frame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        screenSize = frame.size
        let mouse = NSEvent.mouseLocation
        virtualPoint = CGPoint(x: mouse.x - frame.minX,
                               y: frame.height - (mouse.y - frame.minY))
    }

    private func handle(signal: InputSignal) {
        guard phase == .preroll || phase == .running else { return }
        lastInputAt = Date()
        if egg == .sleepy { clearEgg() }

        switch signal.kind {
        case .move(let dx, let dy):
            updateGaze(dx: dx, dy: dy)
        case .key(let code):
            keyHistory.append(code)
            if keyHistory.count > 12 { keyHistory.removeFirst(keyHistory.count - 12) }
            checkSequences()
            poke()
        case .click, .scroll:
            poke()
        case .capsLock:
            setEgg(.caps, T.s.eggCaps, seconds: 2.5)
        }
    }

    /// Fare/trackpad hareketi: imleç donuk ama maskot nereye gittiğini biliyor.
    private func updateGaze(dx: Double, dy: Double) {
        virtualPoint.x = min(max(0, virtualPoint.x + dx), screenSize.width)
        virtualPoint.y = min(max(0, virtualPoint.y + dy), screenSize.height)
        gaze = CGVector(dx: (virtualPoint.x / screenSize.width) * 2 - 1,
                        dy: (virtualPoint.y / screenSize.height) * 2 - 1)

        // İleri geri hızlı savurma → başı döner
        let sign: Double = dx > 2 ? 1 : (dx < -2 ? -1 : 0)
        if sign != 0 {
            if sign != lastMoveSign && lastMoveSign != 0 {
                flipTimes.append(Date())
                flipTimes.removeAll { Date().timeIntervalSince($0) > 2 }
                if flipTimes.count >= 8, egg != .party {
                    setEgg(.dizzy, T.s.eggDizzy, seconds: 3)
                    flipTimes.removeAll()
                }
            }
            lastMoveSign = sign
        }
    }

    private func poke() {
        pokeCount += 1
        pokeTimes.append(Date())
        pokeTimes.removeAll { Date().timeIntervalSince($0) > 3 }

        if pokeTimes.count >= 15, egg != .party {
            setEgg(.annoyed, T.s.eggAnnoyed, seconds: 3)
            pokeTimes.removeAll()
        }

        guard escapeStart == nil, egg == nil else { return }
        nudgeCount += 1
        nudgeLine = Snark.random(from: T.s.blocked, avoiding: nudgeLine)
        Sounds.blocked()

        nudgeClearWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.nudgeLine = nil }
        nudgeClearWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
    }

    private func checkSequences() {
        if keyHistory.count >= Self.konami.count,
           Array(keyHistory.suffix(Self.konami.count)) == Self.konami {
            keyHistory.removeAll()
            sparkleBurst += 1
            Sounds.unlock()
            setEgg(.party, T.s.eggParty, seconds: 9)
            return
        }
        if keyHistory.count >= Self.temiz.count,
           Array(keyHistory.suffix(Self.temiz.count)) == Self.temiz {
            keyHistory.removeAll()
            sparkleBurst += 1
            Sounds.tick()
            setEgg(.secret, T.s.eggSecret, seconds: 4)
        }
    }

    private func setEgg(_ e: EasterEgg, _ message: String, seconds: Double) {
        egg = e
        eggMessage = message
        eggUntil = e == .sleepy ? nil : Date().addingTimeInterval(seconds)
        nudgeLine = nil
    }

    private func clearEgg() {
        egg = nil
        eggMessage = nil
        eggUntil = nil
    }

    // MARK: - İmleç

    private func hideCursor() {
        guard !cursorHidden else { return }
        cursorHidden = true
        CGDisplayHideCursor(CGMainDisplayID())
        NSCursor.hide()
    }

    private func showCursor() {
        guard cursorHidden else { return }
        cursorHidden = false
        CGDisplayShowCursor(CGMainDisplayID())
        NSCursor.unhide()
    }

    /// Yalnızca tasarım önizlemesi üretmek için kullanılır (--render).
    func configureForRender(elapsed: TimeInterval, unlock: Double, nudge: String?,
                            egg: EasterEgg? = nil, eggMessage: String? = nil) {
        self.egg = egg
        self.eggMessage = eggMessage
        duration = Prefs.shared.duration
        self.elapsed = elapsed
        remaining = max(0, Double(duration) - elapsed)
        unlockProgress = unlock
        nudgeLine = nudge
        line = T.s.snark.first ?? ""
        phase = .running
    }

    // MARK: - Biçimlendirme

    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
