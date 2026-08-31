import SwiftUI

struct BreakScreenView: View {
    let isPrimary: Bool
    @EnvironmentObject var session: BreakSession
    @EnvironmentObject var prefs: Prefs

    private var theme: ShieldTheme { prefs.theme }

    var body: some View {
        ZStack {
            theme.gradient.ignoresSafeArea()
            if prefs.bubbles {
                BubbleField(count: isPrimary ? 16 : 8,
                            tint: theme == .light ? Color(red: 0.3, green: 0.5, blue: 0.8) : .white)
                    .ignoresSafeArea()
            }
            if isPrimary { primary } else { secondary }
        }
        .foregroundStyle(theme.fg)
        .animation(.easeInOut(duration: 0.25), value: session.phase)
    }

    @ViewBuilder
    private var primary: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 0)

            if prefs.mascot {
                MascotView(mood: session.phase == .finished ? .happy : .resting, size: 150)
            }

            if session.phase == .finished {
                VStack(spacing: 10) {
                    Text("Mola bitti")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                    Text(session.tip)
                        .font(.system(size: 18, design: .rounded))
                        .opacity(0.8)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 22) {
                    Text("Göz Molası")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .opacity(0.75)

                    ring

                    Text(session.tip)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 620)
                        .opacity(0.9)
                }
            }

            Spacer(minLength: 0)

            if session.phase == .resting { controls.padding(.bottom, 46) }
        }
        .padding(40)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(theme.fg.opacity(0.12), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.001, session.progress))
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(ceil(session.remaining)))")
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: Int(ceil(session.remaining)))
        }
        .frame(width: 190, height: 190)
    }

    @ViewBuilder
    private var controls: some View {
        if prefs.breakStrict && Permissions.hasAccessibility {
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
                        Text(session.unlockProgress > 0.02 ? "Bırakma…" : "Molayı geçmek için basılı tut")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(width: 340, height: 46)
                .overlay(Capsule().strokeBorder(theme.fg.opacity(0.16), lineWidth: 1))
                .clipShape(Capsule())
                .animation(.linear(duration: 0.05), value: session.unlockProgress)

                Text("Katı mod açık · klavye ve trackpad kilitli")
                    .font(.system(size: 11, design: .rounded))
                    .opacity(0.45)
            }
        } else {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button("5 dk ertele") { session.snooze(minutes: 5) }
                    Button("Molayı geç") { session.endBreak(completed: false) }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(theme.accent)

                Text("esc tuşu da molayı geçer")
                    .font(.system(size: 11, design: .rounded))
                    .opacity(0.45)
            }
        }
    }

    private var secondary: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye")
                .font(.system(size: 38))
                .opacity(0.5)
            Text("Göz Molası")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .opacity(0.7)
            Text("\(Int(ceil(session.remaining)))")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .opacity(0.55)
        }
    }
}
