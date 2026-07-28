import AccountContext
import ComponentFlow
import Display
import Foundation
import ItemListUI
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import UIKit

private final class GhostModeControllerArguments {
    let update: (@escaping (GhostModeSettings) -> GhostModeSettings) -> Void
    let showInfo: (String, UIView) -> Void

    init(
        update: @escaping (@escaping (GhostModeSettings) -> GhostModeSettings) -> Void,
        showInfo: @escaping (String, UIView) -> Void
    ) {
        self.update = update
        self.showInfo = showInfo
    }
}

private enum GhostModeSection: Int32 {
    case master
    case privacy
    case behavior
}

private enum GhostModeEntry: ItemListNodeEntry {
    case enabled(Bool)
    case suppressRead(Bool, Bool)
    case suppressStories(Bool, Bool)
    case suppressOnline(Bool, Bool)
    case suppressTyping(Bool, Bool)
    case keepViewOnceMedia(Bool, Bool)
    case revealOnInteractions(Bool, Bool)
    case autoOffline(Bool, Bool)

    var section: ItemListSectionId {
        switch self {
        case .enabled:
            return GhostModeSection.master.rawValue
        case .suppressRead, .suppressStories, .suppressOnline, .suppressTyping, .keepViewOnceMedia:
            return GhostModeSection.privacy.rawValue
        case .revealOnInteractions, .autoOffline:
            return GhostModeSection.behavior.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .enabled: return 0
        case .suppressRead: return 1
        case .suppressStories: return 2
        case .suppressOnline: return 3
        case .suppressTyping: return 4
        case .keepViewOnceMedia: return 5
        case .revealOnInteractions: return 6
        case .autoOffline: return 7
        }
    }

    static func == (lhs: GhostModeEntry, rhs: GhostModeEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.enabled(lhs), .enabled(rhs)):
            return lhs == rhs
        case let (.suppressRead(lhsValue, lhsEnabled), .suppressRead(rhsValue, rhsEnabled)),
             let (.suppressStories(lhsValue, lhsEnabled), .suppressStories(rhsValue, rhsEnabled)),
             let (.suppressOnline(lhsValue, lhsEnabled), .suppressOnline(rhsValue, rhsEnabled)),
             let (.suppressTyping(lhsValue, lhsEnabled), .suppressTyping(rhsValue, rhsEnabled)),
             let (.keepViewOnceMedia(lhsValue, lhsEnabled), .keepViewOnceMedia(rhsValue, rhsEnabled)),
             let (.revealOnInteractions(lhsValue, lhsEnabled), .revealOnInteractions(rhsValue, rhsEnabled)),
             let (.autoOffline(lhsValue, lhsEnabled), .autoOffline(rhsValue, rhsEnabled)):
            return lhsValue == rhsValue && lhsEnabled == rhsEnabled
        default:
            return false
        }
    }

    static func < (lhs: GhostModeEntry, rhs: GhostModeEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! GhostModeControllerArguments
        let strings = presentationData.strings.localFeatures.ghostMode
        let switchItem: (String, String, Bool, Bool, @escaping (GhostModeSettings, Bool) -> GhostModeSettings) -> ListViewItem = { title, info, value, enabled, update in
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: title,
                titleBadgeComponent: featureInfoBadgeComponent(color: presentationData.theme.list.itemAccentColor),
                titleBadgeAction: { sourceView in
                    arguments.showInfo(info, sourceView)
                },
                value: value,
                enabled: enabled,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.update { current in
                        return update(current, value)
                    }
                }
            )
        }
        switch self {
        case let .enabled(value):
            return switchItem(strings.title, strings.masterInfo, value, true, { current, value in
                var current = current
                current.isEnabled = value
                return current
            })
        case let .suppressRead(value, enabled):
            return switchItem(strings.suppressMessageReadReceipts, strings.suppressMessageReadReceiptsInfo, value, enabled, { current, value in
                var current = current
                current.suppressMessageReadReceipts = value
                return current
            })
        case let .suppressStories(value, enabled):
            return switchItem(strings.suppressStoryReadReceipts, strings.suppressStoryReadReceiptsInfo, value, enabled, { current, value in
                var current = current
                current.suppressStoryReadReceipts = value
                return current
            })
        case let .suppressOnline(value, enabled):
            return switchItem(strings.suppressOnlineStatus, strings.suppressOnlineStatusInfo, value, enabled, { current, value in
                var current = current
                current.suppressOnlineStatus = value
                return current
            })
        case let .suppressTyping(value, enabled):
            return switchItem(strings.suppressTypingStatus, strings.suppressTypingStatusInfo, value, enabled, { current, value in
                var current = current
                current.suppressTypingStatus = value
                return current
            })
        case let .keepViewOnceMedia(value, enabled):
            return switchItem(strings.keepViewOnceMedia, strings.keepViewOnceMediaInfo, value, enabled, { current, value in
                var current = current
                current.keepViewOnceMedia = value
                return current
            })
        case let .revealOnInteractions(value, enabled):
            return switchItem(strings.revealOnInteractions, strings.revealOnInteractionsInfo, value, enabled, { current, value in
                var current = current
                current.revealOnInteractions = value
                return current
            })
        case let .autoOffline(value, enabled):
            return switchItem(strings.goOfflineAutomatically, strings.goOfflineAutomaticallyInfo, value, enabled, { current, value in
                var current = current
                current.goOfflineAutomatically = value
                return current
            })
        }
    }
}

public func ghostModeSettingsController(context: AccountContext) -> ViewController {
    var presentTooltip: ((String, UIView) -> Void)?
    let settings = context.account.postbox.preferencesView(keys: [PreferencesKeys.ghostModeSettings])
    |> map { view -> GhostModeSettings in
        return view.values[PreferencesKeys.ghostModeSettings]?.get(GhostModeSettings.self) ?? .defaultSettings
    }

    let arguments = GhostModeControllerArguments(
        update: { f in
            let _ = updateGhostModeSettingsInteractively(postbox: context.account.postbox, f).start()
        },
        showInfo: { text, sourceView in
            presentTooltip?(text, sourceView)
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, settings)
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let enabled = settings.isEnabled
        let strings = presentationData.strings.localFeatures.ghostMode
        let entries: [GhostModeEntry] = [
            .enabled(settings.isEnabled),
            .suppressRead(settings.suppressMessageReadReceipts, enabled),
            .suppressStories(settings.suppressStoryReadReceipts, enabled),
            .suppressOnline(settings.suppressOnlineStatus, enabled),
            .suppressTyping(settings.suppressTypingStatus, enabled),
            .keepViewOnceMedia(settings.keepViewOnceMedia, enabled),
            .revealOnInteractions(settings.revealOnInteractions, enabled),
            .autoOffline(settings.goOfflineAutomatically, enabled)
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
    var currentTooltipController: TooltipController?
    presentTooltip = { [weak controller] text, sourceView in
        guard let controller else {
            return
        }
        currentTooltipController?.dismiss()
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        currentTooltipController = presentFeatureInfoTooltip(
            text: text,
            sourceView: sourceView,
            presentationData: presentationData,
            controller: controller
        )
    }
    return controller
}
