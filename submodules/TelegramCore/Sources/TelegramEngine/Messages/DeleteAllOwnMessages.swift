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

    func processPage(state: SearchMessagesState?, deletedCount: Int, totalCount: Int?, remainingPages: Int) -> Signal<DeleteAllOwnMessagesProgress, NoError> {
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

            let totalCount = totalCount ?? max(Int(result.totalCount), ids.count)
            let updatedDeletedCount = deletedCount + ids.count
            let progress = DeleteAllOwnMessagesProgress(deletedCount: updatedDeletedCount, totalCount: max(totalCount, updatedDeletedCount))

            account.stateManager.messagesRemovedContext.addIsMessagesDeletedInteractively(ids: ids.map { id -> DeletedMessageId in
                if id.namespace == Namespaces.Message.Cloud && (id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup) {
                    return .global(id.id)
                } else {
                    return .messageId(id)
                }
            })

            var followUp: Signal<DeleteAllOwnMessagesProgress, NoError> = .single(progress)
            if !result.completed && remainingPages > 0 {
                followUp = followUp
                |> then(processPage(state: updatedState, deletedCount: updatedDeletedCount, totalCount: progress.totalCount, remainingPages: remainingPages - 1))
            }

            return _internal_deleteMessagesInteractively(account: account, messageIds: ids, type: .forEveryone)
            |> mapToSignal { _ -> Signal<DeleteAllOwnMessagesProgress, NoError> in
                return .complete()
            }
            |> then(followUp)
        }
    }

    return processPage(state: nil, deletedCount: 0, totalCount: nil, remainingPages: 10000)
}
