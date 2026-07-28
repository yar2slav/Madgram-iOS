import Postbox
import TelegramCore
import XCTest

final class DeletedMessageArchiveTests: XCTestCase {
    func testDefaultSettingsAreTemporaryAndUseFiveGigabyteQuota() {
        let settings = DeletedMessageArchiveSettings.defaultSettings
        XCTAssertTrue(settings.isEnabled)
        XCTAssertFalse(settings.keepAcrossLaunches)
        XCTAssertEqual(settings.mediaLimitGigabytes, 5)
    }

    func testArchiveAttributeKeepsOriginalAndVersionIds() {
        let peerId = PeerId(123)
        let originalId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 10)
        let versionId = MessageId(peerId: peerId, namespace: Namespaces.Message.ArchivedVersion, id: 1)
        let attribute = ArchivedMessageAttribute(
            originalMessageId: originalId,
            versionIds: [versionId],
            deletedAt: 100,
            sessionId: 200
        )

        XCTAssertEqual(attribute.originalMessageId, originalId)
        XCTAssertEqual(attribute.associatedMessageIds, [versionId])
        XCTAssertEqual(attribute.deletedAt, 100)
        XCTAssertEqual(attribute.sessionId, 200)
    }

    func testVolatileAttributesDoNotCreateDuplicateRevision() {
        XCTAssertTrue(deletedMessageArchiveContentsAreEqual(
            lhsText: "same",
            lhsAttributes: [EditedMessageAttribute(date: 1, isHidden: false)],
            lhsMedia: [],
            rhsText: "same",
            rhsAttributes: [EditedMessageAttribute(date: 2, isHidden: false)],
            rhsMedia: []
        ))
    }

    func testTextChangeCreatesRevision() {
        XCTAssertFalse(deletedMessageArchiveContentsAreEqual(
            lhsText: "before",
            lhsAttributes: [],
            lhsMedia: [],
            rhsText: "after",
            rhsAttributes: [],
            rhsMedia: []
        ))
    }
}
