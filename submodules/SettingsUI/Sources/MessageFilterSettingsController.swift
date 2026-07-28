import AccountContext
import Display
import Foundation
import ItemListPeerItem
import ItemListUI
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import UIKit

private final class MessageFilterControllerArguments {
    let setHideBlockedUsers: (Bool) -> Void
    let setPeerIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    let removePeer: (EnginePeer.Id) -> Void
    let openPeer: (EnginePeer) -> Void
    let showInfo: (String, UIView) -> Void
    let context: AccountContext

    init(
        context: AccountContext,
        setHideBlockedUsers: @escaping (Bool) -> Void,
        setPeerIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void,
        removePeer: @escaping (EnginePeer.Id) -> Void,
        openPeer: @escaping (EnginePeer) -> Void,
        showInfo: @escaping (String, UIView) -> Void
    ) {
        self.context = context
        self.setHideBlockedUsers = setHideBlockedUsers
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.removePeer = removePeer
        self.openPeer = openPeer
        self.showInfo = showInfo
    }
}

private enum MessageFilterSection: Int32 {
    case blocked
    case hiddenPeers
}

private enum MessageFilterEntry: ItemListNodeEntry {
    case hideBlockedUsers(Bool)
    case hideBlockedUsersInfo(String)
    case hiddenPeersHeader(String)
    case hiddenPeersEmpty(String)
    case hiddenPeer(Int32, EnginePeer, Bool)
    case hiddenPeersInfo(String)

    var section: ItemListSectionId {
        switch self {
        case .hideBlockedUsers, .hideBlockedUsersInfo:
            return MessageFilterSection.blocked.rawValue
        case .hiddenPeersHeader, .hiddenPeersEmpty, .hiddenPeer, .hiddenPeersInfo:
            return MessageFilterSection.hiddenPeers.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .hideBlockedUsers:
            return 0
        case .hideBlockedUsersInfo:
            return 1
        case .hiddenPeersHeader:
            return 2
        case .hiddenPeersEmpty:
            return 3
        case let .hiddenPeer(index, _, _):
            return 100 + index
        case .hiddenPeersInfo:
            return 10000
        }
    }

    static func ==(lhs: MessageFilterEntry, rhs: MessageFilterEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.hideBlockedUsers(lhsValue), .hideBlockedUsers(rhsValue)):
            return lhsValue == rhsValue
        case let (.hideBlockedUsersInfo(lhsText), .hideBlockedUsersInfo(rhsText)):
            return lhsText == rhsText
        case let (.hiddenPeersHeader(lhsText), .hiddenPeersHeader(rhsText)):
            return lhsText == rhsText
        case let (.hiddenPeersEmpty(lhsText), .hiddenPeersEmpty(rhsText)):
            return lhsText == rhsText
        case let (.hiddenPeer(lhsIndex, lhsPeer, lhsRevealed), .hiddenPeer(rhsIndex, rhsPeer, rhsRevealed)):
            return lhsIndex == rhsIndex && lhsPeer == rhsPeer && lhsRevealed == rhsRevealed
        case let (.hiddenPeersInfo(lhsText), .hiddenPeersInfo(rhsText)):
            return lhsText == rhsText
        default:
            return false
        }
    }

    static func <(lhs: MessageFilterEntry, rhs: MessageFilterEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MessageFilterControllerArguments
        let strings = presentationData.strings.localFeatures.messageFilter
        switch self {
        case let .hideBlockedUsers(value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: strings.hideBlockedUsers,
                titleBadgeComponent: featureInfoBadgeComponent(color: presentationData.theme.list.itemAccentColor),
                titleBadgeAction: { sourceView in
                    arguments.showInfo(strings.hideBlockedUsersInfo, sourceView)
                },
                value: value,
                maximumNumberOfLines: 2,
                sectionId: self.section,
                style: .blocks,
                updated: arguments.setHideBlockedUsers
            )
        case let .hideBlockedUsersInfo(text), let .hiddenPeersEmpty(text), let .hiddenPeersInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .hiddenPeersHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .hiddenPeer(_, peer, revealed):
            let revealOptions = ItemListPeerItemRevealOptions(options: [ItemListPeerItemRevealOption(type: .destructive, title: strings.show, action: {
                arguments.removePeer(peer.id)
            })])
            return ItemListPeerItem(
                presentationData: presentationData,
                systemStyle: .glass,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                context: arguments.context,
                peer: peer,
                presence: nil,
                text: .none,
                label: .text("✕", .custom(Font.regular(20.0)), presentationData.theme.list.itemDestructiveColor, false),
                editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: revealed),
                revealOptions: revealOptions,
                switchValue: nil,
                enabled: true,
                selectable: true,
                sectionId: self.section,
                action: {
                    arguments.removePeer(peer.id)
                },
                setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                },
                removePeer: { peerId in
                    arguments.removePeer(peerId)
                }
            )
        }
    }
}

public func messageFilterSettingsController(context: AccountContext) -> ViewController {
    var presentTooltip: ((String, UIView) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?

    let revealedPeerId = ValuePromise<EnginePeer.Id?>(nil, ignoreRepeated: true)

    let arguments = MessageFilterControllerArguments(
        context: context,
        setHideBlockedUsers: { value in
            MessageFilterSettingsStore.shared.update { current in
                var current = current
                current.hideBlockedUsersMessages = value
                return current
            }
        },
        setPeerIdWithRevealedOptions: { peerId, _ in
            revealedPeerId.set(peerId)
        },
        removePeer: { peerId in
            MessageFilterSettingsStore.shared.update { current in
                var current = current
                current.shadowBannedPeerIds.remove(peerId.toInt64())
                return current
            }
        },
        openPeer: { peer in
            if let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                pushControllerImpl?(controller)
            }
        },
        showInfo: { text, sourceView in
            presentTooltip?(text, sourceView)
        }
    )

    let hiddenPeers = messageFilterSettingsSignal()
    |> mapToSignal { settings -> Signal<(MessageFilterSettings, [EnginePeer]), NoError> in
        let peerIds = settings.shadowBannedPeerIds.sorted().map { EnginePeer.Id($0) }
        if peerIds.isEmpty {
            return .single((settings, []))
        }
        return context.engine.data.get(EngineDataMap(peerIds.map { TelegramEngine.EngineData.Item.Peer.Peer(id: $0) }))
        |> map { peers -> (MessageFilterSettings, [EnginePeer]) in
            return (settings, peerIds.compactMap { peers[$0].flatMap { $0 } })
        }
    }

    let signal = combineLatest(context.sharedContext.presentationData, hiddenPeers, revealedPeerId.get())
    |> map { presentationData, settingsAndPeers, revealedPeerId -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let (settings, peers) = settingsAndPeers
        let strings = presentationData.strings.localFeatures.messageFilter

        var entries: [MessageFilterEntry] = [
            .hideBlockedUsers(settings.hideBlockedUsersMessages),
            .hideBlockedUsersInfo(strings.hideBlockedUsersInfo),
            .hiddenPeersHeader(strings.hiddenPeersSection)
        ]
        if peers.isEmpty {
            entries.append(.hiddenPeersEmpty(strings.hiddenPeersEmpty))
        } else {
            for (index, peer) in peers.enumerated() {
                entries.append(.hiddenPeer(Int32(index), peer, peer.id == revealedPeerId))
            }
            entries.append(.hiddenPeersInfo(strings.hiddenPeersInfo))
        }

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
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
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
