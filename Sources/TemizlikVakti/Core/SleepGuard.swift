import Foundation
import IOKit.pwr_mgt

/// Temizlik sırasında ekranın uykuya dalmasını engeller.
final class SleepGuard {
    private var assertionID: IOPMAssertionID = 0
    private var active = false

    func begin() {
        guard !active else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Temizlik Vakti — temizlik oturumu" as CFString,
            &assertionID)
        active = (result == kIOReturnSuccess)
    }

    func end() {
        guard active else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        active = false
    }
}
