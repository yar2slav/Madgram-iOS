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

    func testViewOnceMediaIsKeptWithoutGhostMode() {
        var settings = GhostModeSettings.defaultSettings
        settings.keepViewOnceMedia = true
        XCTAssertTrue(settings.keepsViewOnceMedia)
        XCTAssertTrue(ghostModeDefersViewOnceConsumption(settings: settings, isViewOnce: true, isSecretChat: false, force: false))

        settings.isEnabled = true
        XCTAssertTrue(settings.keepsViewOnceMedia)
    }

    func testViewOnceConsumptionIsDeferredOnlyWhenEveryConditionHolds() {
        var settings = GhostModeSettings.defaultSettings
        settings.isEnabled = true
        settings.keepViewOnceMedia = true

        XCTAssertTrue(ghostModeDefersViewOnceConsumption(settings: settings, isViewOnce: true, isSecretChat: false, force: false))

        // Burning explicitly always consumes.
        XCTAssertFalse(ghostModeDefersViewOnceConsumption(settings: settings, isViewOnce: true, isSecretChat: false, force: true))
        // Secret chats are deferred too; Burn remains the explicit protocol release.
        XCTAssertTrue(ghostModeDefersViewOnceConsumption(settings: settings, isViewOnce: true, isSecretChat: true, force: false))
        // Ordinary media is unaffected.
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

    func testReadMarkerIsCreatedOnlyForServerUnreadState() {
        XCTAssertFalse(ghostModeShouldTrackRead(previousReadState: GhostModePreviousReadState(
            maxIncomingReadId: 10,
            maxOutgoingReadId: 10,
            maxKnownId: 10,
            count: 0,
            markedUnread: false
        )))
        XCTAssertTrue(ghostModeShouldTrackRead(previousReadState: GhostModePreviousReadState(
            maxIncomingReadId: 10,
            maxOutgoingReadId: 10,
            maxKnownId: 12,
            count: 2,
            markedUnread: false
        )))
        XCTAssertTrue(ghostModeShouldTrackRead(previousReadState: GhostModePreviousReadState(
            maxIncomingReadId: 10,
            maxOutgoingReadId: 10,
            maxKnownId: 10,
            count: 0,
            markedUnread: true
        )))
    }

    func testReadMarkerWaitsForServerReadWatermark() {
        let marker = self.peerMarker(peerId: PeerId(1), snapshot: GhostModePreviousReadState(
            maxIncomingReadId: 10,
            maxOutgoingReadId: 10,
            maxKnownId: 15,
            count: 5,
            markedUnread: false
        ))
        XCTAssertFalse(ghostModeReadStateIsAcknowledged(marker: marker, maxReadId: marker.maxReadIndex.id.id - 1))
        XCTAssertTrue(ghostModeReadStateIsAcknowledged(marker: marker, maxReadId: marker.maxReadIndex.id.id))
        XCTAssertTrue(ghostModeReadStateIsAcknowledged(marker: marker, maxReadId: marker.maxReadIndex.id.id + 1))
    }

    func testOlderCommitDoesNotRemoveNewerReadMarker() {
        let committed = self.peerMarker(peerId: PeerId(1), snapshot: nil)
        let newer = GhostModeReadStateMarker(
            peerId: committed.peerId,
            threadId: committed.threadId,
            namespace: committed.namespace,
            maxReadIndex: MessageIndex(
                id: MessageId(
                    peerId: committed.peerId,
                    namespace: committed.namespace,
                    id: committed.maxReadIndex.id.id + 1
                ),
                timestamp: committed.maxReadIndex.timestamp + 1
            )
        )
        XCTAssertTrue(ghostModeCommitCoversCurrentMarker(committed: committed, current: committed))
        XCTAssertFalse(ghostModeCommitCoversCurrentMarker(committed: committed, current: newer))
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

    func testResetPlanRollsBackPeerThreadAndStoryMarkers() {
        let chatMarker = self.peerMarker(peerId: PeerId(1), snapshot: GhostModePreviousReadState(
            maxIncomingReadId: 10,
            maxOutgoingReadId: 8,
            maxKnownId: 15,
            count: 5,
            markedUnread: true
        ))
        let topicMarker = self.threadMarker(peerId: PeerId(2), threadId: 77, snapshot: GhostModePreviousThreadReadState(
            maxIncomingReadId: 20,
            maxKnownMessageId: 25,
            incomingUnreadCount: 3,
            markedUnread: false
        ))
        let seenStoryMarker = self.storyMarker(peerId: PeerId(3), previousStoryReadId: 42)

        let plan = ghostModeResetPlan(
            markers: [chatMarker, topicMarker, seenStoryMarker],
            includeMessages: true,
            includeStories: true
        )

        XCTAssertEqual(plan.peerRollbacks.map { $0.peerId }, [PeerId(1)])
        XCTAssertEqual(plan.peerRollbacks.first?.readState, chatMarker.previousReadState)
        XCTAssertEqual(plan.threadRollbacks.map { $0.threadId }, [77])
        XCTAssertEqual(plan.threadRollbacks.first?.readState, topicMarker.previousThreadReadState)
        XCTAssertEqual(plan.storyRollbacks.map { $0.maxReadId }, [42])
        XCTAssertTrue(plan.peersNeedingServerState.isEmpty)
        XCTAssertEqual(plan.consumedMarkers.count, 3)
        XCTAssertFalse(plan.isEmpty)
    }

    func testResetPlanRoutesSnapshotlessPeerMarkerToServer() {
        let marker = peerMarker(peerId: PeerId(1), snapshot: nil)

        let plan = ghostModeResetPlan(markers: [marker], includeMessages: true, includeStories: true)

        XCTAssertTrue(plan.peerRollbacks.isEmpty)
        XCTAssertEqual(plan.peersNeedingServerState, [PeerId(1)])
        XCTAssertEqual(plan.consumedMarkers, [marker])
    }

    func testResetPlanKeepsStoryMarkersWhenOnlyMessagesRestore() {
        let messages = peerMarker(peerId: PeerId(1), snapshot: GhostModePreviousReadState(
            maxIncomingReadId: 10,
            maxOutgoingReadId: 8,
            maxKnownId: 15,
            count: 5,
            markedUnread: false
        ))
        let stories = storyMarker(peerId: PeerId(3), previousStoryReadId: 42)

        let plan = ghostModeResetPlan(markers: [messages, stories], includeMessages: true, includeStories: false)

        XCTAssertTrue(plan.storyRollbacks.isEmpty)
        XCTAssertEqual(plan.consumedMarkers, [messages])
    }

    func testResetPlanKeepsMessageMarkersWhenOnlyStoriesRestore() {
        let messages = peerMarker(peerId: PeerId(1), snapshot: GhostModePreviousReadState(
            maxIncomingReadId: 10,
            maxOutgoingReadId: 8,
            maxKnownId: 15,
            count: 5,
            markedUnread: false
        ))
        let stories = storyMarker(peerId: PeerId(3), previousStoryReadId: 42)

        let plan = ghostModeResetPlan(markers: [messages, stories], includeMessages: false, includeStories: true)

        XCTAssertTrue(plan.peerRollbacks.isEmpty)
        XCTAssertTrue(plan.peersNeedingServerState.isEmpty)
        XCTAssertEqual(plan.consumedMarkers, [stories])
    }

    func testResetPlanIsEmptyWithoutMarkers() {
        let plan = ghostModeResetPlan(markers: [], includeMessages: true, includeStories: true)

        XCTAssertTrue(plan.isEmpty)
    }

    private func peerMarker(peerId: PeerId, snapshot: GhostModePreviousReadState?) -> GhostModeReadStateMarker {
        return GhostModeReadStateMarker(
            peerId: peerId,
            threadId: nil,
            namespace: Namespaces.Message.Cloud,
            maxReadIndex: MessageIndex(
                id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 15),
                timestamp: 100
            ),
            previousReadState: snapshot
        )
    }

    private func threadMarker(peerId: PeerId, threadId: Int64, snapshot: GhostModePreviousThreadReadState?) -> GhostModeReadStateMarker {
        return GhostModeReadStateMarker(
            peerId: peerId,
            threadId: threadId,
            namespace: Namespaces.Message.Cloud,
            maxReadIndex: MessageIndex(
                id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 25),
                timestamp: 200
            ),
            previousThreadReadState: snapshot
        )
    }

    private func storyMarker(peerId: PeerId, previousStoryReadId: Int32?) -> GhostModeReadStateMarker {
        return GhostModeReadStateMarker(
            peerId: peerId,
            threadId: nil,
            namespace: ghostModeStoryNamespace,
            maxReadIndex: MessageIndex(
                id: MessageId(peerId: peerId, namespace: ghostModeStoryNamespace, id: 55),
                timestamp: 0
            ),
            previousStoryReadId: previousStoryReadId
        )
    }
}
