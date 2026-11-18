import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

private let ghostModeServerReadStateBatchSize = 100

/// Forgets every read that Ghost Mode kept to itself, so a cold start comes back to what the server
/// still considers unread.
///
/// Two steps. The snapshot rollback lands first: it needs no network and restores the unread chats
/// immediately. The server pass then corrects the unread counters, which the snapshots alone cannot
/// get right — a marker only remembers the state from before the *first* suppressed read, so a chat
/// read several times in one session would come back with a stale count.
///
/// Only peer-level cloud read states are verified against the server. Forum threads and stories fall
/// back to their snapshots; their server state is reconciled by the regular topic and story syncs.
func managedGhostModeLaunchReadStateReset(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> (peerIds: [PeerId], withoutSnapshot: Set<PeerId>) in
        let plan = ghostModeResetPlan(
            markers: transaction.getAllGhostModeReadStates(),
            includeMessages: true,
            includeStories: true
        )
        let rolledBackPeerIds = ghostModeApplyResetPlan(transaction: transaction, plan: plan)

        // Chats the user has since answered are left read; asking the server about them would only
        // put the unread badge back.
        let withoutSnapshot = Set(plan.peersNeedingServerState.filter { peerId in
            return !ghostModeUserWroteLast(transaction: transaction, peerId: peerId, namespace: Namespaces.Message.Cloud)
        })
        var peerIds = withoutSnapshot
        peerIds.formUnion(rolledBackPeerIds)
        return (Array(peerIds), withoutSnapshot)
    }
    |> mapToSignal { reset -> Signal<Never, NoError> in
        let peerIds = reset.peerIds
        if peerIds.isEmpty {
            return .complete()
        }
        var signal: Signal<Never, NoError> = .complete()
        for offset in stride(from: 0, to: peerIds.count, by: ghostModeServerReadStateBatchSize) {
            let batch = Array(peerIds[offset ..< min(offset + ghostModeServerReadStateBatchSize, peerIds.count)])
            signal = signal
            |> then(applyServerReadStates(
                postbox: postbox,
                network: network,
                peerIds: batch,
                peerIdsWithoutSnapshot: reset.withoutSnapshot
            ))
        }
        return signal
    }
}

private func applyServerReadStates(
    postbox: Postbox,
    network: Network,
    peerIds: [PeerId],
    peerIdsWithoutSnapshot: Set<PeerId>
) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> [Api.InputDialogPeer] in
        return peerIds.compactMap { peerId -> Api.InputDialogPeer? in
            guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputPeer) else {
                return nil
            }
            return .inputDialogPeer(.init(peer: inputPeer))
        }
    }
    |> mapToSignal { inputPeers -> Signal<Never, NoError> in
        if inputPeers.isEmpty {
            return .complete()
        }
        return network.request(Api.functions.messages.getPeerDialogs(peers: inputPeers))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.PeerDialogs?, NoError> in
            // Best effort: without the server's answer the snapshot rollback already stands.
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result else {
                return .complete()
            }
            let dialogs: [Api.Dialog]
            switch result {
            case let .peerDialogs(peerDialogsData):
                dialogs = peerDialogsData.dialogs
            }
            return postbox.transaction { transaction -> Void in
                var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
                for dialog in dialogs {
                    guard case let .dialog(dialogData) = dialog, let peerId = dialog.peerId else {
                        continue
                    }
                    guard let readState = serverReadStateToApply(
                        transaction: transaction,
                        peerId: peerId,
                        dialogData: dialogData,
                        overwriteReadsAhead: peerIdsWithoutSnapshot.contains(peerId)
                    ) else {
                        continue
                    }
                    readStates[peerId] = [Namespaces.Message.Cloud: readState]
                }
                if !readStates.isEmpty {
                    transaction.resetIncomingReadStates(readStates)
                }
            }
            |> ignoreValues
        }
    }
}

/// Decides whether the dialog the server just described may overwrite what is stored locally.
///
/// A fresh Ghost Mode marker means the user re-read the chat while the request was in flight; that
/// read wins, or the chat would jump back to unread under their finger.
///
/// A local read id ahead of the server's normally means the read arrived from another device after
/// the rollback, and must not be undone. `overwriteReadsAhead` inverts that for peers whose marker
/// carried no rollback snapshot: there the local state is ahead precisely because Ghost Mode left it
/// there, and the server's answer is the only way to recover the unread state.
private func serverReadStateToApply(
    transaction: Transaction,
    peerId: PeerId,
    dialogData: Api.Dialog.Cons_dialog,
    overwriteReadsAhead: Bool
) -> PeerReadState? {
    if transaction.getGhostModeReadState(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud) != nil {
        return nil
    }

    var localMaxIncomingReadId: Int32 = 0
    var localMaxOutgoingReadId: Int32 = 0
    if let states = transaction.getPeerReadStates(peerId) {
        for (namespace, state) in states where namespace == Namespaces.Message.Cloud {
            if case let .idBased(maxIncomingReadId, maxOutgoingReadId, _, _, _) = state {
                localMaxIncomingReadId = maxIncomingReadId
                localMaxOutgoingReadId = maxOutgoingReadId
            }
            break
        }
    }
    if !overwriteReadsAhead && dialogData.readInboxMaxId < localMaxIncomingReadId {
        return nil
    }

    return .idBased(
        maxIncomingReadId: dialogData.readInboxMaxId,
        maxOutgoingReadId: max(dialogData.readOutboxMaxId, localMaxOutgoingReadId),
        maxKnownId: dialogData.topMessage,
        count: dialogData.unreadCount,
        markedUnread: (dialogData.flags & (1 << 3)) != 0
    )
}
