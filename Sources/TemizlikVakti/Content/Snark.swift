import Foundation

/// Metinler artık dile göre TVStrings içinde tutuluyor; burada yalnızca
/// "aynısını art arda gösterme" mantığı kaldı.
enum Snark {
    static func random(from list: [String], avoiding current: String?) -> String {
        guard let first = list.first else { return "" }
        guard list.count > 1 else { return first }
        var pick = list.randomElement()!
        var guardCount = 0
        while pick == current, guardCount < 8 {
            pick = list.randomElement()!
            guardCount += 1
        }
        return pick
    }
}
