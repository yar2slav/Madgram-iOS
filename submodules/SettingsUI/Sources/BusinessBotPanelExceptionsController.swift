import AccountContext
import AlertUI
import Display
import Foundation
import ItemListPeerActionItem
import ItemListPeerItem
import ItemListUI
import Postbox
import PresentationDataUtils
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences

private final class BusinessBotPanelExceptionsArguments {
    let context: AccountContext
    let add: () -> Void
    let setVisibility: (EnginePeer.Id, Bool) -> Void
    let remove: (EnginePeer.Id) -> Void

    init(context: AccountContext, add: @escaping () -> Void, setVisibility: @escaping (EnginePeer.Id, Bool) -> Void, remove: @escaping (EnginePeer.Id) -> Void) {
        self.context = context
        self.add = add
        self.setVisibility = setVisibility
        self.remove = remove
    }
}

private enum BusinessBotPanelExceptionsEntry: ItemListNodeEntry {
    case add(String)
    case peer(Int32, EnginePeer, Bool, String)
    case info(String)

    var section: ItemListSectionId {
        switch self {
        case .add:
            return 0
        case .peer, .info:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case .add:
            return 0
        case let .peer(index, _, _, _):
            return 100 + index
        case .info:
            return 10000
        }
    }

    static func ==(lhs: BusinessBotPanelExceptionsEntry, rhs: BusinessBotPanelExceptionsEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.add(lhsText), .add(rhsText)):
            return lhsText == rhsText
        case let (.peer(lhsIndex, lhsPeer, lhsValue, lhsLabel), .peer(rhsIndex, rhsPeer, rhsValue, rhsLabel)):
            return lhsIndex == rhsIndex && lhsPeer == rhsPeer && lhsValue == rhsValue && lhsLabel == rhsLabel
        case let (.info(lhsText), .info(rhsText)):
            return lhsText == rhsText
        default:
            return false
        }
    }

    static func <(lhs: BusinessBotPanelExceptionsEntry, rhs: BusinessBotPanelExceptionsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! BusinessBotPanelExceptionsArguments
        switch self {
        case let .add(title):
            return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: nil, title: title, sectionId: self.section, height: .generic, editing: false, action: arguments.add)
        case let .peer(_, peer, value, label):
            let revealOptions = ItemListPeerItemRevealOptions(options: [
                ItemListPeerItemRevealOption(type: .destructive, title: presentationData.strings.Common_Delete, action: {
                    arguments.remove(peer.id)
                })
            ])
            return ItemListPeerItem(
                presentationData: presentationData,
                systemStyle: .glass,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameDisplayOrder: presentationData.nameDisplayOrder,
                context: arguments.context,
                peer: peer,
                presence: nil,
                text: .text(label, .secondary),
                label: .none,
                editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: false),
                revealOptions: revealOptions,
                switchValue: ItemListPeerItemSwitch(value: value, style: .standard),
                enabled: true,
                selectable: true,
                sectionId: self.section,
                action: nil,
                setPeerIdWithRevealedOptions: { _, _ in },
                removePeer: arguments.remove,
                toggleUpdated: { value in
                    arguments.setVisibility(peer.id, value)
                }
            )
        case let .info(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

func businessBotPanelExceptionsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = BusinessBotPanelExceptionsArguments(
        context: context,
        add: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let strings = presentationData.strings.localFeatures.interfaceTuning
            let selectionController = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(
                context: context,
                filter: [.onlyPrivateChats, .excludeSavedMessages, .excludeSecretChats, .excludeRecent, .doNotSearchMessages, .removeSearchHeader],
                hasContactSelector: false,
                title: strings.businessBotPanelAddException
            ))
            selectionController.peerSelected = { [weak selectionController] peer, _ in
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.ChatManagingBot(id: peer.id))
                |> deliverOnMainQueue).startStandalone(next: { managingBot in
                    guard managingBot != nil else {
                        selectionController?.present(textAlertController(context: context, title: nil, text: strings.businessBotPanelNotManaged, actions: [
                            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                        ]), in: .window(.root))
                        return
                    }
                    InterfaceTuningSettingsStore.shared.update { current in
                        var current = current
                        current.businessBotPanelVisibilityOverrides[peer.id.toInt64()] = current.hideBusinessBotPanel
                        return current
                    }
                    selectionController?.dismiss()
                })
            }
            pushControllerImpl?(selectionController)
        },
        setVisibility: { peerId, value in
            InterfaceTuningSettingsStore.shared.update { current in
                var current = current
                let globalValue = !current.hideBusinessBotPanel
                if value == globalValue {
                    current.businessBotPanelVisibilityOverrides.removeValue(forKey: peerId.toInt64())
                } else {
                    current.businessBotPanelVisibilityOverrides[peerId.toInt64()] = value
                }
                return current
            }
        },
        remove: { peerId in
            InterfaceTuningSettingsStore.shared.update { current in
                var current = current
                current.businessBotPanelVisibilityOverrides.removeValue(forKey: peerId.toInt64())
                return current
            }
        }
    )

    let settingsAndPeers = interfaceTuningSettingsSignal()
    |> mapToSignal { settings -> Signal<(InterfaceTuningSettings, [EnginePeer]), NoError> in
        let peerIds = settings.businessBotPanelVisibilityOverrides.keys.sorted().map(EnginePeer.Id.init)
        guard !peerIds.isEmpty else {
            return .single((settings, []))
        }
        return context.engine.data.get(EngineDataMap(peerIds.map { TelegramEngine.EngineData.Item.Peer.Peer(id: $0) }))
        |> map { peerMap in
            return (settings, peerIds.compactMap { peerMap[$0].flatMap { $0 } })
        }
    }

    let signal = combineLatest(context.sharedContext.presentationData, settingsAndPeers)
    |> map { presentationData, settingsAndPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let (settings, peers) = settingsAndPeers
        let strings = presentationData.strings.localFeatures.interfaceTuning
        var entries: [BusinessBotPanelExceptionsEntry] = [.add(strings.businessBotPanelAddException)]
        for (index, peer) in peers.enumerated() {
            let value = settings.isBusinessBotPanelVisible(peerId: peer.id.toInt64())
            entries.append(.peer(Int32(index), peer, value, strings.businessBotPanelShow))
        }
        entries.append(.info(strings.businessBotPanelExceptionsInfo))
        return (
            ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text(strings.businessBotPanelExceptions),
                leftNavigationButton: nil,
                rightNavigationButton: nil,
                backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
                animateChanges: true
            ),
            (ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks), arguments)
        )
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] child in
        controller?.push(child)
    }
    return controller
}
