import Foundation

/// Reservations cover the asynchronous database and notification-center work. A failed
/// request can be retried; a callback from a cancelled reservation cannot commit a newer one.
final class LocalNotificationDeliveryState {
    private let limit: Int
    private let lifetime: TimeInterval
    private var sequence: UInt64 = 0
    private var pending: [String: UInt64] = [:]
    private var delivered: [String: TimeInterval] = [:]

    init(limit: Int = 400, lifetime: TimeInterval = 300.0) {
        self.limit = limit
        self.lifetime = lifetime
    }

    func reserve(_ key: String, now: TimeInterval) -> UInt64? {
        self.delivered = self.delivered.filter { now - $0.value < self.lifetime }
        guard self.pending[key] == nil, self.delivered[key] == nil, self.pending.count < self.limit else {
            return nil
        }
        self.sequence &+= 1
        self.pending[key] = self.sequence
        return self.sequence
    }

    func isPending(_ key: String, token: UInt64) -> Bool {
        return self.pending[key] == token
    }

    func complete(_ key: String, token: UInt64, delivered: Bool, now: TimeInterval) {
        guard self.isPending(key, token: token) else {
            return
        }
        self.pending.removeValue(forKey: key)
        if delivered {
            self.delivered[key] = now
            if self.delivered.count > self.limit, let oldest = self.delivered.min(by: { $0.value < $1.value })?.key {
                self.delivered.removeValue(forKey: oldest)
            }
        }
    }

    func wasDelivered(_ key: String, now: TimeInterval) -> Bool {
        guard let deliveredAt = self.delivered[key] else {
            return false
        }
        return now - deliveredAt < self.lifetime
    }

    func cancelPending() {
        self.pending.removeAll()
    }
}
