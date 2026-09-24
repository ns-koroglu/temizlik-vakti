import AppKit
import CoreGraphics

/// Klavye + fare/trackpad girişini sistem genelinde yutan CGEvent tap sarmalayıcısı.
///
/// Kilit yalnızca bu süreç yaşadığı sürece geçerlidir: uygulama çökerse ya da
/// zorla kapatılırsa macOS tap'i otomatik olarak kaldırır ve giriş geri gelir.
/// Yutulan bir girdinin arayüze taşınan özeti.
struct InputSignal: Sendable {
    enum Kind: Sendable {
        case key(Int64)
        case move(dx: Double, dy: Double)
        case click
        case scroll
        case capsLock
    }
    var kind: Kind

    /// Fare hareketi dışındaki girdiler maskotu irkiltir.
    var isPoke: Bool {
        if case .move = kind { return false }
        return true
    }
}

final class InputLocker {

    static let shared = InputLocker()
    private init() {}

    private var _tap: CFMachPort?
    /// Tap iki iş parçacığından erişiliyor (ana kuyruk kurar/yıkar, tap iş parçacığı
    /// yeniden etkinleştirir). Kilitli erişim + yerel güçlü referans, serbest
    /// bırakılmış CFMachPort kullanımını engelliyor.
    private var tap: CFMachPort? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _tap }
        set { stateLock.lock(); _tap = newValue; stateLock.unlock() }
    }
    private let stateLock = NSLock()
    private var source: CFRunLoopSource?
    private var thread: Thread?
    private var loop: CFRunLoop?

    private var _isRunning = false
    private var isRunning: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _isRunning }
        set { stateLock.lock(); _isRunning = newValue; stateLock.unlock() }
    }
    /// Kilidi kim kurdu ("lock" ya da "break") — iki oturum birbirinin kilidini sökmesin.
    private var _owner: String?
    private var owner: String? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _owner }
        set { stateLock.lock(); _owner = newValue; stateLock.unlock() }
    }
    private var _failsafeFired = false
    private var failsafeFired: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _failsafeFired }
        set { stateLock.lock(); _failsafeFired = newValue; stateLock.unlock() }
    }

    /// ESC basılı tutma durumu değiştiğinde ana kuyrukta çağrılır.
    private var _onEscapeChanged: ((Bool) -> Void)?
    var onEscapeChanged: ((Bool) -> Void)? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _onEscapeChanged }
        set { stateLock.lock(); _onEscapeChanged = newValue; stateLock.unlock() }
    }
    /// Yutulan her olayın özeti (ana kuyrukta). Maskotun tepki vermesi için.
    private var _onSignal: ((InputSignal) -> Void)?
    var onSignal: ((InputSignal) -> Void)? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _onSignal }
        set { stateLock.lock(); _onSignal = newValue; stateLock.unlock() }
    }
    /// Arayüz yanıt vermezse bile ESC basılı tutulunca devreye giren acil çıkış.
    private var _onFailsafeUnlock: (() -> Void)?
    var onFailsafeUnlock: (() -> Void)? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _onFailsafeUnlock }
        set { stateLock.lock(); _onFailsafeUnlock = newValue; stateLock.unlock() }
    }

    private var _escapeDown = false
    private var escapeDown: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _escapeDown }
        set { stateLock.lock(); _escapeDown = newValue; stateLock.unlock() }
    }
    private var lastMouseSignal = Date.distantPast
    private var lastScrollSignal = Date.distantPast
    private var pendingDX: Double = 0
    private var pendingDY: Double = 0
    private var _escapeSince: Date?
    private var escapeSince: Date? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _escapeSince }
        set { stateLock.lock(); _escapeSince = newValue; stateLock.unlock() }
    }
    private var _unlockHold: Double = 2.0
    private var unlockHold: Double {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _unlockHold }
        set { stateLock.lock(); _unlockHold = newValue; stateLock.unlock() }
    }

    private static let escapeKeyCode: Int64 = 53

    // MARK: - Yaşam döngüsü

    @discardableResult
    func start(owner: String, unlockHold: Double = 2.0) -> Bool {
        // Zaten kilitliyse yalnızca aynı sahip devam edebilir.
        guard !isRunning else { return self.owner == owner }
        self.owner = owner
        self.failsafeFired = false
        self.unlockHold = max(0.5, unlockHold)

        // Tüm olay türlerini yut. Elle 1...33 yazmak bugünün pressure/directTouch
        // olaylarını ve ileride eklenecek türleri dışarıda bırakıyordu; kilidin
        // iddiası "hiçbir girdi geçmez" olduğu için maske eksiksiz olmalı.
        // (0 = null olayı hariç; tapDisabled bildirimleri maskeden bağımsız gelir.)
        let mask: CGEventMask = ~CGEventMask(1)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let locker = Unmanaged<InputLocker>.fromOpaque(refcon).takeUnretainedValue()
                return locker.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            self.owner = nil
            return false   // Genellikle Erişilebilirlik izni yok demektir.
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            self.tap = nil
            self.owner = nil
            return false
        }

        self.tap = tap
        self.source = source
        escapeDown = false
        isRunning = true

        // Tap geri çağrımını ana iş parçacığından ayrı tut: arayüz takılsa bile
        // olaylar zamanında yutulur (aksi hâlde macOS tap'i devre dışı bırakır).
        let t = Thread { [weak self] in
            guard let self else { return }
            self.loop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            while !Thread.current.isCancelled {
                CFRunLoopRunInMode(.defaultMode, 0.25, false)
                self.checkFailsafe()
            }
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        t.name = "app.temizlikvakti.eventtap"
        t.qualityOfService = .userInteractive
        thread = t
        t.start()
        return true
    }

    func stop(owner: String? = nil) {
        // Yalnızca kilidi kuran taraf (ya da sahipsiz çağrı) durdurabilir.
        if let owner, let current = self.owner, owner != current { return }
        guard isRunning || tap != nil else { return }
        isRunning = false
        self.owner = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        thread?.cancel()
        if let loop { CFRunLoopStop(loop) }
        thread = nil
        loop = nil
        source = nil
        tap = nil
        escapeDown = false
        escapeSince = nil
    }

    /// Ana iş parçacığı donsa bile ESC uzun basımı kilidi açar.
    private func checkFailsafe() {
        stateLock.lock()
        let running = _isRunning
        let fired = _failsafeFired
        let since = _escapeSince
        let hold = _unlockHold
        guard running, !fired, let since,
              Date().timeIntervalSince(since) > hold + 1.0 else {
            stateLock.unlock()
            return
        }
        _failsafeFired = true
        let tap = _tap
        stateLock.unlock()

        // Girdiyi hemen serbest bırak, ama tap/iş parçacığı temizliğini ana kuyruğa
        // bırak: buradan teardown yapmak zombi iş parçacığı bırakıyor ve sonraki
        // oturum kendi kendine açılıyordu.
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        let callback = onFailsafeUnlock
        DispatchQueue.main.async { callback?() }
    }

    // MARK: - Olay işleme

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Sistem tap'i askıya aldıysa hemen geri aç.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Yalnızca oturum sürüyorsa yeniden aç; durdurulduktan sonra gelen geç
            // bildirimle tap'i diriltme.
            if isRunning, !failsafeFired, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            // Askıya alma sırasında ESC keyUp'ı kaybolabilir; durumu sıfırla ki
            // kilit kendi kendine açılmasın.
            if escapeDown {
                escapeDown = false
                escapeSince = nil
                let callback = onEscapeChanged
                DispatchQueue.main.async { callback?(false) }
            }
            return nil
        }
        guard isRunning else { return Unmanaged.passUnretained(event) }

        if type == .keyDown || type == .keyUp {
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            if code == Self.escapeKeyCode {
                let down = (type == .keyDown)
                if down != escapeDown {
                    escapeDown = down
                    escapeSince = down ? Date() : nil
                    let callback = onEscapeChanged
                    DispatchQueue.main.async { callback?(down) }
                }
                return nil   // ESC de dışarı sızmasın
            }
        }

        // Diğer her şey yutulur; ama ne olduğunu arayüze bildir.
        emit(type: type, event: event)
        return nil
    }

    private func emit(type: CGEventType, event: CGEvent) {
        var signal: InputSignal?

        switch type {
        case .keyDown:
            signal = InputSignal(kind: .key(event.getIntegerValueField(.keyboardEventKeycode)))
        case .flagsChanged:
            if event.flags.contains(.maskAlphaShift) { signal = InputSignal(kind: .capsLock) }
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            signal = InputSignal(kind: .click)
        case .scrollWheel:
            // Trackpad kaydırması saniyede yüzlerce olay üretiyor; her biri ana
            // kuyruğa atlayıp ses çalıyordu.
            let now = Date()
            guard now.timeIntervalSince(lastScrollSignal) > 0.3 else { return }
            lastScrollSignal = now
            signal = InputSignal(kind: .scroll)
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            pendingDX += Double(event.getIntegerValueField(.mouseEventDeltaX))
            pendingDY += Double(event.getIntegerValueField(.mouseEventDeltaY))
            let now = Date()
            guard now.timeIntervalSince(lastMouseSignal) > 0.025 else { return }
            lastMouseSignal = now
            let dx = pendingDX, dy = pendingDY
            pendingDX = 0; pendingDY = 0
            signal = InputSignal(kind: .move(dx: dx, dy: dy))
        default:
            break
        }

        guard let signal else { return }
        let callback = onSignal
        DispatchQueue.main.async { callback?(signal) }
    }
}
