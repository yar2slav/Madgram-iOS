import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public struct GhostModeChatState: Equatable {
    public let settings: GhostModeSettings
    public let pendingReadIndex: MessageIndex?

    public init(settings: GhostModeSettings, pendingReadIndex: MessageIndex?) {
        self.settings = settings
        self.pendingReadIndex = pendingReadIndex
    }

    public var hasPendingReadReceipt: Bool {
        return self.pendingReadIndex != nil
    }
}

func _internal_ghostModeChatState(postbox: Postbox, peerId: PeerId, threadId: Int64?) -> Signal<GhostModeChatState, NoError> {
    return postbox.preferencesView(keys: [
        PreferencesKeys.ghostModeSettings,
        PreferencesKeys.ghostModeReadStateVersion
    ])
    |> mapToSignal { _ -> Signal<GhostModeChatState, NoError> in
        return postbox.transaction { transaction -> GhostModeChatState in
            let settings = ghostModeSettings(transaction: transaction)
            let marker = transaction.getGhostModeReadState(
                peerId: peerId,
                threadId: threadId,
                namespace: Namespaces.Message.Cloud
            )
            return GhostModeChatState(settings: settings, pendingReadIndex: marker?.maxReadIndex)
        }
    }
    |> distinctUntilChanged
}

func _internal_commitGhostModeReadState(account: Account, peerId: PeerId, threadId: Int64?) -> Signal<Bool, NoError> {
    return account.postbox.transaction { transaction -> (GhostModeReadStateMarker, Signal<Bool, NoError>)? in
        guard let marker = transaction.getGhostModeReadState(
            peerId: peerId,
            threadId: threadId,
            namespace: Namespaces.Message.Cloud
        ) else {
            return nil
        }
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return nil
        }

        let request: Signal<Bool, NoError>
        if let threadId {
            if let channel = peer as? TelegramChannel, channel.flags.contains(.isMonoforum), let subPeer = transaction.getPeer(PeerId(threadId)).flatMap(apiInputPeer) {
                request = account.network.request(Api.functions.messages.readSavedHistory(parentPeer: inputPeer, peer: subPeer, maxId: marker.maxReadIndex.id.id))
                |> map { _ in true }
                |> `catch` { _ -> Signal<Bool, NoError> in .single(false) }
            } else {
                request = account.network.request(Api.functions.messages.readDiscussion(peer: inputPeer, msgId: Int32(clamping: threadId), readMaxId: marker.maxReadIndex.id.id))
                |> map { _ in true }
                |> `catch` { _ -> Signal<Bool, NoError> in .single(false) }
            }
        } else {
            switch inputPeer {
            case let .inputPeerChannel(data):
                request = account.network.request(Api.functions.channels.readHistory(
                    channel: .inputChannel(.init(channelId: data.channelId, accessHash: data.accessHash)),
                    maxId: marker.maxReadIndex.id.id
                ))
                |> map { _ in true }
                |> `catch` { _ -> Signal<Bool, NoError> in .single(false) }
            default:
                request = account.network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: marker.maxReadIndex.id.id))
                |> map { _ in true }
                |> `catch` { _ -> Signal<Bool, NoError> in .single(false) }
            }
        }
        return (marker, request)
    }
    |> mapToSignal { markerAndRequest -> Signal<Bool, NoError> in
        guard let (marker, request) = markerAndRequest else {
            return .single(true)
        }
        return request
        |> mapToSignal { success -> Signal<Bool, NoError> in
            guard success else {
                return .single(false)
            }
            return account.postbox.transaction { transaction -> Bool in
                transaction.removeGhostModeReadState(
                    peerId: marker.peerId,
                    threadId: marker.threadId,
                    namespace: marker.namespace
                )
                updateGhostModeReadStateVersion(transaction: transaction)
                return true
            }
        }
    }
}

func _internal_commitGhostModeStoryReadState(account: Account, storyId: StoryId) -> Signal<Bool, NoError> {
    return account.postbox.transaction { transaction -> (GhostModeReadStateMarker, Api.InputPeer)? in
        guard let marker = transaction.getGhostModeReadState(
            peerId: storyId.peerId,
            threadId: nil,
            namespace: ghostModeStoryNamespace
        ), marker.maxReadIndex.id.id >= storyId.id else {
            return nil
        }
        guard let inputPeer = transaction.getPeer(storyId.peerId).flatMap(apiInputPeer) else {
            return nil
        }
        return (marker, inputPeer)
    }
    |> mapToSignal { markerAndPeer -> Signal<Bool, NoError> in
        guard let (marker, inputPeer) = markerAndPeer else {
            return .single(true)
        }
        return account.network.request(Api.functions.stories.incrementStoryViews(peer: inputPeer, id: [storyId.id]))
        |> map { _ in true }
        |> `catch` { _ -> Signal<Bool, NoError> in
            return .single(false)
        }
        |> mapToSignal { success -> Signal<Bool, NoError> in
            guard success, marker.maxReadIndex.id.id <= storyId.id else {
                return .single(success)
            }
            return account.postbox.transaction { transaction -> Bool in
                transaction.removeGhostModeReadState(
                    peerId: marker.peerId,
                    threadId: nil,
                    namespace: ghostModeStoryNamespace
                )
                updateGhostModeReadStateVersion(transaction: transaction)
                return true
            }
        }
    }
}

func _internal_discardGhostModeReadStates(postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        let _ = transaction.removeAllGhostModeReadStates()
        updateGhostModeReadStateVersion(transaction: transaction)
    }
    |> ignoreValues
}

func _internal_prepareGhostModeInteraction(account: Account, peerId: PeerId, threadId: Int64?) {
    let _ = (account.postbox.transaction { transaction -> Bool in
        let settings = ghostModeSettings(transaction: transaction)
        return settings.isEnabled && settings.revealOnInteractions
    }
    |> deliverOnMainQueue).startStandalone(next: { shouldReveal in
        guard shouldReveal else {
            return
        }
        account.temporarilyRevealGhostModePresence()
        let _ = _internal_commitGhostModeReadState(account: account, peerId: peerId, threadId: threadId).startStandalone()
    })
}
