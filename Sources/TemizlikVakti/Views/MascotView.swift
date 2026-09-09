import SwiftUI
import AppKit

enum MascotMood {
    case ready, wiping, surprised, happy, resting
    case annoyed, dizzy, sleepy, party
}

/// Elinde beziyle sünger dostumuz. Tamamen SwiftUI ile çizildi.
/// `gaze` ile gözleri bir noktayı takip eder (-1…1 aralığında, ekran merkezine göre).
struct MascotView: View {
    var mood: MascotMood = .wiping
    var size: CGFloat = 220
    var gaze: CGVector = .zero
    /// true ise gerçek imleç konumunu kendi okur (kilitli olmayan ekranlar için).
    var liveMouse: Bool = false
    /// false ise tek kare çizilir. Menü çubuğu paneli gizlendiğinde SwiftUI
    /// TimelineView'ı durdurmuyor: maskot arka planda 30 fps çizilmeye devam edip
    /// boştaki uygulamayı %10-20 CPU'da tutuyordu (ölçüldü).
    var animated: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { ctx in
            let t = animated ? ctx.date.timeIntervalSinceReferenceDate : 0
            let look = liveMouse ? Self.mouseGaze() : gaze
            let party = (mood == .party)
            let bobSpeed = party ? 5.5 : 1.7
            let bob = CGFloat(sin(t * bobSpeed)) * size * (party ? 0.045 : 0.022)
            let tilt = Angle.degrees(sin(t * 1.1) * 2.5 + look.dx * 4)
            let wipe = Angle.degrees(wipeAngle(t))
            let blink = eyeOpenness(t)

            ZStack {
                bodyStack(t: t, wipe: wipe, blink: blink, look: look)
            }
            .rotationEffect(tilt)
            .offset(y: bob)
            .frame(width: size * 1.35, height: size * 1.2)
            .overlay(alignment: .topTrailing) {
                if mood == .sleepy { zzz(t: t) }
            }
        }
    }

    // MARK: - Hareket yardımcıları

    private func wipeAngle(_ t: TimeInterval) -> Double {
        switch mood {
        case .wiping: return sin(t * 4.2) * 22
        case .party: return sin(t * 9) * 34
        case .annoyed: return sin(t * 7) * 12
        case .happy: return -25
        case .resting, .sleepy: return -8
        default: return 0
        }
    }

    private func eyeOpenness(_ t: TimeInterval) -> CGFloat {
        switch mood {
        case .resting, .sleepy: return 0.05
        case .annoyed: return 0.45
        case .surprised, .dizzy: return 1.15
        default:
            let cycle = t.truncatingRemainder(dividingBy: 3.9)
            if cycle < 0.13 { return CGFloat(abs(cos((cycle / 0.13) * .pi))) }
            return 1
        }
    }

    static func mouseGaze() -> CGVector {
        let p = NSEvent.mouseLocation
        guard let f = NSScreen.main?.frame, f.width > 0, f.height > 0 else { return .zero }
        let nx = ((p.x - f.minX) / f.width) * 2 - 1
        let ny = 1 - ((p.y - f.minY) / f.height) * 2
        return CGVector(dx: min(max(nx, -1), 1), dy: min(max(ny, -1), 1))
    }

    // MARK: - Parçalar

    @ViewBuilder
    private func bodyStack(t: TimeInterval, wipe: Angle, blink: CGFloat, look: CGVector) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .frame(width: size, height: size * 0.82)
                .blur(radius: size * 0.06)
                .offset(y: size * 0.09)

            ZStack {
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            Color(red: 1.00, green: 0.85, blue: 0.35),
                            Color(red: 0.98, green: 0.70, blue: 0.20)
                        ], startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: size * 0.012)
                    )
                    .frame(width: size, height: size * 0.82)
                    .overlay(holes)

                RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            Color(red: 0.30, green: 0.62, blue: 0.95),
                            Color(red: 0.18, green: 0.44, blue: 0.82)
                        ], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: size * 0.9, height: size * 0.17)
                    .offset(y: size * 0.3)
            }
            .hueRotation(.degrees(mood == .party ? sin(t * 2.2) * 180 : 0))

            face(blink: blink, look: look, t: t)
                .offset(y: -size * 0.06)

            arm
                .rotationEffect(.degrees(-32) + wipe, anchor: .bottom)
                .offset(x: size * 0.56, y: -size * 0.20)
        }
    }

    private var holes: some View {
        ZStack {
            ForEach(Array(holeSpots.enumerated()), id: \.offset) { _, spot in
                Circle()
                    .fill(Color(red: 0.86, green: 0.58, blue: 0.12).opacity(0.55))
                    .frame(width: size * spot.r, height: size * spot.r)
                    .offset(x: size * spot.x, y: size * spot.y)
            }
        }
    }

    private var holeSpots: [(x: CGFloat, y: CGFloat, r: CGFloat)] {
        [(-0.34, -0.22, 0.075), (0.30, -0.28, 0.055), (-0.40, 0.10, 0.05),
         (0.38, 0.06, 0.07), (0.05, -0.33, 0.045), (-0.12, 0.16, 0.04)]
    }

    @ViewBuilder
    private func face(blink: CGFloat, look: CGVector, t: TimeInterval) -> some View {
        HStack(spacing: size * 0.16) {
            eye(blink: blink, look: look, t: t)
            eye(blink: blink, look: look, t: t)
        }
        .overlay(alignment: .bottom) { mouth.offset(y: size * 0.20) }
    }

    private func eye(blink: CGFloat, look: CGVector, t: TimeInterval) -> some View {
        let orbit = mood == .dizzy
        let px = orbit ? cos(t * 7) * 0.9 : min(max(look.dx, -1), 1)
        let py = orbit ? sin(t * 7) * 0.9 : min(max(look.dy, -1), 1)
        return ZStack {
            Capsule()
                .fill(Color.white)
                .frame(width: size * 0.14, height: size * 0.16 * blink + size * 0.012)
            Circle()
                .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                .frame(width: size * 0.062, height: size * 0.062 * max(blink, 0.05))
                .offset(x: CGFloat(px) * size * 0.026, y: CGFloat(py) * size * 0.022 * blink)
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.02, height: size * 0.02 * max(blink, 0.05))
                .offset(x: CGFloat(px) * size * 0.026 + size * 0.016,
                        y: CGFloat(py) * size * 0.022 * blink - size * 0.018)
        }
        .frame(width: size * 0.14, height: size * 0.18)
    }

    @ViewBuilder
    private var mouth: some View {
        let ink = Color(red: 0.35, green: 0.16, blue: 0.16)
        switch mood {
        case .surprised, .dizzy:
            Ellipse().fill(ink).frame(width: size * 0.09, height: size * 0.12)
        case .annoyed:
            Smile(openness: -0.45)
                .stroke(ink, style: StrokeStyle(lineWidth: size * 0.024, lineCap: .round))
                .frame(width: size * 0.22, height: size * 0.09)
        case .sleepy:
            Ellipse().fill(ink.opacity(0.85)).frame(width: size * 0.06, height: size * 0.075)
        case .resting:
            Smile(openness: 0.35)
                .stroke(ink, style: StrokeStyle(lineWidth: size * 0.022, lineCap: .round))
                .frame(width: size * 0.20, height: size * 0.08)
        case .happy, .party:
            Smile(openness: 0.9)
                .stroke(ink, style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round))
                .frame(width: size * 0.26, height: size * 0.14)
        default:
            Smile(openness: 0.55)
                .stroke(ink, style: StrokeStyle(lineWidth: size * 0.022, lineCap: .round))
                .frame(width: size * 0.22, height: size * 0.1)
        }
    }

    private var arm: some View {
        VStack(spacing: -size * 0.03) {
            RoundedRectangle(cornerRadius: size * 0.035, style: .continuous)
                .fill(
                    LinearGradient(colors: [Color(red: 0.80, green: 0.94, blue: 0.99),
                                            Color(red: 0.52, green: 0.78, blue: 0.94)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.035, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: size * 0.008)
                )
                .frame(width: size * 0.27, height: size * 0.21)
                .rotationEffect(.degrees(-10))
                .shadow(color: .black.opacity(0.25), radius: size * 0.02, y: size * 0.012)
            Capsule()
                .fill(Color(red: 0.99, green: 0.79, blue: 0.26))
                .overlay(Capsule().strokeBorder(Color(red: 0.86, green: 0.60, blue: 0.14).opacity(0.6),
                                                lineWidth: size * 0.008))
                .frame(width: size * 0.085, height: size * 0.26)
        }
    }

    private func zzz(t: TimeInterval) -> some View {
        let phase = t.truncatingRemainder(dividingBy: 3)
        return HStack(spacing: size * 0.02) {
            ForEach(0..<3, id: \.self) { i in
                Text("z")
                    .font(.system(size: size * (0.08 + CGFloat(i) * 0.03), weight: .bold, design: .rounded))
                    .opacity(phase > Double(i) * 0.7 ? 0.75 : 0.15)
                    .offset(y: -CGFloat(i) * size * 0.05)
            }
        }
        .foregroundStyle(.white)
        .offset(x: size * 0.05, y: -size * 0.02)
    }
}

private struct Smile: Shape {
    var openness: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 2 * openness))
        return p
    }
}
