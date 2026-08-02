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
    public var hideGalleryCamera: Bool?
    public var hidePhoneInSettings: Bool
    public var hideBusinessBotPanel: Bool
    public var businessBotPanelVisibilityOverrides: [Int64: Bool]

    public init(
        concealBottomBar: Bool,
        showContactsShortcut: Bool,
        showCallsShortcut: Bool,
        showTabLabels: Bool,
        showSearchShortcut: Bool,
        stretchBottomBar: Bool,
        showProfileIdentifiers: Bool,
        showDataCenter: Bool,
        showRegistrationDate: Bool,
        showChatCreationDate: Bool,
        hideStoryStrip: Bool,
        disableStoryCameraSwipe: Bool,
        confirmStoryOpen: Bool,
        allowStoryRepost: Bool,
        startRoundVideoWithRearCamera: Bool,
        hideGalleryCamera: Bool?,
        hidePhoneInSettings: Bool,
        hideBusinessBotPanel: Bool = false,
        businessBotPanelVisibilityOverrides: [Int64: Bool] = [:]
    ) {
        self.concealBottomBar = concealBottomBar
        self.showContactsShortcut = showContactsShortcut
        self.showCallsShortcut = showCallsShortcut
        self.showTabLabels = showTabLabels
        self.showSearchShortcut = showSearchShortcut
        self.stretchBottomBar = stretchBottomBar
        self.showProfileIdentifiers = showProfileIdentifiers
        self.showDataCenter = showDataCenter
        self.showRegistrationDate = showRegistrationDate
        self.showChatCreationDate = showChatCreationDate
        self.hideStoryStrip = hideStoryStrip
        self.disableStoryCameraSwipe = disableStoryCameraSwipe
        self.confirmStoryOpen = confirmStoryOpen
        self.allowStoryRepost = allowStoryRepost
        self.startRoundVideoWithRearCamera = startRoundVideoWithRearCamera
        self.hideGalleryCamera = hideGalleryCamera
        self.hidePhoneInSettings = hidePhoneInSettings
        self.hideBusinessBotPanel = hideBusinessBotPanel
        self.businessBotPanelVisibilityOverrides = businessBotPanelVisibilityOverrides
    }

    private enum CodingKeys: String, CodingKey {
        case concealBottomBar, showContactsShortcut, showCallsShortcut, showTabLabels, showSearchShortcut, stretchBottomBar
        case showProfileIdentifiers, showDataCenter, showRegistrationDate, showChatCreationDate
        case hideStoryStrip, disableStoryCameraSwipe, confirmStoryOpen, allowStoryRepost
        case startRoundVideoWithRearCamera, hideGalleryCamera, hidePhoneInSettings
        case hideBusinessBotPanel, businessBotPanelVisibilityOverrides
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.concealBottomBar = try container.decodeIfPresent(Bool.self, forKey: .concealBottomBar) ?? false
        self.showContactsShortcut = try container.decodeIfPresent(Bool.self, forKey: .showContactsShortcut) ?? true
        self.showCallsShortcut = try container.decodeIfPresent(Bool.self, forKey: .showCallsShortcut) ?? true
        self.showTabLabels = try container.decodeIfPresent(Bool.self, forKey: .showTabLabels) ?? true
        self.showSearchShortcut = try container.decodeIfPresent(Bool.self, forKey: .showSearchShortcut) ?? true
        self.stretchBottomBar = try container.decodeIfPresent(Bool.self, forKey: .stretchBottomBar) ?? false
        self.showProfileIdentifiers = try container.decodeIfPresent(Bool.self, forKey: .showProfileIdentifiers) ?? false
        self.showDataCenter = try container.decodeIfPresent(Bool.self, forKey: .showDataCenter) ?? false
        self.showRegistrationDate = try container.decodeIfPresent(Bool.self, forKey: .showRegistrationDate) ?? false
        self.showChatCreationDate = try container.decodeIfPresent(Bool.self, forKey: .showChatCreationDate) ?? false
        self.hideStoryStrip = try container.decodeIfPresent(Bool.self, forKey: .hideStoryStrip) ?? false
        self.disableStoryCameraSwipe = try container.decodeIfPresent(Bool.self, forKey: .disableStoryCameraSwipe) ?? false
        self.confirmStoryOpen = try container.decodeIfPresent(Bool.self, forKey: .confirmStoryOpen) ?? false
        self.allowStoryRepost = try container.decodeIfPresent(Bool.self, forKey: .allowStoryRepost) ?? true
        self.startRoundVideoWithRearCamera = try container.decodeIfPresent(Bool.self, forKey: .startRoundVideoWithRearCamera) ?? false
        self.hideGalleryCamera = try container.decodeIfPresent(Bool.self, forKey: .hideGalleryCamera) ?? false
        self.hidePhoneInSettings = try container.decodeIfPresent(Bool.self, forKey: .hidePhoneInSettings) ?? false
        self.hideBusinessBotPanel = try container.decodeIfPresent(Bool.self, forKey: .hideBusinessBotPanel) ?? false
        self.businessBotPanelVisibilityOverrides = try container.decodeIfPresent([Int64: Bool].self, forKey: .businessBotPanelVisibilityOverrides) ?? [:]
    }

    public func isBusinessBotPanelVisible(peerId: Int64) -> Bool {
        if let value = self.businessBotPanelVisibilityOverrides[peerId] {
            return value
        }
        return !self.hideBusinessBotPanel
    }

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
        hideGalleryCamera: false,
        hidePhoneInSettings: false,
        hideBusinessBotPanel: false,
        businessBotPanelVisibilityOverrides: [:]
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
