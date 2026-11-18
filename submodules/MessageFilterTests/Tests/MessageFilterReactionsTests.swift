import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences
import XCTest

private func userPeerId(_ id: Int64) -> PeerId {
    return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
}

private func recentPeer(_ value: MessageReaction.Reaction, _ peerId: PeerId, isMy: Bool = false) -> ReactionsMessageAttribute.RecentPeer {
    return ReactionsMessageAttribute.RecentPeer(value: value, isLarge: false, isUnseen: false, isMy: isMy, peerId: peerId, timestamp: nil)
}

final class MessageFilterReactionsTests: XCTestCase {
    private let hiddenPeer = userPeerId(42)
    private let visiblePeer = userPeerId(7)

    private var settings: MessageFilterSettings {
        return MessageFilterSettings(
            hideBlockedUsersMessages: false,
            shadowBannedPeerIds: [self.hiddenPeer.toInt64()],
            blockedPeerIdsCache: []
        )
    }

    func testInactiveSettingsReturnSameAttribute() {
        let attribute = ReactionsMessageAttribute(
            canViewList: true,
            isTags: false,
            reactions: [MessageReaction(value: .builtin("👍"), count: 1, chosenOrder: nil)],
            recentPeers: [recentPeer(.builtin("👍"), self.hiddenPeer)],
            topPeers: []
        )
        let result = MessageFilterSettings.defaultSettings.strippingHiddenReactions(from: attribute)
        XCTAssertTrue(result === attribute)
    }

    func testAttributeWithoutHiddenPeersIsUntouched() {
        let attribute = ReactionsMessageAttribute(
            canViewList: true,
            isTags: false,
            reactions: [MessageReaction(value: .builtin("👍"), count: 1, chosenOrder: nil)],
            recentPeers: [recentPeer(.builtin("👍"), self.visiblePeer)],
            topPeers: []
        )
        let result = self.settings.strippingHiddenReactions(from: attribute)
        XCTAssertTrue(result === attribute)
    }

    func testSoleHiddenReactionRemovesAttributeEntirely() {
        let attribute = ReactionsMessageAttribute(
            canViewList: true,
            isTags: false,
            reactions: [MessageReaction(value: .builtin("👍"), count: 1, chosenOrder: nil)],
            recentPeers: [recentPeer(.builtin("👍"), self.hiddenPeer)],
            topPeers: []
        )
        XCTAssertNil(self.settings.strippingHiddenReactions(from: attribute))
    }

    func testHiddenReactorIsSubtractedFromSharedReaction() {
        let attribute = ReactionsMessageAttribute(
            canViewList: true,
            isTags: false,
            reactions: [
                MessageReaction(value: .builtin("👍"), count: 2, chosenOrder: nil),
                MessageReaction(value: .builtin("🔥"), count: 1, chosenOrder: nil),
            ],
            recentPeers: [
                recentPeer(.builtin("👍"), self.hiddenPeer),
                recentPeer(.builtin("👍"), self.visiblePeer),
                recentPeer(.builtin("🔥"), self.visiblePeer),
            ],
            topPeers: []
        )
        guard let result = self.settings.strippingHiddenReactions(from: attribute) else {
            XCTFail("attribute should survive")
            return
        }
        XCTAssertFalse(result === attribute)
        XCTAssertEqual(result.reactions, [
            MessageReaction(value: .builtin("👍"), count: 1, chosenOrder: nil),
            MessageReaction(value: .builtin("🔥"), count: 1, chosenOrder: nil),
        ])
        XCTAssertEqual(result.recentPeers.map(\.peerId), [self.visiblePeer, self.visiblePeer])
        XCTAssertEqual(result.canViewList, attribute.canViewList)
    }

    func testOwnChosenReactionSurvivesEvenIfCountUnderflows() {
        // Inconsistent data: my chosen reaction with count 1 while a hidden peer is
        // also listed for the same value. The chosen reaction must not disappear.
        let attribute = ReactionsMessageAttribute(
            canViewList: true,
            isTags: false,
            reactions: [MessageReaction(value: .builtin("👍"), count: 1, chosenOrder: 0)],
            recentPeers: [recentPeer(.builtin("👍"), self.hiddenPeer)],
            topPeers: []
        )
        guard let result = self.settings.strippingHiddenReactions(from: attribute) else {
            XCTFail("chosen reaction should survive")
            return
        }
        XCTAssertEqual(result.reactions.count, 1)
        XCTAssertEqual(result.reactions[0].chosenOrder, 0)
        XCTAssertEqual(result.reactions[0].count, 1)
        XCTAssertTrue(result.recentPeers.isEmpty)
    }

    func testTagsAttributeIsNeverFiltered() {
        let attribute = ReactionsMessageAttribute(
            canViewList: true,
            isTags: true,
            reactions: [MessageReaction(value: .builtin("👍"), count: 1, chosenOrder: 0)],
            recentPeers: [recentPeer(.builtin("👍"), self.hiddenPeer)],
            topPeers: []
        )
        let result = self.settings.strippingHiddenReactions(from: attribute)
        XCTAssertTrue(result === attribute)
    }

    func testHiddenPaidTopPeerIsRemovedAndStarsSubtracted() {
        let attribute = ReactionsMessageAttribute(
            canViewList: true,
            isTags: false,
            reactions: [MessageReaction(value: .stars, count: 15, chosenOrder: nil)],
            recentPeers: [],
            topPeers: [
                ReactionsMessageAttribute.TopPeer(peerId: self.hiddenPeer, count: 10, isTop: true, isMy: false, isAnonymous: false),
                ReactionsMessageAttribute.TopPeer(peerId: self.visiblePeer, count: 5, isTop: false, isMy: false, isAnonymous: false),
            ]
        )
        guard let result = self.settings.strippingHiddenReactions(from: attribute) else {
            XCTFail("attribute should survive")
            return
        }
        XCTAssertEqual(result.reactions, [MessageReaction(value: .stars, count: 5, chosenOrder: nil)])
        XCTAssertEqual(result.topPeers.map(\.peerId), [self.visiblePeer])
    }

    func testAnonymousTopPeerSurvives() {
        let attribute = ReactionsMessageAttribute(
            canViewList: true,
            isTags: false,
            reactions: [MessageReaction(value: .stars, count: 3, chosenOrder: nil)],
            recentPeers: [],
            topPeers: [
                ReactionsMessageAttribute.TopPeer(peerId: nil, count: 3, isTop: true, isMy: false, isAnonymous: true),
            ]
        )
        let result = self.settings.strippingHiddenReactions(from: attribute)
        XCTAssertTrue(result === attribute)
    }
}
