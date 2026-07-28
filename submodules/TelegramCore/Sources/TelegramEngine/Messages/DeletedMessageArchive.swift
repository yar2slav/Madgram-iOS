import Foundation
import Postbox
import SwiftSignalKit

private let deletedMessageArchiveSessionId = Int64.random(in: Int64.min ... Int64.max)

private struct DeletedMessageArchiveKeptResourceKey: Hashable {
    let mediaBoxPath: String
    let resourceId: MediaResourceId
}

private let deletedMessageArchiveMediaKeepDisposables = Atomic<[DeletedMessageArchiveKeptResourceKey: Disposable]>(value: [:])
private let deletedMessageArchiveSessionInitialized = Atomic<Bool>(value: false)

private func archiveTimestamp() -> Int32 {
    return Int32(Date().timeIntervalSince1970)
}

private func removeDeletedMessageArchiveMetadata(transaction: Transaction, ids: [MessageId]) {
    for id in ids {
        transaction.updateMessage(id, update: { currentMessage in
            let attributes = attributesWithoutArchiveMetadata(currentMessage.attributes)
            if attributes.count == currentMessage.attributes.count {
                return .skip
            }
            return .update(StoreMessage(
                id: currentMessage.id,
                customStableId: nil,
                globallyUniqueId: currentMessage.globallyUniqueId,
                groupingKey: currentMessage.groupingKey,
                threadId: currentMessage.threadId,
                timestamp: currentMessage.timestamp,
                flags: StoreMessageFlags(currentMessage.flags),
                tags: currentMessage.tags,
                globalTags: currentMessage.globalTags,
                localTags: currentMessage.localTags,
                forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init),
                authorId: currentMessage.author?.id,
                text: currentMessage.text,
                attributes: attributes,
                media: currentMessage.media
            ))
        })
    }
}

private func prepareDeletedMessageArchive(transaction: Transaction, mediaBox: MediaBox? = nil) -> DeletedMessageArchiveSettings? {
    guard deletedMessageArchiveSessionInitialized.with({ $0 }) else {
        return nil
    }
    var settings = deletedMessageArchiveSettings(transaction: transaction)
    if settings.sessionId != deletedMessageArchiveSessionId {
        if settings.sessionId != 0 && !settings.keepAcrossLaunches {
            let index = transaction.getPreferencesEntry(key: PreferencesKeys.deletedMessageArchiveIndex)?.get(DeletedMessageArchiveIndex.self) ?? .empty
            var resourceIds = Set<MediaResourceId>()
            for entry in index.messageIds {
                if let message = transaction.getMessage(entry.messageId) {
                    resourceIds.formUnion(archivedResourceIds(message))
                }
            }
            if let mediaBox, !resourceIds.isEmpty {
                let _ = mediaBox.removeCachedResources(Array(resourceIds), force: true).start()
            }
            transaction.deleteMessages(index.messageIds.map(\.messageId), forEachMedia: nil)
            removeDeletedMessageArchiveMetadata(transaction: transaction, ids: index.liveMessageIds.map(\.messageId))
            updateDeletedMessageArchiveIndex(transaction: transaction, { _ in .empty })
        }
        settings.sessionId = deletedMessageArchiveSessionId
        transaction.updatePreferencesEntry(key: PreferencesKeys.deletedMessageArchiveSettings, { _ in
            return PreferencesEntry(settings)
        })
    }
    return settings
}

private func archivedResourceIds(_ message: Message) -> [MediaResourceId] {
    var result: [MediaResourceId] = []

    func append(_ media: Media) {
        addMessageMediaResourceIdsToRemove(media: media, resourceIds: &result)
        if let paidContent = media as? TelegramMediaPaidContent {
            for extendedMedia in paidContent.extendedMedia {
                if case let .full(nestedMedia) = extendedMedia {
                    append(nestedMedia)
                }
            }
        } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
            if let image = content.image {
                append(image)
            }
            if let file = content.file {
                append(file)
            }
            if let instantPage = content.instantPage?._parse() {
                for nestedMedia in instantPage.media.values {
                    append(nestedMedia)
                }
            }
        }
    }

    for media in message.effectiveMedia {
        append(media)
    }
    return result
}

private func messageIsDisappearing(_ message: Message) -> Bool {
    for attribute in message.attributes {
        if attribute is AutoremoveTimeoutMessageAttribute
            || attribute is AutoclearTimeoutMessageAttribute
            || attribute is ConsumableContentMessageAttribute
            || attribute is EphemeralMessageAttribute
            || attribute is EphemeralOutgoingMessageAttribute {
            return true
        }
    }
    return false
}

public func deletedMessageArchiveRetentionPlan<ID: Hashable>(
    items: [(id: ID, size: Int64, isDisappearing: Bool)],
    limitBytes: Int64,
    disappearingLimitBytes: Int64
) -> (retained: [ID], removed: [ID]) {
    var removed = Set<ID>()

    func trim(candidates: [Int], budget: Int64) {
        let remaining = candidates.filter { !removed.contains(items[$0].id) }
        var total: Int64 = remaining.reduce(0) { $0 + items[$1].size }
        guard total > budget else {
            return
        }
        let ordered = remaining.sorted { lhs, rhs in
            if items[lhs].size != items[rhs].size {
                return items[lhs].size > items[rhs].size
            }
            return lhs < rhs
        }
        for index in ordered {
            if total <= budget {
                break
            }
            total -= items[index].size
            removed.insert(items[index].id)
        }
    }

    trim(candidates: items.indices.filter { items[$0].isDisappearing }, budget: disappearingLimitBytes)
    trim(candidates: Array(items.indices), budget: limitBytes)

    var retained: [ID] = []
    var removedIds: [ID] = []
    for item in items {
        if removed.contains(item.id) {
            removedIds.append(item.id)
        } else {
            retained.append(item.id)
        }
    }
    return (retained: retained, removed: removedIds)
}

private func updateDeletedMessageArchiveMediaRetention(transaction: Transaction, mediaBox: MediaBox) {
    let settings = deletedMessageArchiveSettings(transaction: transaction)
    let index = transaction.getPreferencesEntry(key: PreferencesKeys.deletedMessageArchiveIndex)?.get(DeletedMessageArchiveIndex.self) ?? .empty

    var orderedResourceIds: [MediaResourceId] = []
    var disappearingResourceIds = Set<MediaResourceId>()
    var seenResourceIds = Set<MediaResourceId>()
    for entry in index.messageIds.reversed() {
        guard let message = transaction.getMessage(entry.messageId) else {
            continue
        }
        let isDisappearing = messageIsDisappearing(message)
        for id in archivedResourceIds(message).reversed() {
            if seenResourceIds.insert(id).inserted {
                orderedResourceIds.append(id)
                if isDisappearing {
                    disappearingResourceIds.insert(id)
                }
            }
        }
    }
    orderedResourceIds.reverse()

    var completedResources: [(id: MediaResourceId, size: Int64, isDisappearing: Bool)] = []
    for id in orderedResourceIds {
        if let path = mediaBox.completedResourcePath(id: id), let size = fileSize(path) {
            completedResources.append((id: id, size: size, isDisappearing: disappearingResourceIds.contains(id)))
        }
    }

    let gigabyte: Int64 = 1024 * 1024 * 1024
    let plan = deletedMessageArchiveRetentionPlan(
        items: completedResources,
        limitBytes: Int64(settings.mediaLimitGigabytes) * gigabyte,
        disappearingLimitBytes: Int64(settings.disappearingMediaLimitGigabytes) * gigabyte
    )
    let idsToRemove = plan.removed
    let retainedIds = plan.retained

    if !idsToRemove.isEmpty {
        let _ = mediaBox.removeCachedResources(idsToRemove, force: true).start()
    }
    var updatedKeepDisposables: [DeletedMessageArchiveKeptResourceKey: Disposable] = [:]
    for id in retainedIds {
        updatedKeepDisposables[DeletedMessageArchiveKeptResourceKey(mediaBoxPath: mediaBox.basePath, resourceId: id)] = mediaBox.keepResource(id: id).start()
    }
    var removedKeepDisposables: [Disposable] = []
    let _ = deletedMessageArchiveMediaKeepDisposables.modify { current in
        var current = current
        let removedKeys = current.keys.filter { $0.mediaBoxPath == mediaBox.basePath }
        for key in removedKeys {
            if let disposable = current.removeValue(forKey: key) {
                removedKeepDisposables.append(disposable)
            }
        }
        for (key, disposable) in updatedKeepDisposables {
            current[key] = disposable
        }
        return current
    }
    for disposable in removedKeepDisposables {
        disposable.dispose()
    }
}

private func archiveAttribute(_ attributes: [MessageAttribute]) -> ArchivedMessageAttribute? {
    return attributes.first(where: { $0 is ArchivedMessageAttribute }) as? ArchivedMessageAttribute
}

private func attributesWithoutArchiveMetadata(_ attributes: [MessageAttribute]) -> [MessageAttribute] {
    return attributes.filter {
        !($0 is ArchivedMessageAttribute) && !($0 is ArchivedMessageVersionAttribute)
    }
}

private func isVolatileEditedMessageAttribute(_ attribute: MessageAttribute) -> Bool {
    return attribute is ArchivedMessageAttribute
        || attribute is ArchivedMessageVersionAttribute
        || attribute is EditedMessageAttribute
        || attribute is ReactionsMessageAttribute
        || attribute is PendingReactionsMessageAttribute
        || attribute is PendingStarsReactionsMessageAttribute
        || attribute is ViewCountMessageAttribute
        || attribute is ForwardCountMessageAttribute
        || attribute is NotificationInfoMessageAttribute
        || attribute is ChannelMessageStateVersionAttribute
        || attribute is PeerGroupMessageStateVersionAttribute
        || attribute is TranslationMessageAttribute
}

private func encodedContentAttributes(_ attributes: [MessageAttribute]) -> [Data] {
    return attributes.compactMap { attribute -> Data? in
        if isVolatileEditedMessageAttribute(attribute) {
            return nil
        }
        let encoder = PostboxEncoder()
        encoder.encodeRootObject(attribute)
        var data = Data(String(describing: type(of: attribute)).utf8)
        data.append(encoder.makeData())
        return data
    }
}

private func mediaArraysAreEqual(_ lhs: [Media], _ rhs: [Media]) -> Bool {
    if lhs.count != rhs.count {
        return false
    }
    for i in 0 ..< lhs.count {
        if !lhs[i].isEqual(to: rhs[i]) {
            return false
        }
    }
    return true
}

public func deletedMessageArchiveContentsAreEqual(
    lhsText: String,
    lhsAttributes: [MessageAttribute],
    lhsMedia: [Media],
    rhsText: String,
    rhsAttributes: [MessageAttribute],
    rhsMedia: [Media]
) -> Bool {
    if lhsText != rhsText {
        return false
    }
    if !mediaArraysAreEqual(lhsMedia, rhsMedia) {
        return false
    }
    return encodedContentAttributes(lhsAttributes) == encodedContentAttributes(rhsAttributes)
}

private func archivedContentIsEqual(_ previous: Message, _ updated: StoreMessage) -> Bool {
    return deletedMessageArchiveContentsAreEqual(
        lhsText: previous.text,
        lhsAttributes: previous.attributes,
        lhsMedia: previous.media,
        rhsText: updated.text,
        rhsAttributes: updated.attributes,
        rhsMedia: updated.media
    )
}

private func isArchiveIneligible(_ message: Message) -> Bool {
    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
        return true
    }
    if message.id.namespace != Namespaces.Message.Cloud {
        return true
    }
    return message.media.contains(where: { $0 is TelegramMediaExpiredContent })
}

private func attributesWithoutExpiry(_ attributes: [MessageAttribute]) -> [MessageAttribute] {
    return attributes.filter { attribute in
        if attribute is AutoremoveTimeoutMessageAttribute
            || attribute is AutoclearTimeoutMessageAttribute
            || attribute is ConsumableContentMessageAttribute
            || attribute is ConsumablePersonalMentionMessageAttribute {
            return false
        }
        return true
    }
}

private func makeStoredCopy(
    of message: Message,
    namespace: MessageId.Namespace,
    attributes: [MessageAttribute],
    globallyUniqueId: Int64,
    keepGlobalTags: Bool
) -> StoreMessage {
    let attributes = attributesWithoutExpiry(attributes)
    var flags = StoreMessageFlags(message.flags)
    flags.remove(.Unsent)
    flags.remove(.Failed)
    flags.remove(.Sending)
    flags.remove(.CountedAsIncoming)

    var tags = message.tags
    tags.remove(.unseenPersonalMessage)
    tags.remove(.unseenReaction)
    tags.remove(.unseenPollVote)
    tags.remove(.pinned)

    return StoreMessage(
        peerId: message.id.peerId,
        namespace: namespace,
        customStableId: nil,
        globallyUniqueId: globallyUniqueId,
        groupingKey: message.groupingKey,
        threadId: message.threadId,
        timestamp: message.timestamp,
        flags: flags,
        tags: tags,
        globalTags: keepGlobalTags ? message.globalTags : [],
        localTags: [],
        forwardInfo: message.forwardInfo.flatMap(StoreMessageForwardInfo.init),
        authorId: message.author?.id,
        text: message.text,
        attributes: attributes,
        media: message.media
    )
}

private func addStoredCopy(
    transaction: Transaction,
    message: Message,
    namespace: MessageId.Namespace,
    attributes: [MessageAttribute],
    keepGlobalTags: Bool = false
) -> MessageId? {
    let globallyUniqueId = Int64.random(in: Int64.min ... Int64.max)
    let copy = makeStoredCopy(
        of: message,
        namespace: namespace,
        attributes: attributes,
        globallyUniqueId: globallyUniqueId,
        keepGlobalTags: keepGlobalTags
    )
    return transaction.addMessages([copy], location: .Random)[globallyUniqueId]
}

func archivePreviousMessageVersionIfNeeded(
    transaction: Transaction,
    id: MessageId,
    updatedMessage: StoreMessage,
    mediaBox: MediaBox? = nil
) -> StoreMessage {
    guard let settings = prepareDeletedMessageArchive(transaction: transaction, mediaBox: mediaBox), settings.saveEditedVersions else {
        return updatedMessage
    }
    guard let previous = transaction.getMessage(id), !isArchiveIneligible(previous) else {
        return updatedMessage
    }

    let previousArchiveAttribute = archiveAttribute(previous.attributes)
    if archivedContentIsEqual(previous, updatedMessage) {
        guard let previousArchiveAttribute else {
            return updatedMessage
        }
        var attributes = attributesWithoutArchiveMetadata(updatedMessage.attributes)
        attributes.append(previousArchiveAttribute)
        return updatedMessage.withUpdatedAttributes(attributes)
    }

    let capturedAt = updatedMessage.attributes.compactMap { ($0 as? EditedMessageAttribute)?.date }.first ?? archiveTimestamp()
    var snapshotAttributes = attributesWithoutArchiveMetadata(previous.attributes)
    snapshotAttributes.append(ArchivedMessageVersionAttribute(capturedAt: capturedAt))
    guard let snapshotId = addStoredCopy(
        transaction: transaction,
        message: previous,
        namespace: Namespaces.Message.ArchivedVersion,
        attributes: snapshotAttributes
    ) else {
        return updatedMessage
    }
    updateDeletedMessageArchiveIndex(transaction: transaction, { current in
        var current = current
        current.messageIds.append(DeletedMessageArchiveIndexEntry(snapshotId))
        let liveEntry = DeletedMessageArchiveIndexEntry(id)
        if !current.liveMessageIds.contains(liveEntry) {
            current.liveMessageIds.append(liveEntry)
        }
        return current
    })
    if let mediaBox {
        updateDeletedMessageArchiveMediaRetention(transaction: transaction, mediaBox: mediaBox)
    }

    var versionIds = previousArchiveAttribute?.versionIds ?? []
    if versionIds.last != snapshotId {
        versionIds.append(snapshotId)
    }
    let updatedArchiveAttribute = ArchivedMessageAttribute(
        originalMessageId: previousArchiveAttribute?.originalMessageId ?? previous.id,
        versionIds: versionIds,
        deletedAt: nil,
        sessionId: previousArchiveAttribute?.sessionId ?? deletedMessageArchiveSessionId
    )
    var attributes = attributesWithoutArchiveMetadata(updatedMessage.attributes)
    attributes.append(updatedArchiveAttribute)
    return updatedMessage.withUpdatedAttributes(attributes)
}

@discardableResult
func archiveMessagesBeforeCloudDeletion(
    transaction: Transaction,
    ids: [MessageId],
    deletedAt: Int32 = archiveTimestamp(),
    mediaBox: MediaBox? = nil
) -> [MessageId] {
    guard let settings = prepareDeletedMessageArchive(transaction: transaction, mediaBox: mediaBox) else {
        return []
    }
    if !settings.saveDeletedMessages {
        if let mediaBox {
            removeDeletedMessageArchiveForLocalDeletion(transaction: transaction, mediaBox: mediaBox, ids: ids)
        } else {
            var versionIds: [MessageId] = []
            var liveEntries = Set<DeletedMessageArchiveIndexEntry>()
            for id in ids {
                if let attribute = transaction.getMessage(id)?.archivedMessageAttribute {
                    versionIds.append(contentsOf: attribute.versionIds)
                    liveEntries.insert(DeletedMessageArchiveIndexEntry(id))
                }
            }
            if !versionIds.isEmpty {
                transaction.deleteMessages(versionIds, forEachMedia: nil)
                let versionEntries = Set(versionIds.map(DeletedMessageArchiveIndexEntry.init))
                updateDeletedMessageArchiveIndex(transaction: transaction, { current in
                    var current = current
                    current.messageIds.removeAll(where: { versionEntries.contains($0) })
                    current.liveMessageIds.removeAll(where: { liveEntries.contains($0) })
                    return current
                })
            }
        }
        return []
    }
    var result: [MessageId] = []
    for id in ids {
        guard let message = transaction.getMessage(id), !isArchiveIneligible(message) else {
            continue
        }
        let previousArchiveAttribute = archiveAttribute(message.attributes)
        var attributes = attributesWithoutArchiveMetadata(message.attributes)
        attributes.append(ArchivedMessageAttribute(
            originalMessageId: previousArchiveAttribute?.originalMessageId ?? message.id,
            versionIds: previousArchiveAttribute?.versionIds ?? [],
            deletedAt: deletedAt,
            sessionId: previousArchiveAttribute?.sessionId ?? deletedMessageArchiveSessionId
        ))
        if let archivedId = addStoredCopy(
            transaction: transaction,
            message: message,
            namespace: Namespaces.Message.Archived,
            attributes: attributes
        ) {
            result.append(archivedId)
        }
    }
    if !result.isEmpty {
        updateDeletedMessageArchiveIndex(transaction: transaction, { current in
            var current = current
            current.messageIds.append(contentsOf: result.map(DeletedMessageArchiveIndexEntry.init))
            let deletedEntries = Set(ids.map(DeletedMessageArchiveIndexEntry.init))
            current.liveMessageIds.removeAll(where: { deletedEntries.contains($0) })
            return current
        })
        if let mediaBox {
            updateDeletedMessageArchiveMediaRetention(transaction: transaction, mediaBox: mediaBox)
        }
    }
    return result
}

func _internal_deleteArchivedMessage(transaction: Transaction, mediaBox: MediaBox, id: MessageId) {
    guard id.namespace == Namespaces.Message.Archived, let message = transaction.getMessage(id) else {
        return
    }
    let versionIds = message.archivedMessageAttribute?.versionIds ?? []
    transaction.deleteMessages(versionIds + [id], forEachMedia: nil)
    let removedIds = Set((versionIds + [id]).map(DeletedMessageArchiveIndexEntry.init))
    updateDeletedMessageArchiveIndex(transaction: transaction, { current in
        var current = current
        current.messageIds.removeAll(where: { removedIds.contains($0) })
        return current
    })
    updateDeletedMessageArchiveMediaRetention(transaction: transaction, mediaBox: mediaBox)
}

func removeDeletedMessageArchiveForLocalDeletion(transaction: Transaction, mediaBox: MediaBox, ids: [MessageId]) {
    var versionIds: [MessageId] = []
    var archivedSourceIds: [MessageId] = []
    var resourceIds = Set<MediaResourceId>()
    for id in ids {
        guard let message = transaction.getMessage(id), let attribute = message.archivedMessageAttribute else {
            continue
        }
        archivedSourceIds.append(id)
        versionIds.append(contentsOf: attribute.versionIds)
        resourceIds.formUnion(archivedResourceIds(message))
        for versionId in attribute.versionIds {
            if let version = transaction.getMessage(versionId) {
                resourceIds.formUnion(archivedResourceIds(version))
            }
        }
    }
    guard !archivedSourceIds.isEmpty else {
        return
    }
    if !versionIds.isEmpty {
        transaction.deleteMessages(versionIds, forEachMedia: nil)
    }
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Array(resourceIds), force: true).start()
    }
    let removedStoredEntries = Set(versionIds.map(DeletedMessageArchiveIndexEntry.init))
    let removedLiveEntries = Set(archivedSourceIds.map(DeletedMessageArchiveIndexEntry.init))
    updateDeletedMessageArchiveIndex(transaction: transaction, { current in
        var current = current
        current.messageIds.removeAll(where: { removedStoredEntries.contains($0) })
        current.liveMessageIds.removeAll(where: { removedLiveEntries.contains($0) })
        return current
    })
    updateDeletedMessageArchiveMediaRetention(transaction: transaction, mediaBox: mediaBox)
}

func _internal_archivedMessageVersions(transaction: Transaction, id: MessageId) -> [Message] {
    guard let message = transaction.getMessage(id), let attribute = message.archivedMessageAttribute else {
        return []
    }
    var result = attribute.versionIds.compactMap(transaction.getMessage)
    result.append(message)
    return result
}

func _internal_clearDeletedMessageArchive(transaction: Transaction) {
    let index = transaction.getPreferencesEntry(key: PreferencesKeys.deletedMessageArchiveIndex)?.get(DeletedMessageArchiveIndex.self) ?? .empty
    transaction.deleteMessages(index.messageIds.map(\.messageId), forEachMedia: nil)
    removeDeletedMessageArchiveMetadata(transaction: transaction, ids: index.liveMessageIds.map(\.messageId))
    updateDeletedMessageArchiveIndex(transaction: transaction, { _ in .empty })
}

func _internal_clearDeletedMessageArchiveMedia(transaction: Transaction, mediaBox: MediaBox) {
    let index = transaction.getPreferencesEntry(key: PreferencesKeys.deletedMessageArchiveIndex)?.get(DeletedMessageArchiveIndex.self) ?? .empty
    var resourceIds = Set<MediaResourceId>()
    for entry in index.messageIds {
        if let message = transaction.getMessage(entry.messageId) {
            resourceIds.formUnion(archivedResourceIds(message))
        }
    }
    var removedKeepDisposables: [Disposable] = []
    let _ = deletedMessageArchiveMediaKeepDisposables.modify { current in
        var current = current
        let removedKeys = current.keys.filter { $0.mediaBoxPath == mediaBox.basePath }
        for key in removedKeys {
            if let disposable = current.removeValue(forKey: key) {
                removedKeepDisposables.append(disposable)
            }
        }
        return current
    }
    for disposable in removedKeepDisposables {
        disposable.dispose()
    }
    if !resourceIds.isEmpty {
        let _ = mediaBox.removeCachedResources(Array(resourceIds), force: true).start()
    }
}

public struct DeletedMessageArchiveStats: Equatable {
    public let messageCount: Int
    public let versionCount: Int
    public let mediaSize: Int64
}

func _internal_deletedMessageArchiveStats(transaction: Transaction, mediaBox: MediaBox) -> DeletedMessageArchiveStats {
    let index = transaction.getPreferencesEntry(key: PreferencesKeys.deletedMessageArchiveIndex)?.get(DeletedMessageArchiveIndex.self) ?? .empty
    var messageCount = 0
    var versionCount = 0
    var resourceIds = Set<MediaResourceId>()
    for entry in index.messageIds {
        guard let message = transaction.getMessage(entry.messageId) else {
            continue
        }
        if message.id.namespace == Namespaces.Message.Archived {
            messageCount += 1
        } else if message.id.namespace == Namespaces.Message.ArchivedVersion {
            versionCount += 1
        }
        resourceIds.formUnion(archivedResourceIds(message))
    }
    var mediaSize: Int64 = 0
    for id in resourceIds {
        if let path = mediaBox.completedResourcePath(id: id) {
            mediaSize += fileSize(path) ?? 0
        }
    }
    return DeletedMessageArchiveStats(messageCount: messageCount, versionCount: versionCount, mediaSize: mediaSize)
}

func _internal_refreshDeletedMessageArchiveMediaLimit(transaction: Transaction, mediaBox: MediaBox) {
    updateDeletedMessageArchiveMediaRetention(transaction: transaction, mediaBox: mediaBox)
}

func initializeDeletedMessageArchiveSession(postbox: Postbox) -> Signal<Never, NoError> {
    let _ = deletedMessageArchiveSessionInitialized.swap(true)
    return postbox.transaction { transaction -> Void in
        _ = prepareDeletedMessageArchive(transaction: transaction, mediaBox: postbox.mediaBox)
        updateDeletedMessageArchiveMediaRetention(transaction: transaction, mediaBox: postbox.mediaBox)
    }
    |> ignoreValues
}
