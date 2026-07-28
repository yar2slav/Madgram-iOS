import Foundation
import Display
import Postbox
import SwiftSignalKit
import TelegramCore
import AccountContext

final class MessageVersionsChatContents: ChatCustomContentsProtocol {
    let kind: ChatCustomContentsKind

    private let context: AccountContext
    private let originalMessageId: EngineMessage.Id
    private let versions: [EngineMessage]

    init(context: AccountContext, originalMessageId: EngineMessage.Id, versions: [EngineMessage]) {
        self.context = context
        self.originalMessageId = originalMessageId
        self.versions = MessageVersionsChatContents.displayMessages(versions)
        self.kind = .messageVersionHistory(originalMessageId: originalMessageId, versionCount: versions.count)
    }

    private static func displayMessages(_ versions: [EngineMessage]) -> [EngineMessage] {
        var result: [EngineMessage] = []
        var previousTimestamp: Int32?
        for version in versions {
            let rawMessage = version._asMessage()
            var timestamp = rawMessage.archivedVersionCapturedAt
                ?? rawMessage.archivedMessageAttribute?.deletedAt
                ?? rawMessage.editedTime
                ?? rawMessage.timestamp
            if let previousTimestamp, timestamp <= previousTimestamp {
                timestamp = previousTimestamp + 1
            }
            previousTimestamp = timestamp
            result.append(EngineMessage(rawMessage.withUpdatedTimestamp(timestamp)))
        }
        return result
    }

    var historyView: Signal<(EngineRawMessageHistoryView, EngineViewUpdateType), NoError> {
        let entries = self.versions.map { message in
            return EngineRawMessageHistoryEntry(
                message: message._asMessage(),
                isRead: true,
                location: nil,
                monthLocation: nil,
                attributes: EngineRawMutableMessageHistoryEntryAttributes(authorIsContact: false)
            )
        }
        let view = EngineRawMessageHistoryView(
            tag: nil,
            namespaces: .just(Set([Namespaces.Message.Cloud, Namespaces.Message.Archived, Namespaces.Message.ArchivedVersion])),
            entries: entries,
            holeEarlier: false,
            holeLater: false,
            isLoading: false
        )
        return .single((view, .Initial))
    }

    var messageLimit: Int? {
        return nil
    }

    func enqueueMessages(messages: [EnqueueMessage]) {
    }

    func deleteMessages(ids: [EngineMessage.Id]) {
    }

    func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {
    }

    func quickReplyUpdateShortcut(value: String) {
    }

    func businessLinkUpdate(message: String, entities: [MessageTextEntity], title: String?) {
    }

    func loadMore() {
    }

    func hashtagSearchUpdate(query: String) {
    }

    var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in }
}

func makeMessageVersionsChatController(context: AccountContext, originalMessageId: EngineMessage.Id, versions: [EngineMessage]) -> ViewController {
    let contents = MessageVersionsChatContents(context: context, originalMessageId: originalMessageId, versions: versions)
    let controller = context.sharedContext.makeChatController(
        context: context,
        chatLocation: .customChatContents,
        subject: .customChatContents(contents: contents),
        botStart: nil,
        mode: .standard(.default),
        params: nil
    )
    controller.navigationPresentation = .modal
    return controller
}
