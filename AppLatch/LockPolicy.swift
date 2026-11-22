import Foundation

// Runtime-only grants. Never persist authorization across launches.
struct LockPolicy {
    private(set) var grants: [String: TimeInterval] = [:]
    private(set) var generation = UUID()

    mutating func grant(_ id: String, seconds: TimeInterval, now: TimeInterval) {
        grants[id] = now + max(0, seconds)
    }

    func isUnlocked(_ id: String, now: TimeInterval) -> Bool {
        guard let expiry = grants[id] else { return false }
        return now < expiry
    }

    func remaining(_ id: String, now: TimeInterval) -> TimeInterval {
        max(0, (grants[id] ?? now) - now)
    }

    mutating func revoke(_ id: String) { grants.removeValue(forKey: id) }

    mutating func lockAll() {
        grants.removeAll()
        generation = UUID()
    }
}
