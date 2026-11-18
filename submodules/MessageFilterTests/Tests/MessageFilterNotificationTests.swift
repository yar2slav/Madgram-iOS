import Foundation
import TelegramUIPreferences
import XCTest

private struct NotificationMessage: Equatable {
    let id: Int
    let authorIds: [Int64]
}

final class MessageFilterNotificationTests: XCTestCase {
    private let hiddenPeer: Int64 = 42
    private let blockedPeer: Int64 = 9
    private let visiblePeer: Int64 = 7

    private func visible(_ messages: [NotificationMessage], settings: MessageFilterSettings) -> [NotificationMessage] {
        return settings.visibleNotificationMessages(messages, authorIds: { $0.authorIds })
    }

    func testInactiveSettingsKeepEveryMessage() {
        let messages = [
            NotificationMessage(id: 1, authorIds: [self.hiddenPeer]),
            NotificationMessage(id: 2, authorIds: [])
        ]
        XCTAssertEqual(self.visible(messages, settings: .defaultSettings), messages)
    }

    func testShadowBannedAuthorLeavesNothingToPresent() {
        let settings = MessageFilterSettings(
            hideBlockedUsersMessages: false,
            shadowBannedPeerIds: [self.hiddenPeer],
            blockedPeerIdsCache: []
        )
        let messages = [
            NotificationMessage(id: 1, authorIds: [self.hiddenPeer]),
            NotificationMessage(id: 2, authorIds: [self.hiddenPeer])
        ]
        XCTAssertTrue(self.visible(messages, settings: settings).isEmpty)
    }

    func testBlockedAuthorIsDroppedOnlyWhenOptionIsEnabled() {
        var settings = MessageFilterSettings(
            hideBlockedUsersMessages: false,
            shadowBannedPeerIds: [],
            blockedPeerIdsCache: [self.blockedPeer]
        )
        let messages = [NotificationMessage(id: 1, authorIds: [self.blockedPeer])]
        XCTAssertEqual(self.visible(messages, settings: settings), messages)

        settings.hideBlockedUsersMessages = true
        XCTAssertTrue(self.visible(messages, settings: settings).isEmpty)
    }

    func testOnlyHiddenAuthorsMessagesAreRemoved() {
        let settings = MessageFilterSettings(
            hideBlockedUsersMessages: false,
            shadowBannedPeerIds: [self.hiddenPeer],
            blockedPeerIdsCache: []
        )
        let messages = [
            NotificationMessage(id: 1, authorIds: [self.hiddenPeer]),
            NotificationMessage(id: 2, authorIds: [self.visiblePeer]),
            NotificationMessage(id: 3, authorIds: [])
        ]
        XCTAssertEqual(self.visible(messages, settings: settings).map(\.id), [2, 3])
    }

    func testAnyHiddenAuthorIdHidesTheMessage() {
        // A message in Replies is attributed to its forwarded author as well as its own.
        let settings = MessageFilterSettings(
            hideBlockedUsersMessages: false,
            shadowBannedPeerIds: [self.hiddenPeer],
            blockedPeerIdsCache: []
        )
        let messages = [NotificationMessage(id: 1, authorIds: [self.visiblePeer, self.hiddenPeer])]
        XCTAssertTrue(self.visible(messages, settings: settings).isEmpty)
    }
}
