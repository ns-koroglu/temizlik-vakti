import AppKit
import SwiftUI

/// Tüm ekranları kaplayan, menü çubuğunun da üzerinde duran kalkan pencereleri.
/// İçeriği çağıran taraf belirler (temizlik kilidi, mola ekranı, …).
/// Kenarlıksız pencereler öntanımlı olarak key olamaz; olamayınca da
/// önizleme ve yumuşak mola ekranındaki "esc ile çık" yolu çalışmaz.
final class ShieldWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class ShieldController {

    private var windows: [NSWindow] = []
    private var observer: NSObjectProtocol?
    private var builder: ((Bool) -> AnyView)?
    private var interactive = false

    /// - Parameters:
    ///   - interactive: true ise pencereler tıklama/klavye alır (kilitlemeyen ekranlar için).
    ///   - content: her ekran için içerik; parametre ana ekransa true.
    func show(interactive: Bool = false, content: @escaping (Bool) -> AnyView) {
        self.builder = content
        self.interactive = interactive
        rebuild()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild() }
            }
    }

    func hide() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        builder = nil
    }

    var isVisible: Bool { !windows.isEmpty }

    private func rebuild() {
        guard let builder else { return }
        for w in windows { w.orderOut(nil) }
        windows.removeAll()

        // NSScreen.main uygulama etkin değilken nil olabiliyor; o durumda menü
        // çubuğunu taşıyan ekrana düş ki ana arayüz hiçbir ekrana düşmeden kalmasın.
        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        for screen in NSScreen.screens {
            let isPrimary = (screen == mainScreen)
            let window = ShieldWindow(contentRect: screen.frame,
                                      styleMask: [.borderless],
                                      backing: .buffered,
                                      defer: false)
            window.isReleasedWhenClosed = false
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = !interactive
            window.acceptsMouseMovedEvents = false
            window.setFrame(screen.frame, display: true)

            let host = NSHostingView(rootView: builder(isPrimary))
            host.frame = CGRect(origin: .zero, size: screen.frame.size)
            window.contentView = host
            window.orderFrontRegardless()
            if interactive && isPrimary { window.makeKeyAndOrderFront(nil) }
            windows.append(window)
        }
    }
}
