import AppKit
import ApplicationServices
import CoreGraphics

enum Permissions {

    /// Asıl gerçek: event tap kurabiliyor muyuz? AXIsProcessTrusted süreç içinde
    /// önbelleğe alınabildiği ve eski/geçersiz TCC kayıtlarında yanıltabildiği için
    /// izni doğrudan sınayarak ölçüyoruz (dinleme amaçlı, hiçbir olayı yutmayan tap).
    static func canCreateEventTap() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) else { return false }
        CGEvent.tapEnable(tap: tap, enable: false)
        return true
    }

    /// Tanılama metni (panelde ve --check çıktısında gösterilir).
    static func diagnostics() -> String {
        let bundle = Bundle.main.bundlePath
        return """
        Paket: \(bundle)
        Kimlik: \(Bundle.main.bundleIdentifier ?? "-")
        AXIsProcessTrusted: \(AXIsProcessTrusted())
        Event tap kurulabiliyor: \(canCreateEventTap())
        """
    }

    /// Girişi kilitlemek için Erişilebilirlik (Accessibility) izni şart.
    static var hasAccessibility: Bool {
        AXIsProcessTrusted() || canCreateEventTap()
    }

    /// Sistem iznini ister; macOS kendi uyarı penceresini gösterir.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// İzin verildikten sonra macOS bazen yeniden başlatma ister.
    static func relaunchApp() {
        let url = Bundle.main.bundleURL
        let conf = NSWorkspace.OpenConfiguration()
        conf.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: conf) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.terminate(nil)
            }
        }
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
