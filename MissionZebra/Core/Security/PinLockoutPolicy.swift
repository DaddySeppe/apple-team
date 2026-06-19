import Foundation

struct PinLockoutState: Equatable {
    var failedAttempts: Int = 0
    var lockedUntilMillis: Int64 = 0
}

enum PinLockoutPolicy {
    static let maxFailedAttempts = 5
    static let lockoutMillis: Int64 = 5 * 60 * 1000

    static func recordFailure(state: PinLockoutState, nowMillis: Int64) -> PinLockoutState {
        let attempts = state.failedAttempts + 1
        if attempts >= maxFailedAttempts {
            return PinLockoutState(
                failedAttempts: 0,
                lockedUntilMillis: nowMillis + lockoutMillis
            )
        }
        return PinLockoutState(
            failedAttempts: attempts,
            lockedUntilMillis: state.lockedUntilMillis
        )
    }

    static func clear() -> PinLockoutState {
        PinLockoutState()
    }

    static func remainingMillis(state: PinLockoutState, nowMillis: Int64) -> Int64 {
        max(state.lockedUntilMillis - nowMillis, 0)
    }
}
