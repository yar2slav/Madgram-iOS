import Foundation
import Postbox
import SwiftSignalKit

public extension EnginePeer.Id {
    var isMadLocalPeer: Bool {
        let value = self.id._internalGetInt64Value()
        return value >= 281474976710000 && value < 281474976710200
    }
}

#if DEBUG
public enum MadDemo {
    public static let firstPeerValue: Int64 = 281474976710100

    public static func peerId(kind: PeerKind, index: Int) -> EnginePeer.Id {
        let namespace: PeerId.Namespace
        switch kind {
        case .user:
            namespace = Namespaces.Peer.CloudUser
        case .group, .channel:
            namespace = Namespaces.Peer.CloudChannel
        }
        return EnginePeer.Id(namespace: namespace, id: EnginePeer.Id.Id._internalFromInt64Value(self.firstPeerValue + Int64(index)))
    }

    public enum PeerKind: String {
        case user
        case group
        case channel
    }

    public struct Peer {
        public var index: Int
        public var kind: PeerKind
        public var firstName: String
        public var lastName: String?
        public var username: String?
        public var avatarJpeg: Data?
        public var online: Bool
        public var lastSeenMinutesAgo: Int?
        public var verified: Bool
        public var pinned: Bool
        public var unreadCount: Int32
        public var muted: Bool

        public init(index: Int, kind: PeerKind, firstName: String, lastName: String?, username: String?, avatarJpeg: Data?, online: Bool, lastSeenMinutesAgo: Int?, verified: Bool, pinned: Bool, unreadCount: Int32, muted: Bool) {
            self.index = index
            self.kind = kind
            self.firstName = firstName
            self.lastName = lastName
            self.username = username
            self.avatarJpeg = avatarJpeg
            self.online = online
            self.lastSeenMinutesAgo = lastSeenMinutesAgo
            self.verified = verified
            self.pinned = pinned
            self.unreadCount = unreadCount
            self.muted = muted
        }

        public var peerId: EnginePeer.Id {
            return MadDemo.peerId(kind: self.kind, index: self.index)
        }
    }

    public struct Message {
        public var chat: EnginePeer.Id
        public var author: EnginePeer.Id?
        public var outgoing: Bool
        public var text: String
        public var minutesAgo: Int
        public var deleted: Bool
        public var previousVersions: [String]
        public var views: Int?
        public var photoJpeg: Data?
        public var photoSize: CGSize?

        public init(chat: EnginePeer.Id, author: EnginePeer.Id?, outgoing: Bool, text: String, minutesAgo: Int, deleted: Bool, previousVersions: [String], views: Int?, photoJpeg: Data?, photoSize: CGSize?) {
            self.chat = chat
            self.author = author
            self.outgoing = outgoing
            self.text = text
            self.minutesAgo = minutesAgo
            self.deleted = deleted
            self.previousVersions = previousVersions
            self.views = views
            self.photoJpeg = photoJpeg
            self.photoSize = photoSize
        }
    }
}

private func madDemoAvatar(mediaBox: MediaBox, peerId: PeerId, jpeg: Data?) -> [TelegramMediaImageRepresentation] {
    guard let jpeg else {
        return []
    }
    let resource = LocalFileMediaResource(fileId: peerId.id._internalGetInt64Value())
    mediaBox.storeResourceData(resource.id, data: jpeg, synchronous: true)
    return [TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)]
}

func _internal_madDemoSeed(transaction: Transaction, mediaBox: MediaBox, accountPeerId: PeerId, me: MadDemo.Peer?, peers: [MadDemo.Peer], messages: [MadDemo.Message]) {
    let now = Int32(Date().timeIntervalSince1970)
    var storedPeers: [Peer] = []
    if let me {
        let photo = madDemoAvatar(mediaBox: mediaBox, peerId: accountPeerId, jpeg: me.avatarJpeg)
        let usernames = me.username.flatMap { [TelegramPeerUsername(flags: [.isActive, .isEditable], username: $0)] } ?? []
        storedPeers.append(TelegramUser(id: accountPeerId, accessHash: nil, firstName: me.firstName, lastName: me.lastName, username: me.username, phone: nil, photo: photo, botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: usernames, storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
    }
    var presences: [PeerId: PeerPresence] = [:]
    for peer in peers {
        let peerId = peer.peerId
        let photo = madDemoAvatar(mediaBox: mediaBox, peerId: peerId, jpeg: peer.avatarJpeg)
        let usernames = peer.username.flatMap { [TelegramPeerUsername(flags: [.isActive, .isEditable], username: $0)] } ?? []
        switch peer.kind {
        case .user:
            storedPeers.append(TelegramUser(id: peerId, accessHash: nil, firstName: peer.firstName, lastName: peer.lastName, username: peer.username, phone: nil, photo: photo, botInfo: nil, restrictionInfo: nil, flags: peer.verified ? [.isVerified] : [], emojiStatus: nil, usernames: usernames, storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
            if peer.online {
                presences[peerId] = TelegramUserPresence(status: .present(until: now + 7 * 24 * 60 * 60), lastActivity: now)
            } else if let minutes = peer.lastSeenMinutesAgo {
                presences[peerId] = TelegramUserPresence(status: .present(until: now - Int32(minutes * 60)), lastActivity: now - Int32(minutes * 60))
            } else {
                presences[peerId] = TelegramUserPresence(status: .recently(isHidden: false), lastActivity: 0)
            }
        case .group, .channel:
            let info: TelegramChannelInfo = peer.kind == .group ? .group(TelegramChannelGroupInfo(flags: [])) : .broadcast(TelegramChannelBroadcastInfo(flags: []))
            storedPeers.append(TelegramChannel(id: peerId, accessHash: nil, title: peer.firstName, username: peer.username, photo: photo, creationDate: now - 365 * 24 * 60 * 60, version: 0, participationStatus: .member, info: info, flags: peer.verified ? [.isVerified] : [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil, usernames: usernames, storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, emojiStatus: nil, approximateBoostLevel: nil, subscriptionUntilDate: nil, verificationIconFileId: nil, sendPaidMessageStars: nil, linkedMonoforumId: nil))
        }
    }
    updatePeersCustom(transaction: transaction, peers: storedPeers, update: { _, updated in updated })
    if !presences.isEmpty {
        transaction.updatePeerPresencesInternal(presences: presences, merge: { _, updated in updated })
    }

    for peer in peers where peer.kind == .user {
        transaction.updatePeerCachedData(peerIds: Set([peer.peerId]), update: { _, current in
            let cachedData = (current as? CachedUserData) ?? CachedUserData()
            if case .known = cachedData.businessIntro {
                return cachedData
            }
            return cachedData.withUpdatedBusinessIntro(nil)
        })
    }

    var nextId: [PeerId: Int32] = [:]
    var nextArchivedId: Int32 = 1
    var storeMessages: [StoreMessage] = []
    var maxIncoming: [PeerId: Int32] = [:]
    var maxOutgoing: [PeerId: Int32] = [:]
    for message in messages.sorted(by: { $0.minutesAgo > $1.minutesAgo }) {
        let chat = message.chat
        let timestamp = now - Int32(message.minutesAgo * 60)
        var flags: StoreMessageFlags = []
        if !message.outgoing {
            flags.insert(.Incoming)
        }
        let author: PeerId?
        if message.outgoing {
            author = accountPeerId
        } else if chat.namespace == Namespaces.Peer.CloudChannel {
            author = message.author
        } else {
            author = message.author ?? chat
        }
        var media: [Media] = []
        if let jpeg = message.photoJpeg {
            let resource = LocalFileMediaResource(fileId: Int64.random(in: 1 ..< Int64.max))
            mediaBox.storeResourceData(resource.id, data: jpeg, synchronous: true)
            let size = message.photoSize ?? CGSize(width: 1280, height: 960)
            media.append(TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: 1 ..< Int64.max)), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: Int32(size.width), height: Int32(size.height)), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: []))
        }
        var attributes: [MessageAttribute] = []
        if let views = message.views {
            attributes.append(ViewCountMessageAttribute(count: views))
        }
        if message.deleted {
            let id = MessageId(peerId: chat, namespace: Namespaces.Message.Archived, id: nextArchivedId)
            nextArchivedId += 1
            attributes.append(ArchivedMessageAttribute(originalMessageId: MessageId(peerId: chat, namespace: Namespaces.Message.Cloud, id: Int32.max - id.id), versionIds: [], deletedAt: timestamp + 60, sessionId: 0))
            storeMessages.append(StoreMessage(id: id, customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: flags, tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: author, text: message.text, attributes: attributes, media: media))
            continue
        }
        let id = (nextId[chat] ?? 1)
        nextId[chat] = id + 1
        let messageId = MessageId(peerId: chat, namespace: Namespaces.Message.Cloud, id: id)
        if !message.previousVersions.isEmpty {
            var versionIds: [MessageId] = []
            for (offset, text) in message.previousVersions.enumerated() {
                let versionId = MessageId(peerId: chat, namespace: Namespaces.Message.ArchivedVersion, id: nextArchivedId)
                nextArchivedId += 1
                versionIds.append(versionId)
                let capturedAt = timestamp + Int32(offset * 60)
                storeMessages.append(StoreMessage(id: versionId, customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: flags, tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: author, text: text, attributes: [ArchivedMessageVersionAttribute(capturedAt: capturedAt)], media: []))
            }
            attributes.append(EditedMessageAttribute(date: timestamp + Int32(message.previousVersions.count * 60), isHidden: false))
            attributes.append(ArchivedMessageAttribute(originalMessageId: messageId, versionIds: versionIds, deletedAt: nil, sessionId: 0))
        }
        if message.outgoing {
            maxOutgoing[chat] = id
        } else {
            maxIncoming[chat] = id
        }
        storeMessages.append(StoreMessage(id: messageId, customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: flags, tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: author, text: message.text, attributes: attributes, media: media))
    }
    let _ = transaction.addMessages(storeMessages, location: .UpperHistoryBlock)

    var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
    for peer in peers {
        let peerId = peer.peerId
        transaction.removeHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
        let maxKnown = (nextId[peerId] ?? 1) - 1
        let incoming = maxIncoming[peerId] ?? 0
        let unread = min(peer.unreadCount, Int32(maxKnown))
        readStates[peerId] = [Namespaces.Message.Cloud: .idBased(maxIncomingReadId: unread > 0 ? max(0, incoming - unread) : maxKnown, maxOutgoingReadId: maxKnown, maxKnownId: maxKnown, count: unread, markedUnread: false)]
        transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
        if peer.muted {
            transaction.updateCurrentPeerNotificationSettings([peerId: TelegramPeerNotificationSettings.defaultSettings.withUpdatedMuteState(.muted(until: Int32.max))])
        }
    }
    transaction.resetIncomingReadStates(readStates)

    for groupId in [PeerGroupId.root, Namespaces.PeerGroup.archive] {
        for hole in transaction.allChatListHoles(groupId: groupId) {
            transaction.replaceChatListHole(groupId: groupId, index: hole.index, hole: nil)
        }
    }

    var pinned: [PinnedItemId] = [.peer(MadLocalChat.peerId)]
    pinned.append(contentsOf: peers.filter(\.pinned).map { PinnedItemId.peer($0.peerId) })
    transaction.setPinnedItemIds(groupId: .root, itemIds: pinned)
}

func _internal_madDemoClear(transaction: Transaction, mediaBox: MediaBox, peerIds: [PeerId]) {
    for peerId in peerIds {
        _internal_clearHistory(transaction: transaction, mediaBox: mediaBox, peerId: peerId, threadId: nil, namespaces: .all)
        transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
    }
}

public extension TelegramEngine.Messages {
    func madDemoSeed(me: MadDemo.Peer?, peers: [MadDemo.Peer], messages: [MadDemo.Message]) -> Signal<Never, NoError> {
        let account = self.account
        return account.postbox.transaction { transaction -> Void in
            let peerIds = (0 ..< 100).flatMap { index in [MadDemo.peerId(kind: .user, index: index), MadDemo.peerId(kind: .channel, index: index)] }
            _internal_madDemoClear(transaction: transaction, mediaBox: account.postbox.mediaBox, peerIds: peerIds.filter { transaction.getPeer($0) != nil })
            _internal_madDemoSeed(transaction: transaction, mediaBox: account.postbox.mediaBox, accountPeerId: account.peerId, me: me, peers: peers, messages: messages)
        }
        |> ignoreValues
    }
}
#endif
