import Foundation
import SwiftSignalKit

public final class MadJSONStore<Value: Codable & Equatable> {
    public let didChangeNotification: Notification.Name
    private let key: String
    private let defaultValue: Value
    private let lock = NSLock()
    private var cachedValue: Value

    public init(key: String, defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue
        self.didChangeNotification = Notification.Name("MadJSONStore.\(key)")
        if let data = UserDefaults.standard.data(forKey: key), let value = try? JSONDecoder().decode(Value.self, from: data) {
            self.cachedValue = value
        } else {
            self.cachedValue = defaultValue
        }
    }

    public var current: Value {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.cachedValue
    }

    @discardableResult
    public func update(_ f: (Value) -> Value) -> Value {
        self.lock.lock()
        let updated = f(self.cachedValue)
        let changed = updated != self.cachedValue
        self.cachedValue = updated
        if let data = try? JSONEncoder().encode(updated) {
            UserDefaults.standard.set(data, forKey: self.key)
        }
        self.lock.unlock()
        if changed {
            NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
        }
        return updated
    }

    public func reload() {
        self.lock.lock()
        if let data = UserDefaults.standard.data(forKey: self.key), let value = try? JSONDecoder().decode(Value.self, from: data) {
            self.cachedValue = value
        } else {
            self.cachedValue = self.defaultValue
        }
        self.lock.unlock()
        NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
    }

    public func signal() -> Signal<Value, NoError> {
        let store = self
        return Signal { subscriber in
            subscriber.putNext(store.current)
            let observer = NotificationCenter.default.addObserver(forName: store.didChangeNotification, object: nil, queue: nil, using: { _ in
                subscriber.putNext(store.current)
            })
            return ActionDisposable {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        |> distinctUntilChanged
    }
}

public enum MadStores {
    public static let peerAliases = MadJSONStore<[Int64: String]>(key: "madgram.peerAliases.v1", defaultValue: [:])
    public static let lockedChats = MadJSONStore<Set<Int64>>(key: "madgram.lockedChats.v1", defaultValue: [])
    public static let presenceWatched = MadJSONStore<Set<Int64>>(key: "madgram.presenceWatched.v1", defaultValue: [])

    public static let backupKeys: [String] = [
        "interfaceTuningSettings.v1",
        "chatContentFilterSettings.v1",
        "messageFilterSettings.v1",
        "localPremiumSettings.v1",
        "localPremiumOverride.emojiStatuses.v1",
        "madgram.agent.settings.v1",
        "madgram.companion.look.v1",
        "madgram.companion.placement.v1",
        "madgram.peerAliases.v1",
        "madgram.lockedChats.v1",
        "madgram.presenceWatched.v1"
    ]

    public static func alias(peerId: Int64) -> String? {
        if let value = peerAliases.current[peerId], !value.isEmpty {
            return value
        }
        return nil
    }
}

public final class MadChatLockSession {
    public static let shared = MadChatLockSession()

    private let lock = NSLock()
    private var unlocked = Set<Int64>()

    public func isLocked(peerId: Int64) -> Bool {
        guard MadStores.lockedChats.current.contains(peerId) else {
            return false
        }
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return !self.unlocked.contains(peerId)
    }

    public func isLockedChat(peerId: Int64) -> Bool {
        return MadStores.lockedChats.current.contains(peerId)
    }

    public func markUnlocked(peerId: Int64) {
        self.lock.lock()
        self.unlocked.insert(peerId)
        self.lock.unlock()
    }

    public func lockAll() {
        self.lock.lock()
        self.unlocked.removeAll()
        self.lock.unlock()
    }
}
