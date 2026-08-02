import AccountContext
import Display
import Foundation
import ItemListUI
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import UIKit

private enum InterfaceTuningSection: Int32 {
    case tabs
    case profiles
    case stories
    case media
    case privacy
    case business
}

private enum InterfaceTuningKey: Int32 {
    case concealBottomBar
    case showContactsShortcut
    case showCallsShortcut
    case showTabLabels
    case showSearchShortcut
    case stretchBottomBar
    case showProfileIdentifiers
    case showDataCenter
    case showRegistrationDate
    case showChatCreationDate
    case hideStoryStrip
    case disableStoryCameraSwipe
    case confirmStoryOpen
    case allowStoryRepost
    case startRoundVideoWithRearCamera
    case hideGalleryCamera
    case hidePhoneInSettings
    case hideBusinessBotPanel
}

private final class InterfaceTuningArguments {
    let update: (InterfaceTuningKey, Bool) -> Void
    let showInfo: (String, UIView) -> Void
    let openBusinessBotExceptions: () -> Void

    init(update: @escaping (InterfaceTuningKey, Bool) -> Void, showInfo: @escaping (String, UIView) -> Void, openBusinessBotExceptions: @escaping () -> Void) {
        self.update = update
        self.showInfo = showInfo
        self.openBusinessBotExceptions = openBusinessBotExceptions
    }
}

private enum InterfaceTuningEntry: ItemListNodeEntry {
    case header(Int32, InterfaceTuningSection, String)
    case toggle(InterfaceTuningKey, InterfaceTuningSection, String, String, Bool, Bool)
    case disclosure(Int32, InterfaceTuningSection, String, String)
    case footer(Int32, InterfaceTuningSection, String)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .toggle(_, section, _, _, _, _), let .disclosure(_, section, _, _), let .footer(_, section, _):
            return section.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .disclosure(id, _, _, _), let .footer(id, _, _):
            return id
        case let .toggle(key, _, _, _, _, _):
            switch key {
            case .concealBottomBar: return 1
            case .showContactsShortcut: return 2
            case .showCallsShortcut: return 3
            case .showTabLabels: return 4
            case .showSearchShortcut: return 5
            case .stretchBottomBar: return 6
            case .showProfileIdentifiers: return 11
            case .showDataCenter: return 12
            case .showRegistrationDate: return 13
            case .showChatCreationDate: return 14
            case .hideStoryStrip: return 21
            case .disableStoryCameraSwipe: return 22
            case .confirmStoryOpen: return 23
            case .allowStoryRepost: return 24
            case .startRoundVideoWithRearCamera: return 31
            case .hideGalleryCamera: return 32
            case .hidePhoneInSettings: return 41
            case .hideBusinessBotPanel: return 51
            }
        }
    }

    static func ==(lhs: InterfaceTuningEntry, rhs: InterfaceTuningEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.header(lhsId, lhsSection, lhsText), .header(rhsId, rhsSection, rhsText)):
            return lhsId == rhsId && lhsSection == rhsSection && lhsText == rhsText
        case let (.toggle(lhsKey, lhsSection, lhsTitle, lhsInfo, lhsValue, lhsEnabled), .toggle(rhsKey, rhsSection, rhsTitle, rhsInfo, rhsValue, rhsEnabled)):
            return lhsKey == rhsKey && lhsSection == rhsSection && lhsTitle == rhsTitle && lhsInfo == rhsInfo && lhsValue == rhsValue && lhsEnabled == rhsEnabled
        case let (.disclosure(lhsId, lhsSection, lhsTitle, lhsLabel), .disclosure(rhsId, rhsSection, rhsTitle, rhsLabel)):
            return lhsId == rhsId && lhsSection == rhsSection && lhsTitle == rhsTitle && lhsLabel == rhsLabel
        case let (.footer(lhsId, lhsSection, lhsText), .footer(rhsId, rhsSection, rhsText)):
            return lhsId == rhsId && lhsSection == rhsSection && lhsText == rhsText
        default:
            return false
        }
    }

    static func <(lhs: InterfaceTuningEntry, rhs: InterfaceTuningEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! InterfaceTuningArguments
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(key, _, title, info, value, enabled):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: title,
                titleBadgeComponent: featureInfoBadgeComponent(color: presentationData.theme.list.itemAccentColor),
                titleBadgeAction: { sourceView in
                    arguments.showInfo(info, sourceView)
                },
                value: value,
                enabled: enabled,
                maximumNumberOfLines: 2,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.update(key, value)
                }
            )
        case let .disclosure(_, _, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openBusinessBotExceptions()
            })
        case let .footer(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func updatedInterfaceTuningSettings(
    _ current: InterfaceTuningSettings,
    key: InterfaceTuningKey,
    value: Bool
) -> InterfaceTuningSettings {
    var current = current
    switch key {
    case .concealBottomBar:
        current.concealBottomBar = value
    case .showContactsShortcut:
        current.showContactsShortcut = value
    case .showCallsShortcut:
        current.showCallsShortcut = value
    case .showTabLabels:
        current.showTabLabels = value
    case .showSearchShortcut:
        current.showSearchShortcut = value
    case .stretchBottomBar:
        current.stretchBottomBar = value
    case .showProfileIdentifiers:
        current.showProfileIdentifiers = value
    case .showDataCenter:
        current.showDataCenter = value
    case .showRegistrationDate:
        current.showRegistrationDate = value
    case .showChatCreationDate:
        current.showChatCreationDate = value
    case .hideStoryStrip:
        current.hideStoryStrip = value
    case .disableStoryCameraSwipe:
        current.disableStoryCameraSwipe = value
    case .confirmStoryOpen:
        current.confirmStoryOpen = value
    case .allowStoryRepost:
        current.allowStoryRepost = value
    case .startRoundVideoWithRearCamera:
        current.startRoundVideoWithRearCamera = value
    case .hideGalleryCamera:
        current.hideGalleryCamera = value
    case .hidePhoneInSettings:
        current.hidePhoneInSettings = value
    case .hideBusinessBotPanel:
        current.hideBusinessBotPanel = value
    }
    return current
}

public func interfaceTuningSettingsController(context: AccountContext) -> ViewController {
    var presentTooltip: ((String, UIView) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = InterfaceTuningArguments(
        update: { key, value in
            InterfaceTuningSettingsStore.shared.update { current in
                return updatedInterfaceTuningSettings(current, key: key, value: value)
            }
        },
        showInfo: { text, sourceView in
            presentTooltip?(text, sourceView)
        },
        openBusinessBotExceptions: {
            pushControllerImpl?(businessBotPanelExceptionsController(context: context))
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, interfaceTuningSettingsSignal())
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = presentationData.strings.localFeatures.interfaceTuning
        let barControlsEnabled = !settings.concealBottomBar
        let entries: [InterfaceTuningEntry] = [
            .header(0, .tabs, strings.tabsSection),
            .toggle(.concealBottomBar, .tabs, strings.concealBottomBar, strings.concealBottomBarInfo, settings.concealBottomBar, true),
            .toggle(.showContactsShortcut, .tabs, strings.showContactsShortcut, strings.showContactsShortcutInfo, settings.showContactsShortcut, barControlsEnabled),
            .toggle(.showCallsShortcut, .tabs, strings.showCallsShortcut, strings.showCallsShortcutInfo, settings.showCallsShortcut, barControlsEnabled),
            .toggle(.showTabLabels, .tabs, strings.showTabLabels, strings.showTabLabelsInfo, settings.showTabLabels, barControlsEnabled),
            .toggle(.showSearchShortcut, .tabs, strings.showSearchShortcut, strings.showSearchShortcutInfo, settings.showSearchShortcut, barControlsEnabled),
            .toggle(.stretchBottomBar, .tabs, strings.stretchBottomBar, strings.stretchBottomBarInfo, settings.stretchBottomBar, barControlsEnabled),
            .footer(7, .tabs, strings.restartNotice),

            .header(10, .profiles, strings.profilesSection),
            .toggle(.showProfileIdentifiers, .profiles, strings.showProfileIdentifiers, strings.showProfileIdentifiersInfo, settings.showProfileIdentifiers, true),
            .toggle(.showDataCenter, .profiles, strings.showDataCenter, strings.showDataCenterInfo, settings.showDataCenter, true),
            .toggle(.showRegistrationDate, .profiles, strings.showRegistrationDate, strings.showRegistrationDateInfo, settings.showRegistrationDate, true),
            .toggle(.showChatCreationDate, .profiles, strings.showChatCreationDate, strings.showChatCreationDateInfo, settings.showChatCreationDate, true),

            .header(20, .stories, strings.storiesSection),
            .toggle(.hideStoryStrip, .stories, strings.hideStoryStrip, strings.hideStoryStripInfo, settings.hideStoryStrip, true),
            .toggle(.disableStoryCameraSwipe, .stories, strings.disableStoryCameraSwipe, strings.disableStoryCameraSwipeInfo, settings.disableStoryCameraSwipe, true),
            .toggle(.confirmStoryOpen, .stories, strings.confirmStoryOpen, strings.confirmStoryOpenInfo, settings.confirmStoryOpen, true),
            .toggle(.allowStoryRepost, .stories, strings.allowStoryRepost, strings.allowStoryRepostInfo, settings.allowStoryRepost, true),

            .header(30, .media, strings.mediaSection),
            .toggle(.startRoundVideoWithRearCamera, .media, strings.startRoundVideoWithRearCamera, strings.startRoundVideoWithRearCameraInfo, settings.startRoundVideoWithRearCamera, true),
            .toggle(.hideGalleryCamera, .media, strings.hideGalleryCamera, strings.hideGalleryCameraInfo, settings.hideGalleryCamera ?? false, true),

            .header(40, .privacy, strings.privacySection),
            .toggle(.hidePhoneInSettings, .privacy, strings.hidePhoneInSettings, strings.hidePhoneInSettingsInfo, settings.hidePhoneInSettings, true),

            .header(50, .business, strings.businessSection),
            .toggle(.hideBusinessBotPanel, .business, strings.hideBusinessBotPanel, strings.hideBusinessBotPanelInfo, settings.hideBusinessBotPanel, true),
            .disclosure(52, .business, strings.businessBotPanelExceptions, settings.businessBotPanelVisibilityOverrides.isEmpty ? "" : "\(settings.businessBotPanelVisibilityOverrides.count)"),
            .footer(53, .business, strings.businessBotPanelExceptionsInfo)
        ]
        return (
            ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text(strings.title),
                leftNavigationButton: nil,
                rightNavigationButton: nil,
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
    pushControllerImpl = { [weak controller] child in
        controller?.push(child)
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
