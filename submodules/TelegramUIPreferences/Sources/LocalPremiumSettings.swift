import Foundation
import SwiftSignalKit

public struct LocalPremiumSettings: Codable, Equatable {
    public var isEnabled: Bool

    public static let defaultSettings = LocalPremiumSettings(isEnabled: false)

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

public final class LocalPremiumSettingsStore {
    public static let shared = LocalPremiumSettingsStore()
    public static let didChangeNotification = Notification.Name("LocalPremiumSettingsStore.didChange")

    private let defaults: UserDefaults
    private let key = "localPremiumSettings.v1"
    private let lock = NSLock()
    private var cachedValue: LocalPremiumSettings

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: self.key), let value = try? JSONDecoder().decode(LocalPremiumSettings.self, from: data) {
            self.cachedValue = value
        } else {
            self.cachedValue = .defaultSettings
        }
    }

    public var current: LocalPremiumSettings {
        self.lock.lock()
        if let data = self.defaults.data(forKey: self.key), let value = try? JSONDecoder().decode(LocalPremiumSettings.self, from: data) {
            self.cachedValue = value
        }
        let value = self.cachedValue
        self.lock.unlock()
        return value
    }

    @discardableResult
    public func update(_ f: (LocalPremiumSettings) -> LocalPremiumSettings) -> LocalPremiumSettings {
        self.lock.lock()
        let currentValue: LocalPremiumSettings
        if let data = self.defaults.data(forKey: self.key), let value = try? JSONDecoder().decode(LocalPremiumSettings.self, from: data) {
            currentValue = value
        } else {
            currentValue = self.cachedValue
        }
        let updatedValue = f(currentValue)
        self.cachedValue = updatedValue
        if let data = try? JSONEncoder().encode(updatedValue) {
            self.defaults.set(data, forKey: self.key)
        }
        self.lock.unlock()

        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        return updatedValue
    }
}

public func localPremiumSettingsSignal() -> Signal<LocalPremiumSettings, NoError> {
    return Signal { subscriber in
        subscriber.putNext(LocalPremiumSettingsStore.shared.current)
        let observer = NotificationCenter.default.addObserver(
            forName: LocalPremiumSettingsStore.didChangeNotification,
            object: nil,
            queue: nil,
            using: { _ in
                subscriber.putNext(LocalPremiumSettingsStore.shared.current)
            }
        )
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    |> distinctUntilChanged
}
