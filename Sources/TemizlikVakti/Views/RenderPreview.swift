import SwiftUI
import AppKit

/// `--render <yol.png>` ile çağrıldığında kilit ekranını dosyaya çizer.
/// Tasarımı ekranı kilitlemeden kontrol etmek için.
@MainActor
enum RenderPreview {
    static func run(path: String, mode: String = "lock", size: CGSize = CGSize(width: 1440, height: 900)) {
        let session = LockSession.shared
        session.configureForRender(elapsed: 42, unlock: 0.42, nudge: nil)

        let content: AnyView
        switch mode {
        case "break":
            let b = BreakSession.shared
            b.configureForRender(remaining: 12, total: 20)
            content = AnyView(BreakScreenView(isPrimary: true)
                .environmentObject(b)
                .environmentObject(Prefs.shared)
                .environmentObject(L10n.shared))
        case "party":
            session.configureForRender(elapsed: 42, unlock: 0, nudge: nil,
                                       egg: .party, eggMessage: "Hile kodu kabul edildi. Parti modu!")
            content = AnyView(LockScreenView(isPrimary: true)
                .environmentObject(session)
                .environmentObject(Prefs.shared)
                .environmentObject(L10n.shared))
        default:
            content = AnyView(LockScreenView(isPrimary: true)
                .environmentObject(session)
                .environmentObject(Prefs.shared)
                .environmentObject(L10n.shared))
        }

        let view = content.frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("çizim başarısız\n".utf8))
            return
        }
        try? png.write(to: URL(fileURLWithPath: path))
        print("yazıldı: \(path)")
    }
}
