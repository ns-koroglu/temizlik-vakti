import SwiftUI
import AppKit

/// Mola başlamadan önce ekranın sağ üstünde beliren küçük uyarı.
/// Öncesinde mola hiçbir uyarı vermeden tüm ekranları kaplıyordu — cümlenin
/// ortasında, toplantıda, sunumda.
@MainActor
final class BreakWarningWindow {
    private var window: NSPanel?

    func show(session: BreakSession) {
        guard window == nil else { return }
        let content = BreakWarningView()
            .environmentObject(session)
            .environmentObject(L10n.shared)

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 96),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: content)

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.maxX - 320, y: f.maxY - 116))
        }
        panel.orderFrontRegardless()
        window = panel
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

struct BreakWarningView: View {
    @EnvironmentObject var session: BreakSession
    @EnvironmentObject var l10n: L10n

    private var s: TVStrings { l10n.s }

    var body: some View {
        HStack(spacing: 12) {
            MascotView(mood: .ready, size: 40, animated: false)
                .frame(width: 54, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: s.breakWarningTitle, Int(ceil(session.warningRemaining))))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                HStack(spacing: 8) {
                    Button(s.breakWarningStartNow) { session.startBreakNow() }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                    Button(s.breakWarningLater) { session.snoozeFromWarning(minutes: 5) }
                        .controlSize(.small)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 300, height: 96)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.12)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(format: s.breakWarningTitle, Int(ceil(session.warningRemaining))))
    }
}
