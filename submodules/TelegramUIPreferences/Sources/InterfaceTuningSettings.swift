import Foundation
import SwiftSignalKit

public enum MadSubToggle: String, CaseIterable {
    case birthdaysChatList
    case birthdaysChat
    case birthdaysProfile
    case aiInput
    case aiSummaries
    case staticAvatarsChatList
    case staticAvatarsChats
    case staticAvatarsProfile
    case similarInChat
    case similarInProfile
    case similarBots
    case viewOnceVoice
    case viewOnceRounds
    case foreignAgentMessages
    case foreignAgentChatList
    case hiddenRulesChats
    case hiddenRulesChatList
    case hiddenRulesNotifications
    case phoneOthers
    case phoneMine
    case joinDateMine
    case joinDateMembers
    case spendReactions
    case spendMessages
    case spendGifts
    case spendTransfer
    case spendPayments
    case spoilersPrivate
    case spoilersGroups
    case spoilersChannels
    case spoilersSaved
    case spoilersProfileMedia

    public var defaultValue: Bool {
        switch self {
        case .spoilersSaved:
            return false
        default:
            return true
        }
    }
}

public struct InterfaceTuningSettings: Codable, Equatable {
    public var concealBottomBar: Bool
    public var showContactsShortcut: Bool
    public var showCallsShortcut: Bool
    public var showTabLabels: Bool
    public var showSearchShortcut: Bool
    public var stretchBottomBar: Bool
    public var showAppBadge: Bool
    public var classicDesign: Bool

    public var showProfileIdentifiers: Bool
    public var showDataCenter: Bool
    public var showRegistrationDate: Bool
    public var showChatCreationDate: Bool

    public var showCallbackData: Bool

    public var hideStoryStrip: Bool
    public var disableStoryCameraSwipe: Bool
    public var confirmStoryOpen: Bool
    public var allowStoryRepost: Bool

    public var startRoundVideoWithRearCamera: Bool
    public var hideGalleryCamera: Bool?
    public var hidePhoneInSettings: Bool
    public var hideBusinessBotPanel: Bool
    public var businessBotPanelVisibilityOverrides: [Int64: Bool]
    public var showOnlineInGroups: Bool
    public var showSecondsInMessages: Bool
    public var showSecondsInLastSeen: Bool
    public var showExactViewCounts: Bool
    public var showChatCompanion: Bool
    public var showAgentTab: Bool
    public var hideVoiceRecordButton: Bool
    public var hidePinnedMessageBar: Bool
    public var forceViewOnceVoice: Bool
    public var hideGiftInputButton: Bool
    public var hideSimilarChannels: Bool
    public var hideBirthdays: Bool
    public var disableTelegramAI: Bool
    public var disableTonWallet: Bool
    public var showOnlineCountAlways: Bool
    public var hideProxySponsor: Bool
    public var staticAnimatedAvatars: Bool
    public var sendInlineWithoutVia: Bool
    public var showNameInsteadOfPhone: Bool
    public var hidePhoneEverywhere: Bool
    public var showMutualContactInHeader: Bool
    public var showJoinDates: Bool
    public var showInvisibleChars: Bool
    public var cleanSentLinks: Bool
    public var cleanOpenedLinks: Bool
    public var hideForeignAgentLabels: Bool
    public var showMediaInfoInViewer: Bool
    public var freeTranslation: Bool
    public var freeTranscription: Bool
    public var roundVideoUltraWide: Bool
    public var spendLockEnabled: Bool
    public var subToggles: [String: Bool]
    public var cameraResolution: Int32
    public var cameraFrameRate: Int32
    public var roundVideoQuality: Int32

    public init(
        concealBottomBar: Bool,
        showContactsShortcut: Bool,
        showCallsShortcut: Bool,
        showTabLabels: Bool,
        showSearchShortcut: Bool,
        stretchBottomBar: Bool,
        showAppBadge: Bool = true,
        classicDesign: Bool = false,
        showProfileIdentifiers: Bool,
        showDataCenter: Bool,
        showRegistrationDate: Bool,
        showChatCreationDate: Bool,
        showCallbackData: Bool = false,
        hideStoryStrip: Bool,
        disableStoryCameraSwipe: Bool,
        confirmStoryOpen: Bool,
        allowStoryRepost: Bool,
        startRoundVideoWithRearCamera: Bool,
        hideGalleryCamera: Bool?,
        hidePhoneInSettings: Bool,
        hideBusinessBotPanel: Bool = false,
        businessBotPanelVisibilityOverrides: [Int64: Bool] = [:],
        showOnlineInGroups: Bool = true,
        showSecondsInMessages: Bool = false,
        showSecondsInLastSeen: Bool = false,
        showExactViewCounts: Bool = false,
        showChatCompanion: Bool = false,
        showAgentTab: Bool = false,
        hideVoiceRecordButton: Bool = false,
        hidePinnedMessageBar: Bool = false,
        forceViewOnceVoice: Bool = false,
        hideGiftInputButton: Bool = false,
        hideSimilarChannels: Bool = false,
        hideBirthdays: Bool = false,
        disableTelegramAI: Bool = false,
        disableTonWallet: Bool = false,
        showOnlineCountAlways: Bool = false,
        hideProxySponsor: Bool = false,
        staticAnimatedAvatars: Bool = false,
        sendInlineWithoutVia: Bool = false,
        showNameInsteadOfPhone: Bool = false,
        hidePhoneEverywhere: Bool = false,
        showMutualContactInHeader: Bool = false,
        showJoinDates: Bool = false,
        showInvisibleChars: Bool = false,
        cleanSentLinks: Bool = false,
        cleanOpenedLinks: Bool = false,
        hideForeignAgentLabels: Bool = false,
        showMediaInfoInViewer: Bool = false,
        freeTranslation: Bool = false,
        freeTranscription: Bool = false,
        roundVideoUltraWide: Bool = false,
        spendLockEnabled: Bool = false,
        subToggles: [String: Bool] = [:],
        cameraResolution: Int32 = 1080,
        cameraFrameRate: Int32 = 30,
        roundVideoQuality: Int32 = 0
    ) {
        self.concealBottomBar = concealBottomBar
        self.showContactsShortcut = showContactsShortcut
        self.showCallsShortcut = showCallsShortcut
        self.showTabLabels = showTabLabels
        self.showSearchShortcut = showSearchShortcut
        self.stretchBottomBar = stretchBottomBar
        self.showAppBadge = showAppBadge
        self.classicDesign = classicDesign
        self.showProfileIdentifiers = showProfileIdentifiers
        self.showDataCenter = showDataCenter
        self.showRegistrationDate = showRegistrationDate
        self.showChatCreationDate = showChatCreationDate
        self.showCallbackData = showCallbackData
        self.hideStoryStrip = hideStoryStrip
        self.disableStoryCameraSwipe = disableStoryCameraSwipe
        self.confirmStoryOpen = confirmStoryOpen
        self.allowStoryRepost = allowStoryRepost
        self.startRoundVideoWithRearCamera = startRoundVideoWithRearCamera
        self.hideGalleryCamera = hideGalleryCamera
        self.hidePhoneInSettings = hidePhoneInSettings
        self.hideBusinessBotPanel = hideBusinessBotPanel
        self.businessBotPanelVisibilityOverrides = businessBotPanelVisibilityOverrides
        self.showOnlineInGroups = showOnlineInGroups
        self.showSecondsInMessages = showSecondsInMessages
        self.showSecondsInLastSeen = showSecondsInLastSeen
        self.showExactViewCounts = showExactViewCounts
        self.showChatCompanion = showChatCompanion
        self.showAgentTab = showAgentTab
        self.hideVoiceRecordButton = hideVoiceRecordButton
        self.hidePinnedMessageBar = hidePinnedMessageBar
        self.forceViewOnceVoice = forceViewOnceVoice
        self.hideGiftInputButton = hideGiftInputButton
        self.hideSimilarChannels = hideSimilarChannels
        self.hideBirthdays = hideBirthdays
        self.disableTelegramAI = disableTelegramAI
        self.disableTonWallet = disableTonWallet
        self.showOnlineCountAlways = showOnlineCountAlways
        self.hideProxySponsor = hideProxySponsor
        self.staticAnimatedAvatars = staticAnimatedAvatars
        self.sendInlineWithoutVia = sendInlineWithoutVia
        self.showNameInsteadOfPhone = showNameInsteadOfPhone
        self.hidePhoneEverywhere = hidePhoneEverywhere
        self.showMutualContactInHeader = showMutualContactInHeader
        self.showJoinDates = showJoinDates
        self.showInvisibleChars = showInvisibleChars
        self.cleanSentLinks = cleanSentLinks
        self.cleanOpenedLinks = cleanOpenedLinks
        self.hideForeignAgentLabels = hideForeignAgentLabels
        self.showMediaInfoInViewer = showMediaInfoInViewer
        self.freeTranslation = freeTranslation
        self.freeTranscription = freeTranscription
        self.roundVideoUltraWide = roundVideoUltraWide
        self.spendLockEnabled = spendLockEnabled
        self.subToggles = subToggles
        self.cameraResolution = cameraResolution
        self.cameraFrameRate = cameraFrameRate
        self.roundVideoQuality = roundVideoQuality
    }

    private enum CodingKeys: String, CodingKey {
        case concealBottomBar, showContactsShortcut, showCallsShortcut, showTabLabels, showSearchShortcut, stretchBottomBar
        case showAppBadge, classicDesign
        case showProfileIdentifiers, showDataCenter, showRegistrationDate, showChatCreationDate
        case showCallbackData
        case hideStoryStrip, disableStoryCameraSwipe, confirmStoryOpen, allowStoryRepost
        case startRoundVideoWithRearCamera, hideGalleryCamera, hidePhoneInSettings
        case hideBusinessBotPanel, businessBotPanelVisibilityOverrides
        case showOnlineInGroups
        case showSecondsInMessages, showSecondsInLastSeen, showExactViewCounts
        case showChatCompanion
        case showAgentTab
        case hideVoiceRecordButton, hidePinnedMessageBar, forceViewOnceVoice, hideGiftInputButton, hideSimilarChannels, hideBirthdays, disableTelegramAI, disableTonWallet, showOnlineCountAlways, hideProxySponsor, staticAnimatedAvatars, sendInlineWithoutVia, showNameInsteadOfPhone, hidePhoneEverywhere, showMutualContactInHeader, showJoinDates, showInvisibleChars, cleanSentLinks, cleanOpenedLinks, hideForeignAgentLabels, showMediaInfoInViewer, freeTranslation, freeTranscription, roundVideoUltraWide, spendLockEnabled, subToggles, cameraResolution, cameraFrameRate, roundVideoQuality
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.concealBottomBar = try container.decodeIfPresent(Bool.self, forKey: .concealBottomBar) ?? false
        self.showContactsShortcut = try container.decodeIfPresent(Bool.self, forKey: .showContactsShortcut) ?? true
        self.showCallsShortcut = try container.decodeIfPresent(Bool.self, forKey: .showCallsShortcut) ?? true
        self.showTabLabels = try container.decodeIfPresent(Bool.self, forKey: .showTabLabels) ?? true
        self.showSearchShortcut = try container.decodeIfPresent(Bool.self, forKey: .showSearchShortcut) ?? true
        self.stretchBottomBar = try container.decodeIfPresent(Bool.self, forKey: .stretchBottomBar) ?? false
        self.showAppBadge = try container.decodeIfPresent(Bool.self, forKey: .showAppBadge) ?? true
        self.classicDesign = try container.decodeIfPresent(Bool.self, forKey: .classicDesign) ?? false
        self.showProfileIdentifiers = try container.decodeIfPresent(Bool.self, forKey: .showProfileIdentifiers) ?? false
        self.showDataCenter = try container.decodeIfPresent(Bool.self, forKey: .showDataCenter) ?? false
        self.showRegistrationDate = try container.decodeIfPresent(Bool.self, forKey: .showRegistrationDate) ?? false
        self.showChatCreationDate = try container.decodeIfPresent(Bool.self, forKey: .showChatCreationDate) ?? false
        self.showCallbackData = try container.decodeIfPresent(Bool.self, forKey: .showCallbackData) ?? false
        self.hideStoryStrip = try container.decodeIfPresent(Bool.self, forKey: .hideStoryStrip) ?? false
        self.disableStoryCameraSwipe = try container.decodeIfPresent(Bool.self, forKey: .disableStoryCameraSwipe) ?? false
        self.confirmStoryOpen = try container.decodeIfPresent(Bool.self, forKey: .confirmStoryOpen) ?? false
        self.allowStoryRepost = try container.decodeIfPresent(Bool.self, forKey: .allowStoryRepost) ?? true
        self.startRoundVideoWithRearCamera = try container.decodeIfPresent(Bool.self, forKey: .startRoundVideoWithRearCamera) ?? false
        self.hideGalleryCamera = try container.decodeIfPresent(Bool.self, forKey: .hideGalleryCamera) ?? false
        self.hidePhoneInSettings = try container.decodeIfPresent(Bool.self, forKey: .hidePhoneInSettings) ?? false
        self.hideBusinessBotPanel = try container.decodeIfPresent(Bool.self, forKey: .hideBusinessBotPanel) ?? false
        self.businessBotPanelVisibilityOverrides = try container.decodeIfPresent([Int64: Bool].self, forKey: .businessBotPanelVisibilityOverrides) ?? [:]
        self.showOnlineInGroups = try container.decodeIfPresent(Bool.self, forKey: .showOnlineInGroups) ?? true
        self.showSecondsInMessages = try container.decodeIfPresent(Bool.self, forKey: .showSecondsInMessages) ?? false
        self.showSecondsInLastSeen = try container.decodeIfPresent(Bool.self, forKey: .showSecondsInLastSeen) ?? false
        self.showExactViewCounts = try container.decodeIfPresent(Bool.self, forKey: .showExactViewCounts) ?? false
        self.showChatCompanion = try container.decodeIfPresent(Bool.self, forKey: .showChatCompanion) ?? false
        self.showAgentTab = try container.decodeIfPresent(Bool.self, forKey: .showAgentTab) ?? false
        self.hideVoiceRecordButton = try container.decodeIfPresent(Bool.self, forKey: .hideVoiceRecordButton) ?? false
        self.hidePinnedMessageBar = try container.decodeIfPresent(Bool.self, forKey: .hidePinnedMessageBar) ?? false
        self.forceViewOnceVoice = try container.decodeIfPresent(Bool.self, forKey: .forceViewOnceVoice) ?? false
        self.hideGiftInputButton = try container.decodeIfPresent(Bool.self, forKey: .hideGiftInputButton) ?? false
        self.hideSimilarChannels = try container.decodeIfPresent(Bool.self, forKey: .hideSimilarChannels) ?? false
        self.hideBirthdays = try container.decodeIfPresent(Bool.self, forKey: .hideBirthdays) ?? false
        self.disableTelegramAI = try container.decodeIfPresent(Bool.self, forKey: .disableTelegramAI) ?? false
        self.disableTonWallet = try container.decodeIfPresent(Bool.self, forKey: .disableTonWallet) ?? false
        self.showOnlineCountAlways = try container.decodeIfPresent(Bool.self, forKey: .showOnlineCountAlways) ?? false
        self.hideProxySponsor = try container.decodeIfPresent(Bool.self, forKey: .hideProxySponsor) ?? false
        self.staticAnimatedAvatars = try container.decodeIfPresent(Bool.self, forKey: .staticAnimatedAvatars) ?? false
        self.sendInlineWithoutVia = try container.decodeIfPresent(Bool.self, forKey: .sendInlineWithoutVia) ?? false
        self.showNameInsteadOfPhone = try container.decodeIfPresent(Bool.self, forKey: .showNameInsteadOfPhone) ?? false
        self.hidePhoneEverywhere = try container.decodeIfPresent(Bool.self, forKey: .hidePhoneEverywhere) ?? false
        self.showMutualContactInHeader = try container.decodeIfPresent(Bool.self, forKey: .showMutualContactInHeader) ?? false
        self.showJoinDates = try container.decodeIfPresent(Bool.self, forKey: .showJoinDates) ?? false
        self.showInvisibleChars = try container.decodeIfPresent(Bool.self, forKey: .showInvisibleChars) ?? false
        self.cleanSentLinks = try container.decodeIfPresent(Bool.self, forKey: .cleanSentLinks) ?? false
        self.cleanOpenedLinks = try container.decodeIfPresent(Bool.self, forKey: .cleanOpenedLinks) ?? false
        self.hideForeignAgentLabels = try container.decodeIfPresent(Bool.self, forKey: .hideForeignAgentLabels) ?? false
        self.showMediaInfoInViewer = try container.decodeIfPresent(Bool.self, forKey: .showMediaInfoInViewer) ?? false
        self.freeTranslation = try container.decodeIfPresent(Bool.self, forKey: .freeTranslation) ?? false
        self.freeTranscription = try container.decodeIfPresent(Bool.self, forKey: .freeTranscription) ?? false
        self.roundVideoUltraWide = try container.decodeIfPresent(Bool.self, forKey: .roundVideoUltraWide) ?? false
        self.subToggles = try container.decodeIfPresent([String: Bool].self, forKey: .subToggles) ?? [:]
        self.spendLockEnabled = try container.decodeIfPresent(Bool.self, forKey: .spendLockEnabled) ?? false
        self.cameraResolution = try container.decodeIfPresent(Int32.self, forKey: .cameraResolution) ?? 1080
        self.cameraFrameRate = try container.decodeIfPresent(Int32.self, forKey: .cameraFrameRate) ?? 30
        self.roundVideoQuality = try container.decodeIfPresent(Int32.self, forKey: .roundVideoQuality) ?? 0
    }

    public func sub(_ toggle: MadSubToggle) -> Bool {
        return self.subToggles[toggle.rawValue] ?? toggle.defaultValue
    }

    public func on(_ master: Bool, _ toggle: MadSubToggle) -> Bool {
        return master && self.sub(toggle)
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
        showAppBadge: true,
        classicDesign: false,
        showProfileIdentifiers: false,
        showDataCenter: false,
        showRegistrationDate: false,
        showChatCreationDate: false,
        showCallbackData: false,
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
        TimeSecondsDisplay.update(self.cachedValue)
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

    public var cached: InterfaceTuningSettings {
        self.lock.lock()
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
        TimeSecondsDisplay.update(updatedValue)

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

public enum TimeSecondsDisplay {
    private static let lock = NSLock()
    private static var loaded = false
    private static var messages = false
    private static var lastSeen = false

    static func update(_ settings: InterfaceTuningSettings) {
        lock.lock()
        loaded = true
        messages = settings.showSecondsInMessages
        lastSeen = settings.showSecondsInLastSeen
        lock.unlock()
    }

    private static func ensureLoaded() {
        lock.lock()
        let isLoaded = loaded
        lock.unlock()
        if !isLoaded {
            _ = InterfaceTuningSettingsStore.shared
        }
    }

    public static var inMessages: Bool {
        ensureLoaded()
        lock.lock()
        defer {
            lock.unlock()
        }
        return messages
    }

    public static var inLastSeen: Bool {
        ensureLoaded()
        lock.lock()
        defer {
            lock.unlock()
        }
        return lastSeen
    }
}
