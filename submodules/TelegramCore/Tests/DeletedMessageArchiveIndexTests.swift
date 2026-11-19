import Foundation
import XCTest
import Postbox
@testable import TelegramCore

final class DeletedMessageArchiveIndexTests: XCTestCase {
    private struct LegacyIndex: Codable {
        var messageIds: [DeletedMessageArchiveIndexEntry]
        var liveMessageIds: [DeletedMessageArchiveIndexEntry]
    }

    private func entry(_ peer: Int64, _ namespace: Int32, _ id: Int32) -> DeletedMessageArchiveIndexEntry {
        return DeletedMessageArchiveIndexEntry(peerId: peer, namespace: namespace, id: id)
    }

    func testPackedRoundTripKeepsEveryEntry() throws {
        let messageIds = (0 ..< 5000).map { entry(Int64($0) * 7_000_000_000 - 3, Int32($0 % 10), Int32.max - Int32($0)) }
        let liveMessageIds = [entry(-1, 0, 1), entry(Int64.max, Int32.min, Int32.min)]
        let index = DeletedMessageArchiveIndex(messageIds: messageIds, liveMessageIds: liveMessageIds)
        let decoded = try XCTUnwrap(PreferencesEntry(index)?.get(DeletedMessageArchiveIndex.self))
        XCTAssertEqual(decoded, index)
    }

    func testLegacyEncodingStillDecodes() throws {
        let legacy = LegacyIndex(messageIds: [entry(42, 8, 3), entry(43, 9, 4)], liveMessageIds: [entry(42, 0, 100)])
        let decoded = try XCTUnwrap(PreferencesEntry(legacy)?.get(DeletedMessageArchiveIndex.self))
        XCTAssertEqual(decoded.messageIds, legacy.messageIds)
        XCTAssertEqual(decoded.liveMessageIds, legacy.liveMessageIds)
    }

    func testPackedEncodingIsSmallerThanLegacy() throws {
        let messageIds = (0 ..< 1000).map { entry(Int64($0), 8, Int32($0)) }
        let packed = try XCTUnwrap(PreferencesEntry(DeletedMessageArchiveIndex(messageIds: messageIds, liveMessageIds: [])))
        let legacy = try XCTUnwrap(PreferencesEntry(LegacyIndex(messageIds: messageIds, liveMessageIds: [])))
        XCTAssertLessThan(packed.data.count, legacy.data.count / 2)
    }
}
