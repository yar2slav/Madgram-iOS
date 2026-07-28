import Foundation
import Postbox
import TelegramCore
import XCTest

final class GhostModeTests: XCTestCase {
    func testDefaultSettingsArePrivateButDisabled() {
        let settings = GhostModeSettings.defaultSettings
        XCTAssertFalse(settings.isEnabled)
        XCTAssertTrue(settings.suppressMessageReadReceipts)
        XCTAssertTrue(settings.suppressStoryReadReceipts)
        XCTAssertTrue(settings.suppressOnlineStatus)
        XCTAssertTrue(settings.suppressTypingStatus)
        XCTAssertFalse(settings.revealOnInteractions)
        XCTAssertTrue(settings.goOfflineAutomatically)
        XCTAssertFalse(settings.hidesMessageReadReceipts)
        XCTAssertFalse(settings.hidesOnlineStatus)
    }

    func testMasterSwitchActivatesConfiguredProtections() {
        var settings = GhostModeSettings.defaultSettings
        settings.isEnabled = true
        XCTAssertTrue(settings.hidesMessageReadReceipts)
        XCTAssertTrue(settings.hidesStoryReadReceipts)
        XCTAssertTrue(settings.hidesOnlineStatus)
        XCTAssertTrue(settings.hidesTypingStatus)
    }

    func testIndividualProtectionCanBeDisabled() {
        var settings = GhostModeSettings.defaultSettings
        settings.isEnabled = true
        settings.suppressMessageReadReceipts = false
        XCTAssertFalse(settings.hidesMessageReadReceipts)
        XCTAssertTrue(settings.hidesOnlineStatus)
    }

    func testSettingsRoundTripKeepsChildConfiguration() throws {
        var settings = GhostModeSettings.defaultSettings
        settings.isEnabled = true
        settings.suppressStoryReadReceipts = false
        settings.revealOnInteractions = true

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(GhostModeSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    func testViewOnceMediaIsNotKeptByDefault() {
        var settings = GhostModeSettings.defaultSettings
        XCTAssertFalse(settings.keepViewOnceMedia)
        XCTAssertFalse(settings.keepsViewOnceMedia)

        settings.isEnabled = true
        XCTAssertFalse(settings.keepsViewOnceMedia)
    }

    func testViewOnceMediaRequiresBothSwitches() {
        var settings = GhostModeSettings.defaultSettings
        settings.keepViewOnceMedia = true
        XCTAssertFalse(settings.keepsViewOnceMedia)

        settings.isEnabled = true
        XCTAssertTrue(settings.keepsViewOnceMedia)
    }

    func testViewOnceConsumptionIsDeferredOnlyWhenEveryConditionHolds() {
        var settings = GhostModeSettings.defaultSettings
        settings.isEnabled = true
        settings.keepViewOnceMedia = true

        XCTAssertTrue(ghostModeDefersViewOnceConsumption(settings: settings, isViewOnce: true, isSecretChat: false, force: false))

        XCTAssertFalse(ghostModeDefersViewOnceConsumption(settings: settings, isViewOnce: true, isSecretChat: false, force: true))
        XCTAssertTrue(ghostModeDefersViewOnceConsumption(settings: settings, isViewOnce: true, isSecretChat: true, force: false))
        XCTAssertFalse(ghostModeDefersViewOnceConsumption(settings: settings, isViewOnce: false, isSecretChat: false, force: false))

        settings.keepViewOnceMedia = false
        XCTAssertFalse(ghostModeDefersViewOnceConsumption(settings: settings, isViewOnce: true, isSecretChat: false, force: false))
    }

    func testViewOnceCaptureKeepsExplicitProtection() {
        var settings = GhostModeSettings.defaultSettings
        settings.isEnabled = true
        settings.keepViewOnceMedia = true

        XCTAssertTrue(ghostModeAllowsViewOnceCapture(
            settings: settings,
            isViewOnce: true,
            isIncoming: true,
            isConsumed: false,
            hasExplicitCopyProtection: false,
            hasPaidContent: false
        ))
        XCTAssertFalse(ghostModeAllowsViewOnceCapture(
            settings: settings,
            isViewOnce: true,
            isIncoming: true,
            isConsumed: false,
            hasExplicitCopyProtection: true,
            hasPaidContent: false
        ))
        XCTAssertFalse(ghostModeAllowsViewOnceCapture(
            settings: settings,
            isViewOnce: true,
            isIncoming: true,
            isConsumed: false,
            hasExplicitCopyProtection: false,
            hasPaidContent: true
        ))
        XCTAssertFalse(ghostModeAllowsViewOnceCapture(
            settings: settings,
            isViewOnce: true,
            isIncoming: true,
            isConsumed: true,
            hasExplicitCopyProtection: false,
            hasPaidContent: false
        ))
    }

    func testSettingsStoredBeforeViewOnceFieldStillDecode() throws {
        let legacy = """
        {
            "isEnabled": true,
            "suppressMessageReadReceipts": false,
            "suppressStoryReadReceipts": true,
            "suppressOnlineStatus": true,
            "suppressTypingStatus": false,
            "revealOnInteractions": true,
            "goOfflineAutomatically": false
        }
        """
        let decoded = try JSONDecoder().decode(GhostModeSettings.self, from: Data(legacy.utf8))

        XCTAssertTrue(decoded.isEnabled)
        XCTAssertFalse(decoded.suppressMessageReadReceipts)
        XCTAssertTrue(decoded.revealOnInteractions)
        XCTAssertFalse(decoded.keepViewOnceMedia)
    }

    func testReadMarkerKeepsRollbackSnapshot() {
        let peerId = PeerId(123)
        let snapshot = GhostModePreviousReadState(
            maxIncomingReadId: 10,
            maxOutgoingReadId: 8,
            maxKnownId: 15,
            count: 5,
            markedUnread: true
        )
        let marker = GhostModeReadStateMarker(
            peerId: peerId,
            threadId: nil,
            namespace: Namespaces.Message.Cloud,
            maxReadIndex: MessageIndex(
                id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 15),
                timestamp: 100
            ),
            previousReadState: snapshot
        )

        XCTAssertEqual(marker.previousReadState, snapshot)
        XCTAssertEqual(marker.maxReadIndex.id.id, 15)
    }

    func testThreadMarkerKeepsRollbackSnapshot() {
        let peerId = PeerId(456)
        let snapshot = GhostModePreviousThreadReadState(
            maxIncomingReadId: 20,
            maxKnownMessageId: 25,
            incomingUnreadCount: 5,
            markedUnread: false
        )
        let marker = GhostModeReadStateMarker(
            peerId: peerId,
            threadId: 77,
            namespace: Namespaces.Message.Cloud,
            maxReadIndex: MessageIndex(
                id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 25),
                timestamp: 200
            ),
            previousThreadReadState: snapshot
        )

        XCTAssertEqual(marker.previousThreadReadState, snapshot)
        XCTAssertEqual(marker.threadId, 77)
    }
}
