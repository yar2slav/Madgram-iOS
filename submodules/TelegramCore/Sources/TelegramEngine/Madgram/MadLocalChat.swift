import Foundation
import Postbox
import SwiftSignalKit

public enum MadLocalChat {
    public static let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(281474976710000))
    static let avatarFileId: Int64 = 281474976710001
}

public extension EnginePeer.Id {
    var isMadLocalChat: Bool {
        return self == MadLocalChat.peerId
    }
}

func _internal_madLocalChatPrepare(transaction: Transaction, mediaBox: MediaBox, name: String, avatarJpeg: Data?, avatarSide: Int32) {
    var photo: [TelegramMediaImageRepresentation] = []
    if let avatarJpeg {
        let resource = LocalFileMediaResource(fileId: MadLocalChat.avatarFileId)
        mediaBox.storeResourceData(resource.id, data: avatarJpeg, synchronous: true)
        photo.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: avatarSide, height: avatarSide), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
    }
    let user = TelegramUser(id: MadLocalChat.peerId, accessHash: nil, firstName: name, lastName: nil, username: nil, phone: nil, photo: photo, botInfo: nil, restrictionInfo: nil, flags: [.isVerified], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
    updatePeersCustom(transaction: transaction, peers: [user], update: { _, updated in updated })
    transaction.updatePeerCachedData(peerIds: Set([MadLocalChat.peerId]), update: { _, current in
        let cachedData = (current as? CachedUserData) ?? CachedUserData()
        if case .known = cachedData.businessIntro {
            return cachedData
        }
        return cachedData.withUpdatedBusinessIntro(nil)
    })
    _internal_madLocalChatSettle(transaction: transaction)
}

func _internal_madLocalChatSettle(transaction: Transaction) {
    let peerId = MadLocalChat.peerId
    transaction.removeHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
}

func _internal_madLocalChatPost(transaction: Transaction, mediaBox: MediaBox, richTexts: [RichTextMessageAttribute], replacing: Bool) -> [EngineMessage.Id] {
    let peerId = MadLocalChat.peerId
    guard transaction.getPeer(peerId) != nil, !richTexts.isEmpty else {
        return []
    }
    if replacing {
        _internal_clearHistory(transaction: transaction, mediaBox: mediaBox, peerId: peerId, threadId: nil, namespaces: .all)
    }
    let timestamp = Int32(Date().timeIntervalSince1970)
    var uniqueIds: [Int64] = []
    var messages: [StoreMessage] = []
    for richText in richTexts {
        let globallyUniqueId = Int64.random(in: 1 ..< Int64.max)
        uniqueIds.append(globallyUniqueId)
        messages.append(StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, customStableId: nil, globallyUniqueId: globallyUniqueId, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: peerId, text: "", attributes: [richText], media: []))
    }
    let ids = transaction.addMessages(messages, location: .UpperHistoryBlock)
    _internal_madLocalChatSettle(transaction: transaction)
    transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
    return uniqueIds.compactMap { ids[$0] }
}

public extension TelegramEngine.Messages {
    func madLocalChatPrepare(name: String, avatarJpeg: Data?, avatarSide: Int32) -> Signal<Never, NoError> {
        let account = self.account
        return account.postbox.transaction { transaction -> Void in
            _internal_madLocalChatPrepare(transaction: transaction, mediaBox: account.postbox.mediaBox, name: name, avatarJpeg: avatarJpeg, avatarSide: avatarSide)
        }
        |> ignoreValues
    }

    func madLocalChatPost(richTexts: [RichTextMessageAttribute], replacing: Bool) -> Signal<[EngineMessage.Id], NoError> {
        let account = self.account
        return account.postbox.transaction { transaction -> [EngineMessage.Id] in
            return _internal_madLocalChatPost(transaction: transaction, mediaBox: account.postbox.mediaBox, richTexts: richTexts, replacing: replacing)
        }
    }

    func madLocalChatUpdate(messageIds: [EngineMessage.Id], richTexts: [RichTextMessageAttribute]) -> Signal<Bool, NoError> {
        return self.account.postbox.transaction { transaction -> Bool in
            guard messageIds.count == richTexts.count, messageIds.allSatisfy({ $0.peerId == MadLocalChat.peerId && transaction.getMessage($0) != nil }) else {
                return false
            }
            for (messageId, richText) in zip(messageIds, richTexts) {
                transaction.updateMessage(messageId, update: { current in
                    if let existing = current.attributes.first(where: { $0 is RichTextMessageAttribute }) as? RichTextMessageAttribute, existing == richText {
                        return .skip
                    }
                    var attributes = current.attributes.filter { !($0 is RichTextMessageAttribute) }
                    attributes.append(richText)
                    return .update(StoreMessage(updating: current, attributes: attributes, tags: current.tags))
                })
            }
            return true
        }
    }
}
