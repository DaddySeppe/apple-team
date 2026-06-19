import XCTest
@testable import MissionZebra

final class PinSecurityTests: XCTestCase {
    func testPBKDF2HashVerifiesAndRejectsWrongPin() {
        let salt = PinSecurity.generateSalt()
        let hash = PinSecurity.hashPin("1234", salt: salt)

        XCTAssertTrue(PinSecurity.isVersionedHash(hash))
        XCTAssertTrue(PinSecurity.verifyPin("1234", salt: salt, expectedHash: hash))
        XCTAssertFalse(PinSecurity.verifyPin("0000", salt: salt, expectedHash: hash))
    }

    func testLegacySHA256HashStillVerifies() {
        let salt = "00112233445566778899aabbccddeeff"
        let legacyHash = "3abe1c65e4a0391c03d1634b29a2e8f6fa520bfa66363275a7431b1b4109eff1"

        XCTAssertTrue(PinSecurity.verifyPin("1234", salt: salt, expectedHash: legacyHash))
    }

    func testLockoutAfterFiveFailures() {
        var state = PinLockoutState()
        let now: Int64 = 1_000

        for attempt in 1..<PinLockoutPolicy.maxFailedAttempts {
            state = PinLockoutPolicy.recordFailure(state: state, nowMillis: now)
            XCTAssertEqual(state.failedAttempts, attempt)
            XCTAssertEqual(state.lockedUntilMillis, 0)
        }

        state = PinLockoutPolicy.recordFailure(state: state, nowMillis: now)
        XCTAssertEqual(state.failedAttempts, 0)
        XCTAssertEqual(state.lockedUntilMillis, now + PinLockoutPolicy.lockoutMillis)
        XCTAssertEqual(PinLockoutPolicy.remainingMillis(state: state, nowMillis: now), PinLockoutPolicy.lockoutMillis)
    }
}
