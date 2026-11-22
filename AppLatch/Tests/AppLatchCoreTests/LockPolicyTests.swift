import XCTest
@testable import AppLatchCore

final class LockPolicyTests: XCTestCase {
    func testExpiryIsInclusiveAndGrantsArePerApp() {
        var policy = LockPolicy()
        policy.grant("notes", seconds: 60, now: 100)
        XCTAssertTrue(policy.isUnlocked("notes", now: 159.9))
        XCTAssertFalse(policy.isUnlocked("notes", now: 160))
        XCTAssertFalse(policy.isUnlocked("mail", now: 101))
        XCTAssertEqual(policy.remaining("notes", now: 170), 0)
    }

    func testLockAllInvalidatesPendingAuthenticationGeneration() {
        var policy = LockPolicy()
        let generation = policy.generation
        policy.grant("notes", seconds: 900, now: 100)
        policy.lockAll()
        XCTAssertNotEqual(generation, policy.generation)
        XCTAssertFalse(policy.isUnlocked("notes", now: 101))
    }

    func testRevokeAndNonPositiveDuration() {
        var policy = LockPolicy()
        policy.grant("notes", seconds: 60, now: 0)
        policy.grant("mail", seconds: 60, now: 0)
        policy.revoke("notes")
        XCTAssertFalse(policy.isUnlocked("notes", now: 1))
        XCTAssertTrue(policy.isUnlocked("mail", now: 1))
        policy.grant("notes", seconds: -1, now: 0)
        XCTAssertFalse(policy.isUnlocked("notes", now: 0))
    }
}
