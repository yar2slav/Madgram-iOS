import AccountContext
import ComponentFlow
import Display
import Foundation
import ItemListUI
import DebugCompanionScreen
import MadgramAgent
import MadgramAgentUI
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import UIKit
import MadLockUI
import MadProfileLinks
import UndoUI

public enum MadgramDeepLinkRoute: String, CaseIterable {
    case settings
    case ghost
    case filters
    case archive
    case interface
    case powerSaving = "power-saving"
    case premium
    case messageShot = "message-shot"
    case forwardWithoutAuthor = "forward-without-author"
    case agent
    case accounts
    case privacyCategory = "privacy"
    case hiding
    case chats
    case messages
    case other
    case notifications
    case reactions
    case lockedChats = "locked"
    case password
    case presence
    case hiddenRules = "hidden-rules"
    case names
    case companion

    fileprivate static func parse(_ url: URL) -> MadgramDeepLinkRoute? {
        guard url.scheme?.lowercased() == "mad" else {
            return nil
        }

        var components: [String] = []
        if let host = url.host, !host.isEmpty {
            components.append(host.lowercased())
        }
        components.append(contentsOf: url.pathComponents.filter { $0 != "/" }.map { $0.lowercased() })

        if components.first == "settings" {
            components.removeFirst()
        }
        guard let route = components.first else {
            return .settings
        }

        switch route {
        case "settings", "madgram":
            return .settings
        case "privacy":
            return .privacyCategory
        case "agent", "ai":
            return .agent
        case "accounts":
            return .accounts
        case "hiding":
            return .hiding
        case "chats", "spoilers":
            return .chats
        case "messages":
            return .messages
        case "other":
            return .other
        case "notifications":
            return .notifications
        case "reactions":
            return .reactions
        case "locked", "locked-chats":
            return .lockedChats
        case "password":
            return .password
        case "presence":
            return .presence
        case "hidden-rules":
            return .hiddenRules
        case "names":
            return .names
        case "companion":
            return .companion
        case "ghost", "ghost-mode":
            return .ghost
        case "filters", "message-filters":
            return .filters
        case "archive", "local-archive", "local-message-archive":
            return .archive
        case "interface", "tuning", "tabs", "profiles", "stories", "camera", "media":
            return .interface
        case "power", "power-saving":
            return .powerSaving
        case "premium", "local-premium":
            return .premium
        case "message-shot", "messageshot":
            return .messageShot
        case "forward-without-author", "anonymous-forward":
            return .forwardWithoutAuthor
        default:
            return nil
        }
    }
}

public func madgramControllerForDeepLink(context: AccountContext, url: URL) -> ViewController? {
    guard let route = MadgramDeepLinkRoute.parse(url) else {
        return nil
    }
    switch route {
    case .ghost:
        return ghostModeSettingsController(context: context)
    case .filters:
        return messageFilterSettingsController(context: context)
    case .archive:
        return localMessageArchiveSettingsController(context: context)
    case .interface:
        return interfaceTuningSettingsController(context: context)
    case .settings, .powerSaving, .premium, .messageShot, .forwardWithoutAuthor:
        return madgramSettingsController(context: context)
    case .agent:
        return agentChatController(context: context)
    case .accounts:
        return madAccountsController(context: context)
    case .privacyCategory:
        return madgramSettingsController(context: context, category: .privacy)
    case .hiding:
        return madgramSettingsController(context: context, category: .hiding)
    case .chats:
        return madgramSettingsController(context: context, category: .chats)
    case .messages:
        return madgramSettingsController(context: context, category: .messages)
    case .other:
        return madgramSettingsController(context: context, category: .other)
    case .notifications:
        return notificationsAndSoundsController(context: context, exceptionsList: nil)
    case .reactions:
        return reactionNotificationSettingsController(context: context)
    case .lockedChats:
        return madPeerListController(context: context, kind: .lockedChats)
    case .password:
        return madLocalPasswordController(context: context)
    case .presence:
        return madPeerListController(context: context, kind: .presence)
    case .hiddenRules:
        return madHiddenRulesController(context: context)
    case .names:
        return madPeerListController(context: context, kind: .aliases)
    case .companion:
        return DebugCompanionScreen(context: context)
    }
}

private final class MadgramControllerArguments {
    let openGhostMode: () -> Void
    let openMessageFilters: () -> Void
    let openLocalMessageArchive: () -> Void
    let openInterfaceTuning: () -> Void
    let updateInterfaceTuning: (@escaping (InterfaceTuningSettings) -> InterfaceTuningSettings) -> Void
    let setLocalPremium: (Bool) -> Void
    let setPowerSaving: (Bool) -> Void
    let showInfo: (String, UIView) -> Void
    let updateContentFilter: (@escaping (ChatContentFilterSettings) -> ChatContentFilterSettings) -> Void
    let openPromotedKeywords: () -> Void
    let openCompanion: () -> Void
    let openAgent: () -> Void
    let openCategory: (MadSettingsCategory) -> Void
    let openNotifications: () -> Void
    let madAction: (MadAction) -> Void

    init(
        openGhostMode: @escaping () -> Void,
        openMessageFilters: @escaping () -> Void,
        openLocalMessageArchive: @escaping () -> Void,
        openInterfaceTuning: @escaping () -> Void,
        updateInterfaceTuning: @escaping (@escaping (InterfaceTuningSettings) -> InterfaceTuningSettings) -> Void,
        setLocalPremium: @escaping (Bool) -> Void,
        setPowerSaving: @escaping (Bool) -> Void,
        showInfo: @escaping (String, UIView) -> Void,
        updateContentFilter: @escaping (@escaping (ChatContentFilterSettings) -> ChatContentFilterSettings) -> Void,
        openPromotedKeywords: @escaping () -> Void,
        openCompanion: @escaping () -> Void,
        openAgent: @escaping () -> Void,
        openCategory: @escaping (MadSettingsCategory) -> Void,
        openNotifications: @escaping () -> Void,
        madAction: @escaping (MadAction) -> Void
    ) {
        self.madAction = madAction
        self.openGhostMode = openGhostMode
        self.openMessageFilters = openMessageFilters
        self.openLocalMessageArchive = openLocalMessageArchive
        self.openInterfaceTuning = openInterfaceTuning
        self.updateInterfaceTuning = updateInterfaceTuning
        self.setLocalPremium = setLocalPremium
        self.setPowerSaving = setPowerSaving
        self.showInfo = showInfo
        self.updateContentFilter = updateContentFilter
        self.openPromotedKeywords = openPromotedKeywords
        self.openCompanion = openCompanion
        self.openAgent = openAgent
        self.openCategory = openCategory
        self.openNotifications = openNotifications
    }
}

public enum MadSettingsCategory: Int32, CaseIterable {
    case interface
    case chats
    case messages
    case privacy
    case other
    case hiding
}

enum MadAction: Equatable {
    case hiddenRules
    case localNames
    case lockedChats
    case localPassword
    case presenceList
    case profileAccounts
    case cameraResolution
    case cameraFrameRate
    case roundQuality
    case exportSettings
    case importSettings
    case changelogChat
}

private enum MadRootItem: Equatable {
    case category(MadSettingsCategory)
    case agent
    case notifications
}

private enum MadgramSection: Int32 {
    case root
    case privacy
    case messages
    case content
    case interface
    case other
}

private enum MadgramEntry: ItemListNodeEntry {
    case rootHeader(String)
    case rootItem(Int32, MadRootItem, String, String, String)
    case privacyHeader(String)
    case ghostMode(String, String)
    case hidePhoneInSettings(String, String, Bool)
    case privacyInfo(String)
    case messagesHeader(String)
    case localMessageArchive(String, String)
    case messageFilters(String, String)
    case messagesInfo(String)
    case contentHeader(String)
    case hidePromotedPosts(String, String, Bool)
    case promotedKeywords(String, String)
    case hideSponsoredMessages(String, String, Bool)
    case revealTextSpoilers(String, Bool)
    case revealMediaSpoilers(String, String, Bool)
    case spoilerSub(Int32, String, Bool, MadSubToggle)
    case contentInfo(String)
    case interfaceHeader(String)
    case classicDesign(String, Bool)
    case showAppBadge(String, String, Bool)
    case timeSeconds(String, String, Bool)
    case secondsInMessages(String, Bool)
    case secondsInLastSeen(String, Bool)
    case chatCompanion(String, String, Bool)
    case companionSettings(String)
    case interfaceTuning(String)
    case interfaceInfo(String)
    case otherHeader(String)
    case powerSaving(String, String, Bool)
    case localPremium(String, String, Bool)
    case madHeader(Int32, MadSettingsCategory, String)
    case madToggle(Int32, MadSettingsCategory, String, String?, Bool, WritableKeyPath<InterfaceTuningSettings, Bool>)
    case madSub(Int32, MadSettingsCategory, String, Bool, MadSubToggle)
    case madAction(Int32, MadSettingsCategory, String, String, MadAction)
    case madInfo(Int32, MadSettingsCategory, String)

    var category: MadSettingsCategory? {
        switch self {
        case let .madHeader(_, category, _), let .madToggle(_, category, _, _, _, _), let .madSub(_, category, _, _, _), let .madAction(_, category, _, _, _), let .madInfo(_, category, _):
            return category
        case .rootHeader, .rootItem:
            return nil
        case .hidePhoneInSettings, .hidePromotedPosts, .promotedKeywords, .hideSponsoredMessages, .contentInfo:
            return .hiding
        case .privacyHeader, .ghostMode, .privacyInfo:
            return .privacy
        case .messagesHeader, .localMessageArchive, .messageFilters, .messagesInfo:
            return .messages
        case .contentHeader, .revealTextSpoilers, .revealMediaSpoilers, .spoilerSub:
            return .chats
        case .interfaceHeader, .classicDesign, .showAppBadge, .timeSeconds, .secondsInMessages, .secondsInLastSeen, .chatCompanion, .companionSettings, .interfaceTuning, .interfaceInfo:
            return .interface
        case .otherHeader, .powerSaving, .localPremium:
            return .other
        }
    }

    var isHeader: Bool {
        switch self {
        case .privacyHeader, .messagesHeader, .contentHeader, .interfaceHeader, .otherHeader:
            return true
        default:
            return false
        }
    }

    var section: ItemListSectionId {
        switch self {
        case let .madHeader(id, _, _), let .madToggle(id, _, _, _, _, _), let .madSub(id, _, _, _, _), let .madAction(id, _, _, _, _), let .madInfo(id, _, _):
            return id / 100
        case .rootHeader, .rootItem:
            return MadgramSection.root.rawValue
        case .privacyHeader, .ghostMode, .hidePhoneInSettings, .privacyInfo:
            return MadgramSection.privacy.rawValue
        case .messagesHeader, .localMessageArchive, .messageFilters, .messagesInfo:
            return MadgramSection.messages.rawValue
        case .contentHeader, .hidePromotedPosts, .promotedKeywords, .hideSponsoredMessages, .revealTextSpoilers, .revealMediaSpoilers, .spoilerSub, .contentInfo:
            return MadgramSection.content.rawValue
        case .interfaceHeader, .classicDesign, .showAppBadge, .timeSeconds, .secondsInMessages, .secondsInLastSeen, .chatCompanion, .companionSettings, .interfaceTuning, .interfaceInfo:
            return MadgramSection.interface.rawValue
        case .otherHeader, .powerSaving, .localPremium:
            return MadgramSection.other.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case let .madHeader(id, _, _), let .madToggle(id, _, _, _, _, _), let .madSub(id, _, _, _, _), let .madAction(id, _, _, _, _), let .madInfo(id, _, _):
            return id
        case .rootHeader: return 1000
        case let .rootItem(index, _, _, _, _): return 1001 + index
        case .privacyHeader: return 0
        case .ghostMode: return 1
        case .hidePhoneInSettings: return 2
        case .privacyInfo: return 3
        case .messagesHeader: return 10
        case .localMessageArchive: return 11
        case .messageFilters: return 12
        case .messagesInfo: return 13
        case .contentHeader: return 14
        case .hidePromotedPosts: return 15
        case .promotedKeywords: return 16
        case .hideSponsoredMessages: return 17
        case .revealTextSpoilers: return 18
        case .revealMediaSpoilers: return 19
        case .contentInfo: return 21
        case let .spoilerSub(id, _, _, _): return id
        case .interfaceHeader: return 30
        case .classicDesign: return 31
        case .showAppBadge: return 32
        case .timeSeconds: return 33
        case .secondsInMessages: return 34
        case .secondsInLastSeen: return 35
        case .chatCompanion: return 36
        case .companionSettings: return 37
        case .interfaceTuning: return 38
        case .interfaceInfo: return 39
        case .otherHeader: return 40
        case .powerSaving: return 42
        case .localPremium: return 43
        }
    }

    static func ==(lhs: MadgramEntry, rhs: MadgramEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.madHeader(a, b, c), .madHeader(d, e, f)), let (.madInfo(a, b, c), .madInfo(d, e, f)):
            return a == d && b == e && c == f
        case let (.madToggle(a, b, c, d, e, f), .madToggle(g, h, i, j, k, l)):
            return a == g && b == h && c == i && d == j && e == k && f == l
        case let (.madSub(a, b, c, d, e), .madSub(f, g, h, i, j)):
            return a == f && b == g && c == h && d == i && e == j
        case let (.madAction(a, b, c, d, e), .madAction(f, g, h, i, j)):
            return a == f && b == g && c == h && d == i && e == j
        case let (.rootHeader(lhsText), .rootHeader(rhsText)):
            return lhsText == rhsText
        case let (.rootItem(lhsIndex, lhsItem, lhsIcon, lhsTitle, lhsLabel), .rootItem(rhsIndex, rhsItem, rhsIcon, rhsTitle, rhsLabel)):
            return lhsIndex == rhsIndex && lhsItem == rhsItem && lhsIcon == rhsIcon && lhsTitle == rhsTitle && lhsLabel == rhsLabel
        case let (.privacyHeader(lhsText), .privacyHeader(rhsText)),
             let (.privacyInfo(lhsText), .privacyInfo(rhsText)),
             let (.messagesHeader(lhsText), .messagesHeader(rhsText)),
             let (.messagesInfo(lhsText), .messagesInfo(rhsText)),
             let (.contentHeader(lhsText), .contentHeader(rhsText)),
             let (.contentInfo(lhsText), .contentInfo(rhsText)),
             let (.interfaceHeader(lhsText), .interfaceHeader(rhsText)),
             let (.interfaceTuning(lhsText), .interfaceTuning(rhsText)),
             let (.companionSettings(lhsText), .companionSettings(rhsText)),
             let (.interfaceInfo(lhsText), .interfaceInfo(rhsText)),
             let (.otherHeader(lhsText), .otherHeader(rhsText)):
            return lhsText == rhsText
        case let (.ghostMode(lhsText, lhsValue), .ghostMode(rhsText, rhsValue)),
             let (.localMessageArchive(lhsText, lhsValue), .localMessageArchive(rhsText, rhsValue)),
             let (.messageFilters(lhsText, lhsValue), .messageFilters(rhsText, rhsValue)),
             let (.promotedKeywords(lhsText, lhsValue), .promotedKeywords(rhsText, rhsValue)):
            return lhsText == rhsText && lhsValue == rhsValue
        case let (.classicDesign(lhsText, lhsValue), .classicDesign(rhsText, rhsValue)),
             let (.revealTextSpoilers(lhsText, lhsValue), .revealTextSpoilers(rhsText, rhsValue)),
             let (.secondsInMessages(lhsText, lhsValue), .secondsInMessages(rhsText, rhsValue)),
             let (.secondsInLastSeen(lhsText, lhsValue), .secondsInLastSeen(rhsText, rhsValue)):
            return lhsText == rhsText && lhsValue == rhsValue
        case let (.hidePhoneInSettings(lhsText, lhsInfo, lhsValue), .hidePhoneInSettings(rhsText, rhsInfo, rhsValue)),
             let (.showAppBadge(lhsText, lhsInfo, lhsValue), .showAppBadge(rhsText, rhsInfo, rhsValue)),
             let (.chatCompanion(lhsText, lhsInfo, lhsValue), .chatCompanion(rhsText, rhsInfo, rhsValue)),
             let (.localPremium(lhsText, lhsInfo, lhsValue), .localPremium(rhsText, rhsInfo, rhsValue)),
             let (.powerSaving(lhsText, lhsInfo, lhsValue), .powerSaving(rhsText, rhsInfo, rhsValue)),
             let (.hidePromotedPosts(lhsText, lhsInfo, lhsValue), .hidePromotedPosts(rhsText, rhsInfo, rhsValue)),
             let (.timeSeconds(lhsText, lhsInfo, lhsValue), .timeSeconds(rhsText, rhsInfo, rhsValue)),
             let (.hideSponsoredMessages(lhsText, lhsInfo, lhsValue), .hideSponsoredMessages(rhsText, rhsInfo, rhsValue)),
             let (.revealMediaSpoilers(lhsText, lhsInfo, lhsValue), .revealMediaSpoilers(rhsText, rhsInfo, rhsValue)):
            return lhsText == rhsText && lhsInfo == rhsInfo && lhsValue == rhsValue
        case let (.spoilerSub(lhsId, lhsText, lhsValue, lhsToggle), .spoilerSub(rhsId, rhsText, rhsValue, rhsToggle)):
            return lhsId == rhsId && lhsText == rhsText && lhsValue == rhsValue && lhsToggle == rhsToggle
        default:
            return false
        }
    }

    static func <(lhs: MadgramEntry, rhs: MadgramEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MadgramControllerArguments
        let switchItem: (String, String?, Bool, @escaping (Bool) -> Void) -> ListViewItem = { title, info, value, updated in
            var titleBadgeComponent: AnyComponent<Empty>?
            var titleBadgeAction: ((UIView) -> Void)?
            if let info {
                titleBadgeComponent = featureInfoBadgeComponent(color: presentationData.theme.list.itemAccentColor)
                titleBadgeAction = { sourceView in
                    arguments.showInfo(info, sourceView)
                }
            }
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: title,
                titleBadgeComponent: titleBadgeComponent,
                titleBadgeAction: titleBadgeAction,
                value: value,
                maximumNumberOfLines: 2,
                sectionId: self.section,
                style: .blocks,
                updated: updated
            )
        }
        switch self {
        case let .madHeader(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .madInfo(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .madToggle(_, _, title, info, value, keyPath):
            return switchItem(title, info, value, { value in
                arguments.updateInterfaceTuning { current in
                    var current = current
                    current[keyPath: keyPath] = value
                    return current
                }
            })
        case let .spoilerSub(_, title, value, toggle), let .madSub(_, _, title, value, toggle):
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateInterfaceTuning { current in
                    var current = current
                    current.subToggles[toggle.rawValue] = !value
                    return current
                }
            })
        case let .madAction(_, _, title, label, action):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.madAction(action)
            })
        case let .rootHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .rootItem(_, item, icon, title, label):
            let color = presentationData.theme.list.itemPrimaryTextColor
            let iconImage = (UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20.0, weight: .regular))?.withTintColor(color, renderingMode: .alwaysOriginal)).flatMap { symbol -> UIImage in
                let side: CGFloat = 29.0
                let box: CGFloat = 25.0
                let scale = min(box / max(symbol.size.width, 1.0), box / max(symbol.size.height, 1.0), 1.0)
                let drawSize = CGSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
                return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
                    symbol.draw(in: CGRect(x: (side - drawSize.width) / 2.0, y: (side - drawSize.height) / 2.0, width: drawSize.width, height: drawSize.height))
                }
            }
            return ItemListDisclosureItem(presentationData: presentationData, icon: iconImage, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                switch item {
                case let .category(category):
                    arguments.openCategory(category)
                case .agent:
                    arguments.openAgent()
                case .notifications:
                    arguments.openNotifications()
                }
            })
        case let .privacyHeader(text), let .messagesHeader(text), let .contentHeader(text), let .interfaceHeader(text), let .otherHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .privacyInfo(text), let .messagesInfo(text), let .contentInfo(text), let .interfaceInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .ghostMode(text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: arguments.openGhostMode)
        case let .companionSettings(text):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: arguments.openCompanion)
        case let .hidePhoneInSettings(text, info, value):
            return switchItem(text, info, value, { value in
                arguments.updateInterfaceTuning { current in
                    var current = current
                    current.hidePhoneInSettings = value
                    return current
                }
            })
        case let .localMessageArchive(text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: arguments.openLocalMessageArchive)
        case let .messageFilters(text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: arguments.openMessageFilters)
        case let .classicDesign(text, value):
            return switchItem(text, nil, value, { value in
                arguments.updateInterfaceTuning { current in
                    var current = current
                    current.classicDesign = value
                    return current
                }
            })
        case let .showAppBadge(text, info, value):
            return switchItem(text, info, value, { value in
                arguments.updateInterfaceTuning { current in
                    var current = current
                    current.showAppBadge = value
                    return current
                }
            })
        case let .chatCompanion(text, info, value):
            return switchItem(text, info, value, { value in
                arguments.updateInterfaceTuning { current in
                    var current = current
                    current.showChatCompanion = value
                    return current
                }
            })
        case let .hidePromotedPosts(text, info, value):
            return switchItem(text, info, value, { value in
                arguments.updateContentFilter { current in
                    var current = current
                    current.hidePromotedPosts = value
                    return current
                }
            })
        case let .promotedKeywords(text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: arguments.openPromotedKeywords)
        case let .hideSponsoredMessages(text, info, value):
            return switchItem(text, info, value, { value in
                arguments.updateContentFilter { current in
                    var current = current
                    current.hideSponsoredMessages = value
                    return current
                }
            })
        case let .revealTextSpoilers(text, value):
            return switchItem(text, nil, value, { value in
                arguments.updateContentFilter { current in
                    var current = current
                    current.revealTextSpoilers = value
                    return current
                }
            })
        case let .revealMediaSpoilers(text, info, value):
            return switchItem(text, info, value, { value in
                arguments.updateContentFilter { current in
                    var current = current
                    current.revealMediaSpoilers = value
                    return current
                }
            })
        case let .timeSeconds(text, info, value):
            return switchItem(text, info, value, { value in
                arguments.updateInterfaceTuning { current in
                    var current = current
                    current.showSecondsInMessages = value
                    current.showSecondsInLastSeen = value
                    return current
                }
            })
        case let .secondsInMessages(text, value):
            return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateInterfaceTuning { current in
                    var current = current
                    current.showSecondsInMessages = !value
                    return current
                }
            })
        case let .secondsInLastSeen(text, value):
            return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateInterfaceTuning { current in
                    var current = current
                    current.showSecondsInLastSeen = !value
                    return current
                }
            })
        case let .interfaceTuning(text):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: arguments.openInterfaceTuning)
        case let .powerSaving(text, info, value):
            return switchItem(text, info, value, arguments.setPowerSaving)
        case let .localPremium(text, info, value):
            return switchItem(text, info, value, arguments.setLocalPremium)
        }
    }
}

public func madgramSettingsController(context: AccountContext, category: MadSettingsCategory? = nil) -> ViewController {
    var presentTooltip: ((String, UIView) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let localPremiumValue = Atomic(value: LocalPremiumSettingsStore.shared.current)
    let localPremiumPromise = ValuePromise(localPremiumValue.with { $0 }, ignoreRepeated: true)

    let arguments = MadgramControllerArguments(
        openGhostMode: {
            pushControllerImpl?(ghostModeSettingsController(context: context))
        },
        openMessageFilters: {
            pushControllerImpl?(messageFilterSettingsController(context: context))
        },
        openLocalMessageArchive: {
            pushControllerImpl?(localMessageArchiveSettingsController(context: context))
        },
        openInterfaceTuning: {
            pushControllerImpl?(interfaceTuningSettingsController(context: context))
        },
        updateInterfaceTuning: { f in
            let current = InterfaceTuningSettingsStore.shared.cached
            let updated = f(current)
            let spendKinds: [MadSubToggle] = [.spendReactions, .spendMessages, .spendGifts, .spendTransfer, .spendPayments]
            let weakensSpendLock = spendKinds.contains(where: { current.on(current.spendLockEnabled, $0) && !updated.on(updated.spendLockEnabled, $0) })
            if weakensSpendLock && MadLock.hasPassword {
                MadLock.requireUnlock(strings: context.sharedContext.currentPresentationData.with { $0 }.strings, completion: { success in
                    if success {
                        InterfaceTuningSettingsStore.shared.update { current in
                            return f(current)
                        }
                    } else {
                        InterfaceTuningSettingsStore.shared.update { $0 }
                    }
                })
                return
            }
            InterfaceTuningSettingsStore.shared.update { current in
                return f(current)
            }
        },
        setLocalPremium: { value in
            let updated = LocalPremiumSettingsStore.shared.update { current in
                var current = current
                current.isEnabled = value
                return current
            }
            let _ = localPremiumValue.swap(updated)
            localPremiumPromise.set(updated)
            let _ = (context.sharedContext.activeAccountContexts
            |> take(1)
            |> mapToSignal { activeAccounts -> Signal<Never, NoError> in
                var signals: [Signal<Never, NoError>] = []
                for (_, accountContext, _) in activeAccounts.accounts {
                    signals.append(accountContext.engine.accountData.applyLocalPremiumOverride())
                }
                if signals.isEmpty {
                    signals.append(context.engine.accountData.applyLocalPremiumOverride())
                }
                return combineLatest(signals) |> ignoreValues
            }).start()
        },
        setPowerSaving: { value in
            let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var settings = settings
                if value {
                    settings.energyUsageSettings = EnergyUsageSettings.powerSavingDefault
                    settings.energyUsageSettings.activationThreshold = 96
                } else {
                    settings.energyUsageSettings = EnergyUsageSettings.default
                }
                return settings
            }).start()
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var settings = settings
                settings.reduceMotion = value
                return settings
            }).start()
        },
        showInfo: { text, sourceView in
            presentTooltip?(text, sourceView)
        },
        updateContentFilter: { f in
            ChatContentFilterSettingsStore.shared.update(f)
        },
        openPromotedKeywords: {
            pushControllerImpl?(promotedPostKeywordsController(context: context))
        },
        openCompanion: {
            pushControllerImpl?(DebugCompanionScreen(context: context))
        },
        openAgent: {
            pushControllerImpl?(agentChatController(context: context))
        },
        openCategory: { category in
            pushControllerImpl?(madgramSettingsController(context: context, category: category))
        },
        openNotifications: {
            pushControllerImpl?(notificationsAndSoundsController(context: context, exceptionsList: nil, focusOnItemTag: nil))
        },
        madAction: { action in
            let more = context.sharedContext.currentPresentationData.with { $0 }.strings.localFeatures.more
            let updateInt: (WritableKeyPath<InterfaceTuningSettings, Int32>, Int32) -> Void = { keyPath, value in
                InterfaceTuningSettingsStore.shared.update { current in
                    var current = current
                    current[keyPath: keyPath] = value
                    return current
                }
            }
            let settings = InterfaceTuningSettingsStore.shared.current
            switch action {
            case .hiddenRules:
                pushControllerImpl?(madHiddenRulesController(context: context))
            case .localNames:
                pushControllerImpl?(madPeerListController(context: context, kind: .aliases))
            case .lockedChats:
                pushControllerImpl?(madPeerListController(context: context, kind: .lockedChats))
            case .presenceList:
                pushControllerImpl?(madPeerListController(context: context, kind: .presence))
            case .profileAccounts:
                pushControllerImpl?(madAccountsController(context: context))
            case .localPassword:
                pushControllerImpl?(madLocalPasswordController(context: context))
            case .cameraResolution:
                let values: [Int32] = [2160, 1080, 720]
                madPresentOptions(context: context, present: { presentControllerImpl?($0) }, title: more.cameraResolution, options: [("4K", settings.cameraResolution == 2160), ("1080p", settings.cameraResolution == 1080), ("720p", settings.cameraResolution == 720)], selected: { index in
                    updateInt(\.cameraResolution, values[index])
                })
            case .cameraFrameRate:
                let values: [Int32] = [30, 60]
                madPresentOptions(context: context, present: { presentControllerImpl?($0) }, title: more.cameraFrameRate, options: [("30", settings.cameraFrameRate != 60), ("60", settings.cameraFrameRate == 60)], selected: { index in
                    updateInt(\.cameraFrameRate, values[index])
                })
            case .roundQuality:
                madPresentOptions(context: context, present: { presentControllerImpl?($0) }, title: more.roundVideoQuality, options: [(more.roundVideoQualityStandard, settings.roundVideoQuality == 0), (more.roundVideoQualityHigh, settings.roundVideoQuality == 1), (more.roundVideoQualityMax, settings.roundVideoQuality == 2)], selected: { index in
                    updateInt(\.roundVideoQuality, Int32(index))
                })
            case .exportSettings:
                madExportSettings()
            case .changelogChat:
                MadChangelogPreferences.setHidden(false, accountId: context.account.peerId.toInt64())
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: more.changelogRestored, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }))
            case .importSettings:
                MadLock.requireUnlock(strings: context.sharedContext.currentPresentationData.with { $0 }.strings, completion: { unlocked in
                    guard unlocked else {
                        return
                    }
                    madImportSettings(completion: { success in
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: success ? more.settingsImported : more.settingsImportFailed, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }))
                    })
                })
            }
        }
    )

    let ghostModeSettings = context.engine.messages.ghostModeSettings()

    let isLocalMessageArchiveEnabled = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.deletedMessageArchiveSettings))
    |> map { entry -> Bool in
        return (entry?.get(DeletedMessageArchiveSettings.self) ?? .defaultSettings).isEnabled
    }
    |> distinctUntilChanged

    let hiddenSenderCount = messageFilterSettingsSignal()
    |> map { settings -> Int in
        return settings.shadowBannedPeerIds.count
    }
    |> distinctUntilChanged

    let sharedData = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings, ApplicationSpecificSharedDataKeys.presentationThemeSettings])
    |> map { sharedData -> Bool in
        let downloadSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]?.get(MediaAutoDownloadSettings.self) ?? .defaultSettings
        let themeSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
        let energy = downloadSettings.energyUsageSettings
        return energy.activationThreshold >= 96
            && !energy.autoplayVideo
            && !energy.autoplayGif
            && !energy.loopStickers
            && !energy.loopEmoji
            && !energy.fullTranslucency
            && !energy.extendBackgroundWork
            && !energy.autodownloadInBackground
            && themeSettings.reduceMotion
    }
    |> distinctUntilChanged

    let signal = combineLatest(
        context.sharedContext.presentationData,
        ghostModeSettings,
        localPremiumPromise.get(),
        sharedData,
        isLocalMessageArchiveEnabled,
        hiddenSenderCount,
        interfaceTuningSettingsSignal(),
        chatContentFilterSettingsSignal(),
        MadStores.peerAliases.signal(),
        MadStores.lockedChats.signal(),
        MadStores.presenceWatched.signal()
    )
    |> map { presentationData, ghostModeSettings, localPremiumSettings, isPowerSavingEnabled, isLocalMessageArchiveEnabled, hiddenSenderCount, interfaceTuningSettings, contentFilterSettings, peerAliases, lockedChats, presenceWatched -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = presentationData.strings.localFeatures
        var entries: [MadgramEntry] = [
            .privacyHeader(strings.madgram.privacySection),
            .ghostMode(strings.ghostMode.title, ghostModeSettings.isEnabled ? strings.ghostMode.on : strings.ghostMode.off),
            .hidePhoneInSettings(strings.interfaceTuning.hidePhoneInSettings, strings.interfaceTuning.hidePhoneInSettingsInfo, interfaceTuningSettings.hidePhoneInSettings),
            .privacyInfo(strings.madgram.privacyInfo),

            .messagesHeader(strings.madgram.messagesSection),
            .localMessageArchive(strings.localMessageArchive.title, isLocalMessageArchiveEnabled ? strings.ghostMode.on : strings.ghostMode.off),
            .messageFilters(strings.messageFilter.title, hiddenSenderCount > 0 ? "\(hiddenSenderCount)" : ""),
            .messagesInfo(strings.madgram.messagesInfo),

            .contentHeader(strings.extras.contentSection.uppercased()),
            .hidePromotedPosts(strings.extras.hidePromotedPosts, strings.extras.hidePromotedPostsInfo, contentFilterSettings.hidePromotedPosts),
            .promotedKeywords(strings.extras.promotedKeywords, "\(contentFilterSettings.promotedPostKeywords.count)"),
            .hideSponsoredMessages(strings.extras.hideSponsoredMessages, strings.extras.hideSponsoredMessagesInfo, contentFilterSettings.hideSponsoredMessages),
            .revealTextSpoilers(strings.extras.revealTextSpoilers, contentFilterSettings.revealTextSpoilers),
            .revealMediaSpoilers(strings.extras.revealMediaSpoilers, strings.extras.revealSpoilersInfo, contentFilterSettings.revealMediaSpoilers),
            .contentInfo(strings.extras.contentInfo),

            .interfaceHeader(strings.madgram.interfaceSection),
            .classicDesign(strings.madgram.classicDesign, interfaceTuningSettings.classicDesign),
            .showAppBadge(strings.interfaceTuning.showAppBadge, strings.interfaceTuning.showAppBadgeInfo, interfaceTuningSettings.showAppBadge),
        ]
        if contentFilterSettings.revealsSpoilers {
            var spoilerSubs: [(String, MadSubToggle)] = [
                (strings.extras.spoilersPrivate, .spoilersPrivate),
                (strings.extras.spoilersGroups, .spoilersGroups),
                (strings.extras.spoilersChannels, .spoilersChannels),
                (strings.extras.spoilersSaved, .spoilersSaved)
            ]
            if contentFilterSettings.revealMediaSpoilers {
                spoilerSubs.append((strings.extras.spoilersProfileMedia, .spoilersProfileMedia))
            }
            for (index, (title, toggle)) in spoilerSubs.enumerated() {
                entries.append(.spoilerSub(22 + Int32(index), title, interfaceTuningSettings.sub(toggle), toggle))
            }
        }
        let secondsCount = (interfaceTuningSettings.showSecondsInMessages ? 1 : 0) + (interfaceTuningSettings.showSecondsInLastSeen ? 1 : 0)
        entries.append(.timeSeconds(secondsCount == 0 ? strings.extras.timeSeconds : "\(strings.extras.timeSeconds) · \(secondsCount)/2", strings.extras.timeSecondsInfo, secondsCount != 0))
        if secondsCount != 0 {
            entries.append(.secondsInMessages(strings.extras.secondsInMessages, interfaceTuningSettings.showSecondsInMessages))
            entries.append(.secondsInLastSeen(strings.extras.secondsInLastSeen, interfaceTuningSettings.showSecondsInLastSeen))
        }
        entries += [
            .chatCompanion(strings.extras.chatCompanion, strings.extras.chatCompanionInfo, interfaceTuningSettings.showChatCompanion),
            .companionSettings(strings.extras.companionSettings),
            .interfaceTuning(strings.interfaceTuning.title),
            .interfaceInfo(strings.madgram.classicDesignInfo),

            .otherHeader(strings.madgram.otherSection),
            .powerSaving(strings.madgram.powerSaving, strings.madgram.powerSavingInfo, isPowerSavingEnabled),
            .localPremium(strings.localPremium.title, strings.extras.localPremiumInfo, localPremiumSettings.isEnabled)
        ]
        entries += madExtraEntries(settings: interfaceTuningSettings, contentFilter: contentFilterSettings, more: strings.more, aliasesCount: peerAliases.count, lockedCount: lockedChats.count, presenceCount: presenceWatched.count)
        let extras = strings.extras
        let title: String
        if let category {
            entries = entries.filter { $0.category == category && !$0.isHeader }
            title = madCategoryTitle(category, strings: extras, more: strings.more)
        } else {
            let agentSettings = AgentSettingsStore.shared.current
            let agentLabel = AgentKeychain.apiKey(for: agentSettings.provider) == nil ? extras.aiAgentNotConfigured : ""
            let items: [(MadRootItem, String, String, String)] = [
                (.category(.interface), "paintpalette", extras.categoryInterface, ""),
                (.category(.chats), "bubble.left.and.bubble.right", extras.categoryChats, ""),
                (.category(.messages), "bubble.left", extras.categoryMessages, ""),
                (.notifications, "bell", extras.categoryNotifications, ""),
                (.category(.hiding), "eye.slash", strings.more.categoryHiding, ""),
                (.category(.privacy), "hand.raised", extras.categoryPrivacy, ghostModeSettings.isEnabled ? strings.ghostMode.on : ""),
                (.agent, "sparkles", extras.aiAgent, agentLabel),
                (.category(.other), "slider.horizontal.3", extras.categoryOther, "")
            ]
            entries = [.rootHeader(extras.categoriesHeader)]
            for (index, item) in items.enumerated() {
                entries.append(.rootItem(Int32(index), item.0, item.1, item.2, item.3))
            }
            title = strings.madgram.title
        }
        return (
            ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text(title),
                leftNavigationButton: nil,
                rightNavigationButton: ItemListNavigationButton(content: .icon(.search), style: .regular, enabled: true, action: {
                    pushControllerImpl?(MadSettingsSearchController(context: context))
                }),
                backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
                animateChanges: true
            ),
            (
                ItemListNodeState(
                    presentationData: ItemListPresentationData(presentationData),
                    entries: entries,
                    style: .blocks
                ),
                arguments
            )
        )
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    var currentTooltipController: TooltipController?
    presentTooltip = { [weak controller] text, sourceView in
        guard let controller else {
            return
        }
        currentTooltipController?.dismiss()
        currentTooltipController = presentFeatureInfoTooltip(
            text: text,
            sourceView: sourceView,
            presentationData: context.sharedContext.currentPresentationData.with { $0 },
            controller: controller
        )
    }
    return controller
}

private func madCategoryTitle(_ category: MadSettingsCategory, strings: MadgramExtraFeatureStrings, more: MadgramMoreFeatureStrings) -> String {
    switch category {
    case .interface:
        return strings.categoryInterface
    case .chats:
        return strings.categoryChats
    case .messages:
        return strings.categoryMessages
    case .privacy:
        return strings.categoryPrivacy
    case .other:
        return strings.categoryOther
    case .hiding:
        return more.categoryHiding
    }
}


private func madExtraEntries(settings: InterfaceTuningSettings, contentFilter: ChatContentFilterSettings, more: MadgramMoreFeatureStrings, aliasesCount: Int, lockedCount: Int, presenceCount: Int) -> [MadgramEntry] {
    var entries: [MadgramEntry] = []
    var id: Int32 = 0
    var category: MadSettingsCategory = .interface
    func section(_ base: Int32, _ newCategory: MadSettingsCategory, _ header: String?) {
        id = base
        category = newCategory
        if let header {
            entries.append(.madHeader(id, category, header.uppercased()))
            id += 1
        }
    }
    func toggle(_ title: String, _ info: String?, _ keyPath: WritableKeyPath<InterfaceTuningSettings, Bool>, subs: [(String, MadSubToggle)] = []) {
        let value = settings[keyPath: keyPath]
        entries.append(.madToggle(id, category, title, info, value, keyPath))
        for (index, (subTitle, sub)) in subs.enumerated() where value {
            entries.append(.madSub(id + 1 + Int32(index), category, subTitle, settings.sub(sub), sub))
        }
        id += 1 + Int32(subs.count)
    }
    func action(_ title: String, _ label: String, _ value: MadAction) {
        entries.append(.madAction(id, category, title, label, value))
        id += 1
    }
    func info(_ text: String) {
        entries.append(.madInfo(id, category, text))
        id += 1
    }
    func count(_ value: Int) -> String {
        return value == 0 ? "" : "\(value)"
    }

    section(2000, .interface, nil)
    toggle(more.showOnlineCountAlways, more.showOnlineCountAlwaysInfo, \.showOnlineCountAlways)
    toggle(more.showMutualContactInHeader, nil, \.showMutualContactInHeader)
    toggle(more.showNameInsteadOfPhone, more.showNameInsteadOfPhoneInfo, \.showNameInsteadOfPhone)
    toggle(more.staticAnimatedAvatars, nil, \.staticAnimatedAvatars, subs: [(more.whereChatList, .staticAvatarsChatList), (more.whereChats, .staticAvatarsChats), (more.whereProfile, .staticAvatarsProfile)])
    section(2100, .interface, more.cameraSection)
    let resolutionLabel = settings.cameraResolution == 2160 ? "4K" : (settings.cameraResolution == 720 ? "720p" : "1080p")
    action(more.cameraResolution, resolutionLabel, .cameraResolution)
    action(more.cameraFrameRate, settings.cameraFrameRate == 60 ? "60" : "30", .cameraFrameRate)
    let qualityLabel = settings.roundVideoQuality == 2 ? more.roundVideoQualityMax : (settings.roundVideoQuality == 1 ? more.roundVideoQualityHigh : more.roundVideoQualityStandard)
    action(more.roundVideoQuality, qualityLabel, .roundQuality)
    toggle(more.roundVideoUltraWide, more.roundVideoUltraWideInfo, \.roundVideoUltraWide)
    info(more.cameraInfo)

    section(2200, .chats, nil)
    toggle(more.disableTelegramAI, more.disableTelegramAIInfo, \.disableTelegramAI, subs: [(more.aiInput, .aiInput), (more.aiSummaries, .aiSummaries)])
    toggle(more.disableTonWallet, more.disableTonWalletInfo, \.disableTonWallet)
    toggle(more.showJoinDates, more.showJoinDatesInfo, \.showJoinDates, subs: [(more.joinDateMine, .joinDateMine), (more.joinDateMembers, .joinDateMembers)])
    toggle(more.showMediaInfoInViewer, more.showMediaInfoInViewerInfo, \.showMediaInfoInViewer)
    toggle(more.exactViewCounts, more.exactViewCountsInfo, \.showExactViewCounts)
    section(2300, .chats, more.linksSection)
    toggle(more.cleanSentLinks, nil, \.cleanSentLinks)
    toggle(more.cleanOpenedLinks, nil, \.cleanOpenedLinks)
    info(more.cleanLinksInfo)

    section(2400, .messages, nil)
    toggle(more.forceViewOnceVoice, more.forceViewOnceVoiceInfo, \.forceViewOnceVoice, subs: [(more.voiceMessages, .viewOnceVoice), (more.roundMessages, .viewOnceRounds)])
    toggle(more.sendInlineWithoutVia, more.sendInlineWithoutViaInfo, \.sendInlineWithoutVia)
    toggle(more.freeTranslation, more.freeTranslationInfo, \.freeTranslation)
    toggle(more.freeTranscription, more.freeTranscriptionInfo, \.freeTranscription)

    section(2500, .privacy, nil)
    action(more.accounts.title, "", .profileAccounts)
    toggle(more.showInvisibleChars, more.showInvisibleCharsInfo, \.showInvisibleChars)
    action(more.localNames, count(aliasesCount), .localNames)
    action(more.presenceWatched, count(presenceCount), .presenceList)
    section(2600, .privacy, more.localPassword)
    action(more.localPassword, MadLock.hasPassword ? "" : more.localPasswordNotSet, .localPassword)
    action(more.lockedChats, count(lockedCount), .lockedChats)
    toggle(more.spendLock, more.spendLockInfo, \.spendLockEnabled, subs: [(more.spendReactions, .spendReactions), (more.spendMessages, .spendMessages), (more.spendGifts, .spendGifts), (more.spendTransfer, .spendTransfer), (more.spendPayments, .spendPayments)])
    info(more.localPasswordInfo)

    section(2800, .hiding, nil)
    toggle(more.hideVoiceRecordButton, nil, \.hideVoiceRecordButton)
    toggle(more.hidePinnedMessageBar, nil, \.hidePinnedMessageBar)
    toggle(more.hideGiftInputButton, nil, \.hideGiftInputButton)
    toggle(more.hideBirthdays, more.hideBirthdaysInfo, \.hideBirthdays, subs: [(more.whereChatList, .birthdaysChatList), (more.whereChats, .birthdaysChat), (more.whereProfile, .birthdaysProfile)])
    toggle(more.hideSimilarChannels, nil, \.hideSimilarChannels, subs: [(more.similarInChat, .similarInChat), (more.similarInProfile, .similarInProfile), (more.similarBots, .similarBots)])
    toggle(more.hideProxySponsor, nil, \.hideProxySponsor)
    toggle(more.hidePhoneEverywhere, nil, \.hidePhoneEverywhere, subs: [(more.phoneOthers, .phoneOthers), (more.phoneMine, .phoneMine)])
    section(2900, .hiding, more.hidingTextSection)
    toggle(more.hideForeignAgentLabels, more.hideForeignAgentLabelsInfo, \.hideForeignAgentLabels, subs: [(more.whereMessages, .foreignAgentMessages), (more.whereChatList, .foreignAgentChatList)])
    let rulesCount = madHiddenRuleCount(contentFilter.hiddenRulesSource)
    action(more.hiddenRules, count(rulesCount), .hiddenRules)
    let ruleSubs: [(String, MadSubToggle)] = [(more.whereChats, .hiddenRulesChats), (more.whereChatList, .hiddenRulesChatList), (more.whereNotifications, .hiddenRulesNotifications)]
    for (index, (subTitle, sub)) in ruleSubs.enumerated() where rulesCount > 0 {
        entries.append(.madSub(id + Int32(index), category, subTitle, settings.sub(sub), sub))
    }
    id += Int32(ruleSubs.count)

    section(2700, .other, more.backupSection)
    action(more.exportSettings, "", .exportSettings)
    action(more.importSettings, "", .importSettings)
    action(more.changelogShow, "", .changelogChat)
    info(more.backupInfo)
    return entries
}

private func madHiddenRuleCount(_ source: String) -> Int {
    return source.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
}
