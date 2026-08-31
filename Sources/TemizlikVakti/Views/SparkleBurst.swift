import SwiftUI

/// Easter egg tetiklendiğinde ekranın ortasından dışa saçılan parıltılar.
struct SparkleBurst: View {
    var tint: Color = .yellow
    var count: Int = 16
    private let start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let elapsed = ctx.date.timeIntervalSince(start)
            let p = min(1, elapsed / 1.4)
            Canvas { g, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for i in 0..<count {
                    let angle = Double(i) / Double(count) * 2 * .pi
                    let dist = 60 + p * 380 * (0.6 + Double((i % 4)) * 0.15)
                    let x = center.x + cos(angle) * dist
                    let y = center.y + sin(angle) * dist
                    let r = 14 * (1 - p) + 3
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    g.fill(sparklePath(in: rect), with: .color(tint.opacity((1 - p) * 0.95)))
                }
            }
        }
    }

    private func sparklePath(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = rect.width / 2
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + r * 0.18, y: c.y - r * 0.18))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + r * 0.18, y: c.y + r * 0.18))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - r * 0.18, y: c.y + r * 0.18))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - r * 0.18, y: c.y - r * 0.18))
        return p
    }
}
