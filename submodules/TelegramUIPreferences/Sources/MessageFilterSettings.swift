import Foundation
import SwiftSignalKit

public struct MessageFilterSettings: Codable, Equatable {
    public var hideBlockedUsersMessages: Bool
    public var shadowBannedPeerIds: Set<Int64>
    public var blockedPeerIdsCache: Set<Int64>

    public static let defaultSettings = MessageFilterSettings(
        hideBlockedUsersMessages: false,
        shadowBannedPeerIds: [],
        blockedPeerIdsCache: []
    )

    public init(hideBlockedUsersMessages: Bool, shadowBannedPeerIds: Set<Int64>, blockedPeerIdsCache: Set<Int64>) {
        self.hideBlockedUsersMessages = hideBlockedUsersMessages
        self.shadowBannedPeerIds = shadowBannedPeerIds
        self.blockedPeerIdsCache = blockedPeerIdsCache
    }

    public var isActive: Bool {
        return !self.shadowBannedPeerIds.isEmpty || (self.hideBlockedUsersMessages && !self.blockedPeerIdsCache.isEmpty)
    }

    public func hidesMessages(fromAuthorId authorId: Int64) -> Bool {
        if self.shadowBannedPeerIds.contains(authorId) {
            return true
        }
        if self.hideBlockedUsersMessages && self.blockedPeerIdsCache.contains(authorId) {
            return true
        }
        return false
    }

    public func isShadowBanned(_ authorId: Int64) -> Bool {
        return self.shadowBannedPeerIds.contains(authorId)
    }

    public func paginationAnchor<T>(visible: T?, unfiltered: T?) -> T? {
        if self.isActive {
            return unfiltered ?? visible
        } else {
            return visible
        }
    }
}

public final class MessageFilterSettingsStore {
    public static let shared = MessageFilterSettingsStore()
    public static let didChangeNotification = Notification.Name("MessageFilterSettingsStore.didChange")

    private let defaults: UserDefaults
    private let key = "messageFilterSettings.v1"
    private let lock = NSLock()
    private var cachedValue: MessageFilterSettings

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: self.key), let value = try? JSONDecoder().decode(MessageFilterSettings.self, from: data) {
            self.cachedValue = value
        } else {
            self.cachedValue = .defaultSettings
        }
    }

    public var current: MessageFilterSettings {
        self.lock.lock()
        if let data = self.defaults.data(forKey: self.key), let value = try? JSONDecoder().decode(MessageFilterSettings.self, from: data) {
            self.cachedValue = value
        }
        let value = self.cachedValue
        self.lock.unlock()
        return value
    }

    @discardableResult
    public func update(_ f: (MessageFilterSettings) -> MessageFilterSettings) -> MessageFilterSettings {
        self.lock.lock()
        let currentValue: MessageFilterSettings
        if let data = self.defaults.data(forKey: self.key), let value = try? JSONDecoder().decode(MessageFilterSettings.self, from: data) {
            currentValue = value
        } else {
            currentValue = self.cachedValue
        }
        let updatedValue = f(currentValue)
        let changed = updatedValue != currentValue
        self.cachedValue = updatedValue
        if let data = try? JSONEncoder().encode(updatedValue) {
            self.defaults.set(data, forKey: self.key)
        }
        self.lock.unlock()

        if changed {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
        return updatedValue
    }

    @discardableResult
    public func toggleShadowBan(peerId: Int64) -> Bool {
        var isHidden = false
        self.update { current in
            var current = current
            if current.shadowBannedPeerIds.contains(peerId) {
                current.shadowBannedPeerIds.remove(peerId)
                isHidden = false
            } else {
                current.shadowBannedPeerIds.insert(peerId)
                isHidden = true
            }
            return current
        }
        return isHidden
    }
}

public func messageFilterSettingsSignal() -> Signal<MessageFilterSettings, NoError> {
    return Signal { subscriber in
        subscriber.putNext(MessageFilterSettingsStore.shared.current)
        let observer = NotificationCenter.default.addObserver(
            forName: MessageFilterSettingsStore.didChangeNotification,
            object: nil,
            queue: nil,
            using: { _ in
                subscriber.putNext(MessageFilterSettingsStore.shared.current)
            }
        )
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    |> distinctUntilChanged
}
