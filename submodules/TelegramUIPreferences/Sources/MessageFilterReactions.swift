import Foundation
import Postbox
import TelegramCore

public extension MessageFilterSettings {
    /// Removes hidden peers' contributions from a message's reactions attribute.
    ///
    /// Returns the original instance when nothing needs to change, a rewritten
    /// attribute when some contributions were removed, or nil when nothing is
    /// left to display. Attribution is best-effort: in large chats the server
    /// only sends a few recent reactors, so a hidden peer outside that list
    /// cannot be subtracted from the counts.
    func strippingHiddenReactions(from attribute: ReactionsMessageAttribute) -> ReactionsMessageAttribute? {
        if !self.isActive {
            return attribute
        }
        // Tag reactions are the account's own saved-message tags.
        if attribute.isTags {
            return attribute
        }

        var removedCounts: [MessageReaction.Reaction: Int32] = [:]

        var recentPeers: [ReactionsMessageAttribute.RecentPeer] = []
        recentPeers.reserveCapacity(attribute.recentPeers.count)
        for peer in attribute.recentPeers {
            if self.hidesMessages(fromAuthorId: peer.peerId.toInt64()) {
                removedCounts[peer.value, default: 0] += 1
            } else {
                recentPeers.append(peer)
            }
        }

        var topPeers: [ReactionsMessageAttribute.TopPeer] = []
        topPeers.reserveCapacity(attribute.topPeers.count)
        for peer in attribute.topPeers {
            if let peerId = peer.peerId, self.hidesMessages(fromAuthorId: peerId.toInt64()) {
                removedCounts[.stars, default: 0] += peer.count
            } else {
                topPeers.append(peer)
            }
        }

        if removedCounts.isEmpty {
            return attribute
        }

        var reactions: [MessageReaction] = []
        reactions.reserveCapacity(attribute.reactions.count)
        for reaction in attribute.reactions {
            let removed = removedCounts[reaction.value] ?? 0
            var count = reaction.count - removed
            if reaction.isSelected {
                // The account's own reaction always stays visible.
                count = max(count, 1)
            }
            if count > 0 {
                reactions.append(MessageReaction(value: reaction.value, count: count, chosenOrder: reaction.chosenOrder))
            }
        }

        if reactions.isEmpty && recentPeers.isEmpty && topPeers.isEmpty {
            return nil
        }

        return ReactionsMessageAttribute(
            canViewList: attribute.canViewList,
            isTags: attribute.isTags,
            reactions: reactions,
            recentPeers: recentPeers,
            topPeers: topPeers
        )
    }
}
