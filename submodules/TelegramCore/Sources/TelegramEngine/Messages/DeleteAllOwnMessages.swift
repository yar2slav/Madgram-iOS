import Foundation
import Postbox
import SwiftSignalKit

public struct DeleteAllOwnMessagesProgress: Equatable {
    public let deletedCount: Int
    public let totalCount: Int

    public init(deletedCount: Int, totalCount: Int) {
        self.deletedCount = deletedCount
        self.totalCount = totalCount
    }
}

/// Deletes every cloud message authored by the account in the given peer, for all participants.
///
/// Enumerates the account's messages via server-side search (pages are anchored to offset ids, so
/// pagination stays stable while earlier pages are being deleted) and deletes each page through the
/// interactive-deletion pipeline: messages disappear locally right away, server deletion goes through
/// the resilient cloud-operation queue. Emits cumulative progress after each page.
func _internal_deleteAllOwnMessages(account: Account, peerId: PeerId) -> Signal<DeleteAllOwnMessagesProgress, NoError> {
    let location: SearchMessagesLocation = .peer(peerId: peerId, fromId: account.peerId, tags: nil, reactions: nil, threadId: nil, minDate: nil, maxDate: nil)

    func markInteractivelyDeleted(_ ids: [MessageId]) {
        account.stateManager.messagesRemovedContext.addIsMessagesDeletedInteractively(ids: ids.map { id -> DeletedMessageId in
            if id.namespace == Namespaces.Message.Cloud && (id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup) {
                return .global(id.id)
            } else {
                return .messageId(id)
            }
        })
    }

    func processSearchPage(state: SearchMessagesState?, deletedCount: Int, totalCount: Int?, remainingPages: Int) -> Signal<DeleteAllOwnMessagesProgress, NoError> {
        return _internal_searchMessages(account: account, location: location, query: "", state: state, centerId: nil, limit: 100)
        |> mapToSignal { result, updatedState -> Signal<DeleteAllOwnMessagesProgress, NoError> in
            let ids = result.messages.compactMap { message -> MessageId? in
                guard message.id.peerId == peerId, message.id.namespace == Namespaces.Message.Cloud else {
                    return nil
                }
                return message.id
            }
            if ids.isEmpty {
                return .single(DeleteAllOwnMessagesProgress(deletedCount: deletedCount, totalCount: deletedCount))
            }

            let totalCount = totalCount ?? max(deletedCount + Int(result.totalCount), deletedCount + ids.count)
            let updatedDeletedCount = deletedCount + ids.count
            let progress = DeleteAllOwnMessagesProgress(deletedCount: updatedDeletedCount, totalCount: max(totalCount, updatedDeletedCount))

            markInteractivelyDeleted(ids)

            var followUp: Signal<DeleteAllOwnMessagesProgress, NoError> = .single(progress)
            if !result.completed && remainingPages > 0 {
                followUp = followUp
                |> then(processSearchPage(state: updatedState, deletedCount: updatedDeletedCount, totalCount: progress.totalCount, remainingPages: remainingPages - 1))
            }

            return _internal_deleteMessagesInteractively(account: account, messageIds: ids, type: .forEveryone)
            |> mapToSignal { _ -> Signal<DeleteAllOwnMessagesProgress, NoError> in
                return .complete()
            }
            |> then(followUp)
        }
    }

    func collectRecentChannelPostIds() -> Signal<Set<MessageId>, NoError> {
        func collectPage(maxId: AdminLogEventId, collectedIds: Set<MessageId>, remainingPages: Int) -> Signal<Set<MessageId>, ChannelAdminLogEventError> {
            return channelAdminLogEvents(
                accountPeerId: account.peerId,
                postbox: account.postbox,
                network: account.network,
                peerId: peerId,
                maxId: maxId,
                minId: AdminLogEventId.min,
                limit: 100,
                filter: [.sendMessages],
                admins: [account.peerId]
            )
            |> mapToSignal { result -> Signal<Set<MessageId>, ChannelAdminLogEventError> in
                var updatedIds = collectedIds
                var nextMaxId = maxId
                for event in result.events {
                    nextMaxId = min(nextMaxId, event.id)
                    if case let .sendMessage(message) = event.action, message.id.peerId == peerId, message.id.namespace == Namespaces.Message.Cloud {
                        updatedIds.insert(message.id)
                    }
                }
                if result.events.isEmpty || remainingPages <= 1 || nextMaxId >= maxId {
                    return .single(updatedIds)
                }
                return collectPage(maxId: nextMaxId, collectedIds: updatedIds, remainingPages: remainingPages - 1)
            }
        }

        return collectPage(maxId: AdminLogEventId.max, collectedIds: Set(), remainingPages: 100)
        |> `catch` { _ -> Signal<Set<MessageId>, NoError> in
            return .single(Set())
        }
    }

    func deleteCollectedChannelPosts(ids: [MessageId]) -> Signal<DeleteAllOwnMessagesProgress, NoError> {
        var result: Signal<DeleteAllOwnMessagesProgress, NoError> = .complete()
        var offset = 0
        while offset < ids.count {
            let upperBound = min(offset + 100, ids.count)
            let pageIds = Array(ids[offset ..< upperBound])
            let deletedCount = upperBound
            result = result
            |> then(Signal { subscriber in
                markInteractivelyDeleted(pageIds)
                return _internal_deleteMessagesInteractively(account: account, messageIds: pageIds, type: .forEveryone).start(completed: {
                    subscriber.putNext(DeleteAllOwnMessagesProgress(deletedCount: deletedCount, totalCount: ids.count))
                    subscriber.putCompletion()
                })
            })
            offset = upperBound
        }
        return result
        |> then(processSearchPage(state: nil, deletedCount: ids.count, totalCount: nil, remainingPages: 10000))
    }

    return account.postbox.transaction { transaction -> Bool in
        guard let channel = transaction.getPeer(peerId) as? TelegramChannel, case .broadcast = channel.info else {
            return false
        }
        return true
    }
    |> mapToSignal { isBroadcastChannel -> Signal<DeleteAllOwnMessagesProgress, NoError> in
        if isBroadcastChannel {
            return collectRecentChannelPostIds()
            |> mapToSignal { ids -> Signal<DeleteAllOwnMessagesProgress, NoError> in
                let sortedIds = ids.sorted { lhs, rhs in
                    return lhs.id < rhs.id
                }
                return deleteCollectedChannelPosts(ids: sortedIds)
            }
        } else {
            return processSearchPage(state: nil, deletedCount: 0, totalCount: nil, remainingPages: 10000)
        }
    }
}
