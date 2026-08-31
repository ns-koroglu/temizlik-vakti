import AppKit
import ApplicationServices

enum Permissions {

    /// Girişi kilitlemek için Erişilebilirlik (Accessibility) izni şart.
    static var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Sistem iznini ister; macOS kendi uyarı penceresini gösterir.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
