import SwiftUI

/// Arka planda süzülen sabun köpükleri.
struct BubbleField: View {
    var count: Int = 20
    var tint: Color = .white

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            Canvas { g, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                for i in 0..<count {
                    let seed = Double(i) * 12.9898
                    let rnd1 = frac(sin(seed) * 43758.5453)
                    let rnd2 = frac(sin(seed * 1.7) * 12543.123)
                    let rnd3 = frac(sin(seed * 3.3) * 9871.71)

                    let radius = 5 + rnd2 * 26
                    let speed = 14 + rnd1 * 34
                    let span = size.height + 160
                    let raw = (t * speed + rnd3 * span).truncatingRemainder(dividingBy: span)
                    let y = size.height + 80 - raw
                    let x = rnd1 * size.width + sin(t * 0.5 + seed) * 26

                    let rect = CGRect(x: x - radius, y: y - radius,
                                      width: radius * 2, height: radius * 2)
                    let alpha = 0.05 + rnd2 * 0.09
                    g.stroke(Path(ellipseIn: rect),
                             with: .color(tint.opacity(alpha + 0.10)),
                             lineWidth: 1.0)
                    g.fill(Path(ellipseIn: rect), with: .color(tint.opacity(alpha * 0.30)))
                    let hi = CGRect(x: rect.minX + radius * 0.42, y: rect.minY + radius * 0.30,
                                    width: radius * 0.28, height: radius * 0.28)
                    g.fill(Path(ellipseIn: hi), with: .color(tint.opacity(alpha + 0.22)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func frac(_ v: Double) -> Double {
        let f = v - v.rounded(.down)
        return f < 0 ? f + 1 : f
    }
}

/// Yanlışlıkla tuşa basıldığında maskotu hafifçe sarsar.
struct Shake: GeometryEffect {
    var animatableData: CGFloat
    var amplitude: CGFloat = 9
    var shakes: CGFloat = 3

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amplitude * sin(animatableData * .pi * shakes)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
