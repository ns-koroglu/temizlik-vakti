import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var hotkeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Geliştirme yardımcısı: kilit ekranını PNG olarak çiz ve çık.
        let args = CommandLine.arguments
        if args.contains("--check") {
            let text = Permissions.diagnostics()
            print(text)
            // Dünya-yazılır /tmp yerine kullanıcıya özel geçici dizin (sembolik bağ
            // ile dosya ezme riski ve dünya-okunur donanım dökümü olmasın).
            let path = NSTemporaryDirectory() + "tv-check.txt"
            try? text.write(toFile: path, atomically: true, encoding: .utf8)
            print("yazıldı: \(path)")
            NSApp.terminate(nil)
            return
        }
        if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
            let mode = (i + 2 < args.count && !args[i + 2].hasPrefix("-")) ? args[i + 2] : "lock"
            MainActor.assumeIsolated { RenderPreview.run(path: args[i + 1], mode: mode) }
            NSApp.terminate(nil)
            return
        }

        MainActor.assumeIsolated {
            BreakSession.shared.startScheduling()
            // İlk çalıştırmada menü çubuğu uygulaması hiçbir işaret vermiyordu.
            // Status item yerleşsin diye kısa bir gecikmeyle açıyoruz.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                Onboarding.presentIfNeeded()
            }
        }

        // Genel kısayol: ⌃⌥⌘C
        hotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            let mods: NSEvent.ModifierFlags = [.control, .option, .command]
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == mods,
                  event.charactersIgnoringModifiers?.lowercased() == "c" else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if !LockSession.shared.isActive { LockSession.shared.start() }
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            LockSession.shared.abort()
            BreakSession.shared.abort()
        }
        if let hotkeyMonitor { NSEvent.removeMonitor(hotkeyMonitor) }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
