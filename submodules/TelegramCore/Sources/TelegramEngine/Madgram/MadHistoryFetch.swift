import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

func _internal_madFetchHistory(account: Account, peerId: PeerId, offsetId: Int32, offsetDate: Int32, addOffset: Int32, limit: Int32) -> Signal<[Message], NoError> {
    let accountPeerId = account.peerId
    let postbox = account.postbox
    let network = account.network
    return postbox.transaction { transaction -> (Api.InputPeer?, Bool) in
        let peer = transaction.getPeer(peerId)
        return (peer.flatMap(apiInputPeer), peer?.isForumOrMonoForum ?? false)
    }
    |> mapToSignal { inputPeer, peerIsForum -> Signal<[Message], NoError> in
        guard let inputPeer else {
            return .single([])
        }
        return network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: offsetId, offsetDate: offsetDate, addOffset: addOffset, limit: limit, maxId: 0, minId: 0, hash: 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<[Message], NoError> in
            guard let result else {
                return .single([])
            }
            let messages: [Api.Message]
            let chats: [Api.Chat]
            let users: [Api.User]
            switch result {
            case let .channelMessages(data):
                messages = data.messages
                chats = data.chats
                users = data.users
            case let .messages(data):
                messages = data.messages
                chats = data.chats
                users = data.users
            case let .messagesSlice(data):
                messages = data.messages
                chats = data.chats
                users = data.users
            case .messagesNotModified:
                messages = []
                chats = []
                users = []
            }
            return postbox.transaction { transaction -> [Message] in
                var peers: [PeerId: Peer] = [:]
                for user in users {
                    if let user = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                        peers[user.id] = user
                    }
                }
                for chat in chats {
                    if let groupOrChannel = mergeGroupOrChannel(lhs: transaction.getPeer(chat.peerId), rhs: chat) {
                        peers[groupOrChannel.id] = groupOrChannel
                    }
                }
                if peers[peerId] == nil, let peer = transaction.getPeer(peerId) {
                    peers[peerId] = peer
                }
                if peers[accountPeerId] == nil, let peer = transaction.getPeer(accountPeerId) {
                    peers[accountPeerId] = peer
                }
                var rendered: [Message] = []
                for message in messages {
                    if let storeMessage = StoreMessage(apiMessage: message, accountPeerId: accountPeerId, peerIsForum: peerIsForum), let renderedMessage = locallyRenderedMessage(message: storeMessage, peers: peers) {
                        rendered.append(renderedMessage)
                    }
                }
                return rendered.sorted(by: { $0.index < $1.index })
            }
        }
    }
}

public extension TelegramEngine.Messages {
    func madHistoryAround(peerId: EnginePeer.Id, messageId: Int32, before: Int32, after: Int32) -> Signal<[EngineMessage], NoError> {
        return _internal_madFetchHistory(account: self.account, peerId: peerId, offsetId: messageId + 1, offsetDate: 0, addOffset: -after, limit: before + after + 1)
        |> map { $0.map(EngineMessage.init) }
    }

    func madHistoryPage(peerId: EnginePeer.Id, beforeDate: Int32, limit: Int32) -> Signal<[EngineMessage], NoError> {
        return _internal_madFetchHistory(account: self.account, peerId: peerId, offsetId: 0, offsetDate: beforeDate, addOffset: 0, limit: limit)
        |> map { $0.map(EngineMessage.init) }
    }
}
