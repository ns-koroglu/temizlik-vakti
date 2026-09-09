import SwiftUI

extension ShieldTheme {
    var gradient: LinearGradient {
        switch self {
        case .dark:
            return LinearGradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.08),
                                           Color(red: 0.02, green: 0.02, blue: 0.03)],
                                  startPoint: .top, endPoint: .bottom)
        case .light:
            return LinearGradient(colors: [Color(red: 0.97, green: 0.97, blue: 0.98),
                                           Color(red: 0.88, green: 0.90, blue: 0.93)],
                                  startPoint: .top, endPoint: .bottom)
        case .gradient:
            return LinearGradient(colors: [Color(red: 0.16, green: 0.11, blue: 0.35),
                                           Color(red: 0.09, green: 0.24, blue: 0.42),
                                           Color(red: 0.05, green: 0.35, blue: 0.44)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    var fg: Color { self == .light ? Color(red: 0.10, green: 0.11, blue: 0.14) : .white }
    var accent: Color {
        switch self {
        case .dark: return Color(red: 1.0, green: 0.80, blue: 0.30)
        case .light: return Color(red: 0.12, green: 0.45, blue: 0.90)
        case .gradient: return Color(red: 0.45, green: 0.95, blue: 0.85)
        }
    }
}

struct LockScreenView: View {
    let isPrimary: Bool
    @EnvironmentObject var session: LockSession
    @EnvironmentObject var prefs: Prefs

    @EnvironmentObject var l10n: L10n
    @State private var showBurst = false

    private var theme: ShieldTheme { prefs.theme }
    private var str: TVStrings { l10n.s }

    var body: some View {
        ZStack {
            theme.gradient.ignoresSafeArea()
            if session.egg == .party { partyGlow }
            if prefs.bubbles {
                BubbleField(count: isPrimary ? 22 : 10,
                            tint: theme == .light ? Color(red: 0.3, green: 0.5, blue: 0.8) : .white)
                    .ignoresSafeArea()
            }

            if isPrimary {
                primaryContent
            } else {
                secondaryContent
            }

            if showBurst { SparkleBurst(tint: theme.accent).allowsHitTesting(false) }
        }
        .onChange(of: session.sparkleBurst) { _, _ in
            showBurst = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showBurst = false }
        }
        .foregroundStyle(theme.fg)
        .animation(.easeInOut(duration: 0.25), value: session.phase)
    }

    // MARK: - Ana ekran

    @ViewBuilder
    private var primaryContent: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)

            if prefs.mascot {
                MascotView(mood: mood, size: 190,
                           gaze: session.gaze,
                           liveMouse: session.isPreview)
                    .accessibilityHidden(true)
                    .modifier(Shake(animatableData: CGFloat(session.nudgeCount)))
                    .animation(.spring(response: 0.35, dampingFraction: 0.35), value: session.nudgeCount)
            }

            switch session.phase {
            case .preroll:
                prerollBlock
            case .finished:
                finishedBlock
            default:
                runningBlock
            }

            Spacer(minLength: 0)

            if session.phase == .running || session.phase == .preroll {
                unlockHint
                    .padding(.bottom, 46)
            }
        }
        .padding(40)
        .overlay(alignment: .top) {
            titleBadge.padding(.top, 34)
        }
    }

    private var titleBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
            Text("Temizlik Vakti")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(0.85)
    }

    @ViewBuilder
    private var prerollBlock: some View {
        VStack(spacing: 14) {
            Text("\(max(1, Int(ceil(session.prerollRemaining))))")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: Int(ceil(session.prerollRemaining)))
            Text(session.line)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .opacity(0.85)
        }
    }

    @ViewBuilder
    private var runningBlock: some View {
        VStack(spacing: 18) {
            Text(session.duration > 0
                 ? LockSession.clock(session.remaining)
                 : LockSession.clock(session.elapsed))
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .monospacedDigit()
                .accessibilityLabel(session.duration > 0
                                    ? LockSession.clock(session.remaining)
                                    : LockSession.clock(session.elapsed))

            if session.duration > 0 {
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.fg.opacity(0.14))
                    Capsule().fill(theme.accent)
                        .frame(width: max(6, 300 * session.progressFraction))
                }
                .frame(width: 300, height: 8)
            } else {
                Text(str.unlimitedSession)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .opacity(0.6)
            }

            ZStack {
                if let eggMsg = session.eggMessage {
                    Text(eggMsg)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.accent)
                        .transition(.scale.combined(with: .opacity))
                } else if let nudge = session.nudgeLine {
                    Text(nudge)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.accent)
                        .transition(.scale.combined(with: .opacity))
                } else if prefs.snark {
                    Text(session.line)
                        .font(.system(size: 19, weight: .regular, design: .rounded))
                        .opacity(0.8)
                        .transition(.opacity)
                        .id(session.line)
                }
            }
            .multilineTextAlignment(.center)
            .frame(height: 32)
            .animation(.easeInOut(duration: 0.3), value: session.nudgeLine)
            .animation(.easeInOut(duration: 0.3), value: session.eggMessage)
            .animation(.easeInOut(duration: 0.4), value: session.line)
        }
    }

    @ViewBuilder
    private var finishedBlock: some View {
        VStack(spacing: 12) {
            Text(str.allClean)
                .font(.system(size: 56, weight: .bold, design: .rounded))
            Text(session.line)
                .font(.system(size: 19, design: .rounded))
                .opacity(0.85)
            if session.perfectRun {
                Label(str.perfectRun, systemImage: "rosette")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(theme.accent.opacity(0.25), in: Capsule())
            }
            if session.elapsed > 1 {
                Text(String(format: str.sessionSummary, LockSession.clock(session.elapsed), session.pokeCount))
                    .font(.system(size: 13, design: .rounded))
                    .opacity(0.6)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Kilit açma ipucu

    private var unlockHint: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .leading) {
                Capsule().fill(theme.fg.opacity(0.09))
                Capsule()
                    .fill(theme.accent.opacity(0.45))
                    .frame(width: max(0, 340 * session.unlockProgress))
                HStack(spacing: 10) {
                    Text("esc")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(theme.fg.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                    Text(session.unlockProgress > 0.02 ? str.unlockHolding : str.unlockHold)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: 340, height: 46)
            .overlay(Capsule().strokeBorder(theme.fg.opacity(0.16), lineWidth: 1))
            .clipShape(Capsule())
            .animation(.linear(duration: 0.05), value: session.unlockProgress)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(str.unlockHold)
            .accessibilityValue("\(Int(session.unlockProgress * 100))%")

            // Önizlemede giriş kilitli DEĞİL; "kilitli" demek kullanıcıyı
            // gerçekten silmeye başlaması için yanlış yönlendiriyordu.
            Text(session.isPreview ? str.previewFooterNote : str.lockFooterNote)
                .font(.system(size: 11, weight: session.isPreview ? .semibold : .regular, design: .rounded))
                .opacity(session.isPreview ? 0.8 : 0.45)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - İkincil ekranlar

    private var secondaryContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .opacity(0.5)
            Text("Temizlik Vakti")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .opacity(0.7)
            Text(session.duration > 0
                 ? LockSession.clock(session.remaining)
                 : LockSession.clock(session.elapsed))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .opacity(0.55)

            // Kaçış yolu her ekranda görünmeli: kullanıcı ikincil ekrana bakıyor olabilir.
            Text(session.isPreview ? str.previewFooterNote : str.unlockHold)
                .font(.system(size: 12, design: .rounded))
                .multilineTextAlignment(.center)
                .opacity(0.45)
                .padding(.horizontal, 30)
        }
    }

    private var mood: MascotMood {
        if session.phase == .finished { return .happy }
        switch session.egg {
        case .party: return .party
        case .annoyed: return .annoyed
        case .dizzy: return .dizzy
        case .sleepy: return .sleepy
        case .caps, .secret: return .surprised
        case nil: break
        }
        if session.nudgeLine != nil { return .surprised }
        if session.phase == .preroll { return .ready }
        return .wiping
    }

    /// Konami kodundan sonra açılan parti fonu
    private var partyGlow: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            LinearGradient(colors: [Color(hue: (t * 0.12).truncatingRemainder(dividingBy: 1),
                                          saturation: 0.75, brightness: 0.55),
                                    Color(hue: (t * 0.12 + 0.35).truncatingRemainder(dividingBy: 1),
                                          saturation: 0.75, brightness: 0.4)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            .opacity(0.75)
        }
        .ignoresSafeArea()
    }
}
