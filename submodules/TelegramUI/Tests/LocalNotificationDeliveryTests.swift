import XCTest

final class LocalNotificationDeliveryTests: XCTestCase {
    func testConcurrentBatchesCannotScheduleTheSameMessageTwice() throws {
        let state = LocalNotificationDeliveryState()
        let token = try XCTUnwrap(state.reserve("account1:peer1:msg1", now: 0))
        XCTAssertNil(state.reserve("account1:peer1:msg1", now: 1))
        state.complete("account1:peer1:msg1", token: token, delivered: true, now: 2)
        XCTAssertNil(state.reserve("account1:peer1:msg1", now: 3))
        XCTAssertNotNil(state.reserve("account2:peer1:msg1", now: 3))
    }

    func testNotificationCenterFailureDoesNotConsumeTheMessage() throws {
        let state = LocalNotificationDeliveryState()
        let token = try XCTUnwrap(state.reserve("message", now: 0))
        state.complete("message", token: token, delivered: false, now: 1)
        XCTAssertNotNil(state.reserve("message", now: 2))
    }

    func testForegroundCancellationInvalidatesAnOutstandingDatabaseRead() throws {
        let state = LocalNotificationDeliveryState()
        let old = try XCTUnwrap(state.reserve("message", now: 0))
        state.cancelPending()
        XCTAssertFalse(state.isPending("message", token: old))
        let current = try XCTUnwrap(state.reserve("message", now: 1))
        state.complete("message", token: old, delivered: true, now: 2)
        XCTAssertTrue(state.isPending("message", token: current))
        state.complete("message", token: current, delivered: false, now: 3)
        XCTAssertNotNil(state.reserve("message", now: 4))
    }

    func testReturningToBackgroundDoesNotRepeatSuccessfullyScheduledMessages() throws {
        let state = LocalNotificationDeliveryState()
        let token = try XCTUnwrap(state.reserve("message", now: 0))
        state.complete("message", token: token, delivered: true, now: 1)
        state.cancelPending()
        XCTAssertNil(state.reserve("message", now: 2))
        XCTAssertNotNil(state.reserve("message", now: 301))
    }

    func testHistoryAndInFlightWorkAreBounded() throws {
        let state = LocalNotificationDeliveryState(limit: 2)
        let first = try XCTUnwrap(state.reserve("first", now: 0))
        let second = try XCTUnwrap(state.reserve("second", now: 1))
        XCTAssertNil(state.reserve("third", now: 2))
        state.complete("first", token: first, delivered: true, now: 3)
        state.complete("second", token: second, delivered: true, now: 4)
        let third = try XCTUnwrap(state.reserve("third", now: 5))
        state.complete("third", token: third, delivered: true, now: 6)
        XCTAssertNotNil(state.reserve("first", now: 7))
        XCTAssertNil(state.reserve("second", now: 7))
    }
}
