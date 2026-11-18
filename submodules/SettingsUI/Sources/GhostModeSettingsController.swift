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
    let openException: (Int64, String) -> Void

    init(
        update: @escaping (@escaping (GhostModeSettings) -> GhostModeSettings) -> Void,
        showInfo: @escaping (String, UIView) -> Void,
        openException: @escaping (Int64, String) -> Void
    ) {
        self.update = update
        self.showInfo = showInfo
        self.openException = openException
    }
}

private enum GhostModeSection: Int32 {
    case master
    case privacy
    case behavior
    case exceptions
}

private enum GhostModeEntry: ItemListNodeEntry {
    case enabled(Bool)
    case masterInfo(String)
    case privacyHeader(String)
    case suppressRead(Bool, Bool)
    case suppressStories(Bool, Bool)
    case suppressOnline(Bool, Bool)
    case suppressTyping(Bool, Bool)
    case keepViewOnceMedia(Bool, Bool)
    case behaviorHeader(String)
    case revealOnInteractions(Bool, Bool)
    case autoOffline(Bool, Bool)
    case exceptionsHeader(String)
    case exception(Int32, Int64, String, String)
    case exceptionsEmpty(String)
    case exceptionsInfo(String)

    var section: ItemListSectionId {
        switch self {
        case .enabled, .masterInfo:
            return GhostModeSection.master.rawValue
        case .privacyHeader, .suppressRead, .suppressStories, .suppressOnline, .suppressTyping, .keepViewOnceMedia:
            return GhostModeSection.privacy.rawValue
        case .behaviorHeader, .revealOnInteractions, .autoOffline:
            return GhostModeSection.behavior.rawValue
        case .exceptionsHeader, .exception, .exceptionsEmpty, .exceptionsInfo:
            return GhostModeSection.exceptions.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .enabled: return 0
        case .masterInfo: return 1
        case .privacyHeader: return 2
        case .suppressRead: return 3
        case .suppressStories: return 4
        case .suppressOnline: return 5
        case .suppressTyping: return 6
        case .keepViewOnceMedia: return 7
        case .behaviorHeader: return 8
        case .revealOnInteractions: return 9
        case .autoOffline: return 10
        case .exceptionsHeader: return 11
        case .exceptionsEmpty: return 12
        case let .exception(index, _, _, _): return 100 + index
        case .exceptionsInfo: return 100000
        }
    }

    static func == (lhs: GhostModeEntry, rhs: GhostModeEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.enabled(lhs), .enabled(rhs)):
            return lhs == rhs
        case let (.masterInfo(lhsText), .masterInfo(rhsText)),
             let (.privacyHeader(lhsText), .privacyHeader(rhsText)),
             let (.behaviorHeader(lhsText), .behaviorHeader(rhsText)),
             let (.exceptionsHeader(lhsText), .exceptionsHeader(rhsText)),
             let (.exceptionsEmpty(lhsText), .exceptionsEmpty(rhsText)),
             let (.exceptionsInfo(lhsText), .exceptionsInfo(rhsText)):
            return lhsText == rhsText
        case let (.exception(lhsIndex, lhsPeerId, lhsTitle, lhsLabel), .exception(rhsIndex, rhsPeerId, rhsTitle, rhsLabel)):
            return lhsIndex == rhsIndex && lhsPeerId == rhsPeerId && lhsTitle == rhsTitle && lhsLabel == rhsLabel
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
        let switchItem: (String, String?, Bool, Bool, @escaping (GhostModeSettings, Bool) -> GhostModeSettings) -> ListViewItem = { title, info, value, enabled, update in
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
            return switchItem(strings.title, nil, value, true, { current, value in
                var current = current
                current.isEnabled = value
                return current
            })
        case let .masterInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .privacyHeader(text), let .behaviorHeader(text), let .exceptionsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .exception(_, peerId, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openException(peerId, title)
            })
        case let .exceptionsEmpty(text):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, enabled: false, label: "", sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .exceptionsInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
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
    var presentControllerImpl: ((ViewController) -> Void)?
    let settings = context.engine.messages.ghostModeSettings()

    let arguments = GhostModeControllerArguments(
        update: { f in
            let _ = context.engine.messages.updateGhostModeSettingsInteractively(f).start()
        },
        showInfo: { text, sourceView in
            presentTooltip?(text, sourceView)
        },
        openException: { peerId, title in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let sheet = ActionSheetController(presentationData: presentationData)
            sheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: title),
                    ActionSheetButtonItem(title: presentationData.strings.localFeatures.extras.ghostExceptionRemove, color: .destructive, action: { [weak sheet] in
                        sheet?.dismissAnimated()
                        let _ = context.engine.messages.updateGhostModeSettingsInteractively({ current in
                            return current.withPeerOverride(nil, peerId: EnginePeer.Id(peerId))
                        }).start()
                    })
                ]),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak sheet] in
                        sheet?.dismissAnimated()
                    })
                ])
            ])
            presentControllerImpl?(sheet)
        }
    )

    let exceptionPeers = settings
    |> map { settings -> [Int64] in
        return settings.peerOverrides.keys.sorted()
    }
    |> distinctUntilChanged
    |> mapToSignal { peerIds -> Signal<[Int64: String], NoError> in
        if peerIds.isEmpty {
            return .single([:])
        }
        return context.engine.data.subscribe(EngineDataMap(peerIds.map { TelegramEngine.EngineData.Item.Peer.Peer(id: EnginePeer.Id($0)) }))
        |> map { peers -> [Int64: String] in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var result: [Int64: String] = [:]
            for (id, peer) in peers {
                if let peer {
                    result[id.toInt64()] = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                }
            }
            return result
        }
    }

    let signal = combineLatest(context.sharedContext.presentationData, settings, exceptionPeers)
    |> map { presentationData, settings, exceptionPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let enabled = settings.isEnabled || settings.peerOverrides.values.contains(true)
        let extras = presentationData.strings.localFeatures.extras
        let strings = presentationData.strings.localFeatures.ghostMode
        var entries: [GhostModeEntry] = [
            .enabled(settings.isEnabled),
            .masterInfo(strings.masterInfo),
            .privacyHeader(strings.hideSection),
            .suppressRead(settings.suppressMessageReadReceipts, enabled),
            .suppressStories(settings.suppressStoryReadReceipts, enabled),
            .suppressOnline(settings.suppressOnlineStatus, enabled),
            .suppressTyping(settings.suppressTypingStatus, enabled),
            .keepViewOnceMedia(settings.keepViewOnceMedia, true),
            .behaviorHeader(strings.behaviorSection),
            .revealOnInteractions(settings.revealOnInteractions, enabled),
            .autoOffline(settings.goOfflineAutomatically, enabled)
        ]
        entries.append(.exceptionsHeader(extras.ghostExceptions.uppercased()))
        if settings.peerOverrides.isEmpty {
            entries.append(.exceptionsEmpty(extras.ghostExceptionsEmpty))
        } else {
            let sortedOverrides = settings.peerOverrides.sorted(by: { lhs, rhs in
                let lhsTitle = exceptionPeers[lhs.key] ?? ""
                let rhsTitle = exceptionPeers[rhs.key] ?? ""
                if lhsTitle != rhsTitle {
                    return lhsTitle < rhsTitle
                }
                return lhs.key < rhs.key
            })
            for (index, item) in sortedOverrides.enumerated() {
                let title = exceptionPeers[item.key] ?? "\(item.key)"
                entries.append(.exception(Int32(index), item.key, title, item.value ? extras.ghostExceptionOn : extras.ghostExceptionOff))
            }
        }
        entries.append(.exceptionsInfo(extras.ghostExceptionsInfo))
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
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
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
