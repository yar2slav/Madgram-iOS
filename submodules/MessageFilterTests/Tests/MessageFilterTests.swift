import Foundation
import TelegramUIPreferences
import XCTest

final class MessageFilterTests: XCTestCase {
    func testDefaultSettingsHideNothing() {
        let settings = MessageFilterSettings.defaultSettings
        XCTAssertFalse(settings.hideBlockedUsersMessages)
        XCTAssertTrue(settings.shadowBannedPeerIds.isEmpty)
        XCTAssertTrue(settings.blockedPeerIdsCache.isEmpty)
        XCTAssertFalse(settings.isActive)
        XCTAssertFalse(settings.hidesMessages(fromAuthorId: 42))
    }

    func testShadowBanHidesRegardlessOfBlockedOption() {
        let settings = MessageFilterSettings(
            hideBlockedUsersMessages: false,
            shadowBannedPeerIds: [42],
            blockedPeerIdsCache: []
        )
        XCTAssertTrue(settings.isActive)
        XCTAssertTrue(settings.isShadowBanned(42))
        XCTAssertTrue(settings.hidesMessages(fromAuthorId: 42))
        XCTAssertFalse(settings.hidesMessages(fromAuthorId: 43))
    }

    func testBlockedPeersAreHiddenOnlyWhenOptionIsEnabled() {
        var settings = MessageFilterSettings(
            hideBlockedUsersMessages: false,
            shadowBannedPeerIds: [],
            blockedPeerIdsCache: [7]
        )
        XCTAssertFalse(settings.isActive)
        XCTAssertFalse(settings.hidesMessages(fromAuthorId: 7))

        settings.hideBlockedUsersMessages = true
        XCTAssertTrue(settings.isActive)
        XCTAssertTrue(settings.hidesMessages(fromAuthorId: 7))
        XCTAssertFalse(settings.isShadowBanned(7))
    }

    func testEnabledBlockedOptionWithEmptyMirrorIsInactive() {
        let settings = MessageFilterSettings(
            hideBlockedUsersMessages: true,
            shadowBannedPeerIds: [],
            blockedPeerIdsCache: []
        )
        XCTAssertFalse(settings.isActive)
    }

    func testSettingsRoundTripThroughCodable() throws {
        let settings = MessageFilterSettings(
            hideBlockedUsersMessages: true,
            shadowBannedPeerIds: [1, -100500],
            blockedPeerIdsCache: [9]
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(MessageFilterSettings.self, from: data)
        XCTAssertEqual(settings, decoded)
    }

    func testPaginationUsesUnfilteredBoundaryWhileFiltering() {
        let inactiveSettings = MessageFilterSettings.defaultSettings
        XCTAssertEqual(inactiveSettings.paginationAnchor(visible: 20, unfiltered: 10), 20)

        let activeSettings = MessageFilterSettings(
            hideBlockedUsersMessages: false,
            shadowBannedPeerIds: [42],
            blockedPeerIdsCache: []
        )
        XCTAssertEqual(activeSettings.paginationAnchor(visible: 20, unfiltered: 10), 10)
        XCTAssertEqual(activeSettings.paginationAnchor(visible: 20, unfiltered: nil), 20)
    }

    func testLegacyInterfaceTuningSettingsUseVisibleBusinessPanels() throws {
        let legacy = """
        {
          "concealBottomBar": false,
          "showContactsShortcut": true,
          "showCallsShortcut": true,
          "showTabLabels": true,
          "showSearchShortcut": true,
          "stretchBottomBar": false,
          "showProfileIdentifiers": false,
          "showDataCenter": false,
          "showRegistrationDate": false,
          "showChatCreationDate": false,
          "hideStoryStrip": false,
          "disableStoryCameraSwipe": false,
          "confirmStoryOpen": false,
          "allowStoryRepost": true,
          "startRoundVideoWithRearCamera": false,
          "hideGalleryCamera": false,
          "hidePhoneInSettings": false
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(InterfaceTuningSettings.self, from: legacy)
        XCTAssertFalse(decoded.hideBusinessBotPanel)
        XCTAssertTrue(decoded.businessBotPanelVisibilityOverrides.isEmpty)
        XCTAssertTrue(decoded.isBusinessBotPanelVisible(peerId: 42))
    }

    func testBusinessPanelOverrideHasPriorityOverGlobalSetting() {
        var settings = InterfaceTuningSettings.defaultSettings
        settings.hideBusinessBotPanel = true
        XCTAssertFalse(settings.isBusinessBotPanelVisible(peerId: 42))

        settings.businessBotPanelVisibilityOverrides[42] = true
        XCTAssertTrue(settings.isBusinessBotPanelVisible(peerId: 42))

        settings.hideBusinessBotPanel = false
        settings.businessBotPanelVisibilityOverrides[42] = false
        XCTAssertFalse(settings.isBusinessBotPanelVisible(peerId: 42))
        XCTAssertTrue(settings.isBusinessBotPanelVisible(peerId: 43))
    }
}
