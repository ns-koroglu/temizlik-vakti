import SwiftUI

/// Küçük bir kullanım defteri. Tamamen yerel (UserDefaults), hiçbir yere gönderilmez.
@MainActor
final class Stats: ObservableObject {
    static let shared = Stats()
    private let d = UserDefaults.standard

    @Published private(set) var sessions: Int
    @Published private(set) var totalSeconds: Double
    @Published private(set) var blockedInputs: Int
    @Published private(set) var perfectRuns: Int
    @Published private(set) var breaksCompleted: Int

    var isEmpty: Bool { sessions == 0 && breaksCompleted == 0 }

    private init() {
        sessions = d.integer(forKey: "stat.sessions")
        totalSeconds = d.double(forKey: "stat.totalSeconds")
        blockedInputs = d.integer(forKey: "stat.blockedInputs")
        perfectRuns = d.integer(forKey: "stat.perfectRuns")
        breaksCompleted = d.integer(forKey: "stat.breaksCompleted")
    }

    func recordCleaning(seconds: Double, blocked: Int, perfect: Bool) {
        sessions += 1
        totalSeconds += max(0, seconds)
        blockedInputs += max(0, blocked)
        if perfect { perfectRuns += 1 }
        persist()
    }

    func recordBreak() {
        breaksCompleted += 1
        persist()
    }

    func reset() {
        sessions = 0; totalSeconds = 0; blockedInputs = 0
        perfectRuns = 0; breaksCompleted = 0
        persist()
    }

    private func persist() {
        d.set(sessions, forKey: "stat.sessions")
        d.set(totalSeconds, forKey: "stat.totalSeconds")
        d.set(blockedInputs, forKey: "stat.blockedInputs")
        d.set(perfectRuns, forKey: "stat.perfectRuns")
        d.set(breaksCompleted, forKey: "stat.breaksCompleted")
    }

    /// "1 sa 23 dk" / "4 dk"
    func totalTimeText(_ strings: TVStrings) -> String {
        let total = Int(totalSeconds.rounded())
        if total >= 3600 {
            return String(format: strings.countdownHoursMinutes, total / 3600, (total % 3600) / 60)
        }
        let minutes = max(1, total / 60)
        return minutes == 1 ? strings.minutesChoiceOne : String(format: strings.minutesChoice, minutes)
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = (info?["CFBundleShortVersionString"] as? String) ?? "1.0"
        let build = (info?["CFBundleVersion"] as? String) ?? "1"
        return "\(short) (\(build))"
    }
}
