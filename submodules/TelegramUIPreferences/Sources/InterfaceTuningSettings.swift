import Foundation
import SwiftSignalKit

public struct InterfaceTuningSettings: Codable, Equatable {
    public var concealBottomBar: Bool
    public var showContactsShortcut: Bool
    public var showCallsShortcut: Bool
    public var showTabLabels: Bool
    public var showSearchShortcut: Bool
    public var stretchBottomBar: Bool

    public var showProfileIdentifiers: Bool
    public var showDataCenter: Bool
    public var showRegistrationDate: Bool
    public var showChatCreationDate: Bool

    public var hideStoryStrip: Bool
    public var disableStoryCameraSwipe: Bool
    public var confirmStoryOpen: Bool
    public var allowStoryRepost: Bool

    public var startRoundVideoWithRearCamera: Bool
    public var hidePhoneInSettings: Bool

    public static let defaultSettings = InterfaceTuningSettings(
        concealBottomBar: false,
        showContactsShortcut: true,
        showCallsShortcut: true,
        showTabLabels: true,
        showSearchShortcut: true,
        stretchBottomBar: false,
        showProfileIdentifiers: false,
        showDataCenter: false,
        showRegistrationDate: false,
        showChatCreationDate: false,
        hideStoryStrip: false,
        disableStoryCameraSwipe: false,
        confirmStoryOpen: false,
        allowStoryRepost: true,
        startRoundVideoWithRearCamera: false,
        hidePhoneInSettings: false
    )
}

public final class InterfaceTuningSettingsStore {
    public static let shared = InterfaceTuningSettingsStore()
    public static let didChangeNotification = Notification.Name("InterfaceTuningSettingsStore.didChange")

    private let defaults: UserDefaults
    private let key = "interfaceTuningSettings.v1"
    private let lock = NSLock()
    private var cachedValue: InterfaceTuningSettings

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: self.key), let value = try? JSONDecoder().decode(InterfaceTuningSettings.self, from: data) {
            self.cachedValue = value
        } else {
            self.cachedValue = .defaultSettings
        }
    }

    public var current: InterfaceTuningSettings {
        self.lock.lock()
        if let data = self.defaults.data(forKey: self.key), let value = try? JSONDecoder().decode(InterfaceTuningSettings.self, from: data) {
            self.cachedValue = value
        }
        let value = self.cachedValue
        self.lock.unlock()
        return value
    }

    @discardableResult
    public func update(_ f: (InterfaceTuningSettings) -> InterfaceTuningSettings) -> InterfaceTuningSettings {
        self.lock.lock()
        let currentValue: InterfaceTuningSettings
        if let data = self.defaults.data(forKey: self.key), let value = try? JSONDecoder().decode(InterfaceTuningSettings.self, from: data) {
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

public func interfaceTuningSettingsSignal() -> Signal<InterfaceTuningSettings, NoError> {
    return Signal { subscriber in
        subscriber.putNext(InterfaceTuningSettingsStore.shared.current)
        let observer = NotificationCenter.default.addObserver(
            forName: InterfaceTuningSettingsStore.didChangeNotification,
            object: nil,
            queue: nil,
            using: { _ in
                subscriber.putNext(InterfaceTuningSettingsStore.shared.current)
            }
        )
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    |> distinctUntilChanged
}
