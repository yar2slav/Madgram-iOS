import Foundation
import TelegramCore
import XCTest

private let megabyte: Int64 = 1024 * 1024

final class DeletedMessageArchiveRetentionTests: XCTestCase {
    private func plan(
        _ items: [(id: String, size: Int64, isDisappearing: Bool)],
        limit: Int64,
        disappearingLimit: Int64
    ) -> (retained: [String], removed: [String]) {
        return deletedMessageArchiveRetentionPlan(items: items, limitBytes: limit, disappearingLimitBytes: disappearingLimit)
    }

    func testEverythingIsRetainedBelowBothLimits() {
        let result = self.plan(
            [
                (id: "a", size: 10 * megabyte, isDisappearing: false),
                (id: "b", size: 20 * megabyte, isDisappearing: true)
            ],
            limit: 100 * megabyte,
            disappearingLimit: 50 * megabyte
        )

        XCTAssertEqual(result.retained, ["a", "b"])
        XCTAssertTrue(result.removed.isEmpty)
    }

    func testDisappearingMediaCannotExceedItsOwnBudget() {
        let result = self.plan(
            [
                (id: "ordinary", size: 10 * megabyte, isDisappearing: false),
                (id: "video", size: 80 * megabyte, isDisappearing: true),
                (id: "photo", size: 5 * megabyte, isDisappearing: true)
            ],
            limit: 500 * megabyte,
            disappearingLimit: 50 * megabyte
        )

        XCTAssertEqual(result.removed, ["video"])
        XCTAssertEqual(result.retained, ["ordinary", "photo"])
    }

    func testOrdinaryArchiveSurvivesALargeDisappearingVideo() {
        var items: [(id: String, size: Int64, isDisappearing: Bool)] = []
        for index in 0 ..< 20 {
            items.append((id: "small-\(index)", size: megabyte, isDisappearing: false))
        }
        items.append((id: "video", size: 90 * megabyte, isDisappearing: true))

        let result = self.plan(items, limit: 60 * megabyte, disappearingLimit: 50 * megabyte)

        XCTAssertEqual(result.removed, ["video"])
        XCTAssertEqual(result.retained.count, 20)
    }

    func testLargestFilesAreEvictedFirst() {
        let result = self.plan(
            [
                (id: "old-small", size: 5 * megabyte, isDisappearing: false),
                (id: "big", size: 60 * megabyte, isDisappearing: false),
                (id: "new-small", size: 5 * megabyte, isDisappearing: false)
            ],
            limit: 50 * megabyte,
            disappearingLimit: 50 * megabyte
        )

        XCTAssertEqual(result.removed, ["big"])
        XCTAssertEqual(result.retained, ["old-small", "new-small"])
    }

    func testEqualSizesAreEvictedOldestFirst() {
        let result = self.plan(
            [
                (id: "oldest", size: 30 * megabyte, isDisappearing: false),
                (id: "newest", size: 30 * megabyte, isDisappearing: false)
            ],
            limit: 30 * megabyte,
            disappearingLimit: 30 * megabyte
        )

        XCTAssertEqual(result.removed, ["oldest"])
        XCTAssertEqual(result.retained, ["newest"])
    }

    func testDisappearingTrimCountsTowardsTheOverallLimit() {
        let result = self.plan(
            [
                (id: "ordinary", size: 40 * megabyte, isDisappearing: false),
                (id: "disappearing", size: 40 * megabyte, isDisappearing: true)
            ],
            limit: 50 * megabyte,
            disappearingLimit: 50 * megabyte
        )

        XCTAssertEqual(result.removed.count, 1)
        XCTAssertEqual(result.retained.count, 1)
    }

    func testLegacyEnabledSettingMigratesToBothSwitches() throws {
        let legacy = """
        {
            "isEnabled": false,
            "keepAcrossLaunches": true,
            "mediaLimitGigabytes": 10,
            "disappearingMediaLimitGigabytes": 2,
            "sessionId": 42
        }
        """
        let settings = try JSONDecoder().decode(DeletedMessageArchiveSettings.self, from: Data(legacy.utf8))

        XCTAssertFalse(settings.saveDeletedMessages)
        XCTAssertFalse(settings.saveEditedVersions)
        XCTAssertEqual(settings.deletedMessageMarker, "🧹")
        XCTAssertFalse(settings.isEnabled)
    }

    func testArchiveSwitchesRemainIndependent() {
        var settings = DeletedMessageArchiveSettings.defaultSettings
        settings.saveDeletedMessages = false

        XCTAssertFalse(settings.saveDeletedMessages)
        XCTAssertTrue(settings.saveEditedVersions)
        XCTAssertTrue(settings.isEnabled)
    }

    func testDeletedMarkerFallsBackAndIsLimited() {
        XCTAssertEqual(DeletedMessageArchiveSettings.normalizedDeletedMessageMarker("   "), "🧹")
        XCTAssertEqual(DeletedMessageArchiveSettings.normalizedDeletedMessageMarker("  removed  "), "removed")
        XCTAssertEqual(
            DeletedMessageArchiveSettings.normalizedDeletedMessageMarker(String(repeating: "x", count: 40)).count,
            DeletedMessageArchiveSettings.deletedMessageMarkerLimit
        )
    }
}
