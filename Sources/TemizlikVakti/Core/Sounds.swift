import AppKit

enum Sounds {
    static var enabled: Bool = true

    private static func play(_ name: String, volume: Float = 0.6) {
        guard enabled, let s = NSSound(named: NSSound.Name(name)) else { return }
        s.volume = volume
        s.play()
    }

    static func lock()    { play("Submarine", volume: 0.5) }
    static func unlock()  { play("Glass", volume: 0.6) }
    static func blocked() { play("Tink", volume: 0.25) }
    static func tick()    { play("Pop", volume: 0.2) }
}
