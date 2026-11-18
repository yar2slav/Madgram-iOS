import Foundation
import XCTest
import Postbox
import SwiftSignalKit
@testable import TelegramCore

final class MadLocalChatTests: XCTestCase {
    private var postbox: Postbox!
    private var directory: URL!

    override func setUpWithError() throws {
        initializeAccountManagement()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("mad-local-chat-tests-" + UUID().uuidString)
        let encryption = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: try XCTUnwrap(.init(data: Data(count: 32))), salt: try XCTUnwrap(.init(data: Data(count: 16))))
        let opened = try value(openPostbox(basePath: directory.path, seedConfiguration: telegramPostboxSeedConfiguration, encryptionParameters: encryption, timestampForAbsoluteTimeBasedOperations: Int32(Date().timeIntervalSince1970), isMainProcess: true, isTemporary: false, isReadOnly: false, useCopy: false, useCaches: true, removeDatabaseOnError: false)
            |> filter { result in
                if case .upgrading = result { return false }
                return true
            })
        guard case let .postbox(postbox) = opened else {
            throw NSError(domain: "MadLocalChatTests", code: 1)
        }
        self.postbox = postbox
    }

    override func tearDownWithError() throws {
        if let postbox = postbox {
            let _ = try value(postbox.transaction { _ in })
            postbox.mediaBox.dataQueue.sync {}
        }
        postbox = nil
        Postbox.sharedQueue.sync {}
        if let directory = directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func value<T>(_ signal: Signal<T, NoError>, file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let expectation = self.expectation(description: "signal")
        var result: T?
        let disposable = (signal |> take(1)).start(next: { value in
            result = value
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 10.0)
        disposable.dispose()
        return try XCTUnwrap(result, file: file, line: line)
    }

    private func richText(_ text: String) -> RichTextMessageAttribute {
        return RichTextMessageAttribute(instantPage: InstantPage(blocks: [.paragraph(.plain(text))], media: [:], isComplete: true, rtl: false, url: "", views: nil), fullInstantPage: nil)
    }

    private func openedView() throws -> MessageHistoryView {
        let signal = postbox.aroundMessageOfInterestHistoryViewForChatLocation(.peer(peerId: MadLocalChat.peerId, threadId: nil), ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 50, topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud], tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .not(Namespaces.Message.allNonRegular), orderStatistics: [], customUnreadMessageId: nil, additionalData: [], useRootInterfaceStateForThread: false)
        return try value(signal |> map { $0.0 })
    }

    func testPostedChatOpensWithoutLoading() throws {
        let mediaBox = postbox.mediaBox
        let ids = try value(postbox.transaction { transaction -> [EngineMessage.Id] in
            _internal_madLocalChatPrepare(transaction: transaction, mediaBox: mediaBox, name: "mad", avatarJpeg: nil, avatarSide: 640)
            return _internal_madLocalChatPost(transaction: transaction, mediaBox: mediaBox, richTexts: [self.richText("one")], replacing: true)
        })
        XCTAssertEqual(ids.count, 1)
        let view = try openedView()
        XCTAssertFalse(view.isLoading)
        XCTAssertEqual(view.entries.count, 1)
    }

    func testRepostReplacesAndStillOpens() throws {
        let mediaBox = postbox.mediaBox
        let _ = try value(postbox.transaction { transaction -> [EngineMessage.Id] in
            _internal_madLocalChatPrepare(transaction: transaction, mediaBox: mediaBox, name: "mad", avatarJpeg: nil, avatarSide: 640)
            return _internal_madLocalChatPost(transaction: transaction, mediaBox: mediaBox, richTexts: [self.richText("old")], replacing: true)
        })
        let ids = try value(postbox.transaction { transaction -> [EngineMessage.Id] in
            _internal_madLocalChatPrepare(transaction: transaction, mediaBox: mediaBox, name: "mad", avatarJpeg: nil, avatarSide: 640)
            return _internal_madLocalChatPost(transaction: transaction, mediaBox: mediaBox, richTexts: [self.richText("new")], replacing: true)
        })
        XCTAssertEqual(ids.count, 1)
        let view = try openedView()
        XCTAssertFalse(view.isLoading)
        XCTAssertEqual(view.entries.map(\.message.id), ids)
    }

    func testUnreadLocalMessagesFromAnOlderBuildOpenAfterSettle() throws {
        let mediaBox = postbox.mediaBox
        let _ = try value(postbox.transaction { transaction -> Void in
            _internal_madLocalChatPrepare(transaction: transaction, mediaBox: mediaBox, name: "mad", avatarJpeg: nil, avatarSide: 640)
            let message = StoreMessage(peerId: MadLocalChat.peerId, namespace: Namespaces.Message.Local, customStableId: nil, globallyUniqueId: 1, groupingKey: nil, threadId: nil, timestamp: 100, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: MadLocalChat.peerId, text: "", attributes: [self.richText("old")], media: [])
            let _ = transaction.addMessages([message], location: .UpperHistoryBlock)
            transaction.updatePeerChatListInclusion(MadLocalChat.peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
        })
        let _ = try value(postbox.transaction { transaction -> Void in
            _internal_madLocalChatPrepare(transaction: transaction, mediaBox: mediaBox, name: "mad", avatarJpeg: nil, avatarSide: 640)
        })
        let view = try openedView()
        XCTAssertFalse(view.isLoading)
        XCTAssertEqual(view.entries.count, 1)
    }

    func testBusinessIntroIsKnownSoTheChatDoesNotWaitForTheServer() throws {
        let mediaBox = postbox.mediaBox
        let cachedData = try value(postbox.transaction { transaction -> CachedPeerData? in
            _internal_madLocalChatPrepare(transaction: transaction, mediaBox: mediaBox, name: "mad", avatarJpeg: nil, avatarSide: 640)
            return transaction.getPeerCachedData(peerId: MadLocalChat.peerId)
        })
        guard let userData = cachedData as? CachedUserData, case .known = userData.businessIntro else {
            XCTFail("business intro must be known locally")
            return
        }
    }

    func testReadingTheChatQueuesASyncThatOnlyConfirmationCanEnd() throws {
        let mediaBox = postbox.mediaBox
        let peerId = MadLocalChat.peerId
        let _ = try value(postbox.transaction { transaction -> Void in
            _internal_madLocalChatPrepare(transaction: transaction, mediaBox: mediaBox, name: "mad", avatarJpeg: nil, avatarSide: 640)
            let _ = _internal_madLocalChatPost(transaction: transaction, mediaBox: mediaBox, richTexts: [self.richText("one")], replacing: true)
            if let index = transaction.getTopPeerMessageIndex(peerId: peerId) {
                let _ = transaction.applyInteractiveReadMaxIndex(index)
            }
        })
        let hasInputPeer = try value(postbox.transaction { transaction -> Bool in
            return transaction.getPeer(peerId).flatMap(apiInputPeer) != nil
        })
        XCTAssertFalse(hasInputPeer)
        let queued = try value(postbox.synchronizePeerReadStatesView() |> map { $0.operations[peerId] != nil })
        XCTAssertTrue(queued)
        let _ = try value(postbox.transaction { transaction -> Void in
            transaction.confirmSynchronizedIncomingReadState(peerId)
        })
        let stillQueued = try value(postbox.synchronizePeerReadStatesView() |> map { $0.operations[peerId] != nil })
        XCTAssertFalse(stillQueued)
    }
}
