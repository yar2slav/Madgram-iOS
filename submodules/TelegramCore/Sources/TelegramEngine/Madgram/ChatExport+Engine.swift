import Foundation
import Postbox
import SwiftSignalKit

public struct ChatExportArchivedContent {
    public let deletedMessages: [EngineMessage]
    public let versions: [EngineMessage.Id: [EngineMessage]]

    public init(deletedMessages: [EngineMessage], versions: [EngineMessage.Id: [EngineMessage]]) {
        self.deletedMessages = deletedMessages
        self.versions = versions
    }
}

public extension TelegramEngine.Messages {
    func chatExportArchivedContent(peerId: EnginePeer.Id) -> Signal<ChatExportArchivedContent, NoError> {
        return self.account.postbox.transaction { transaction -> ChatExportArchivedContent in
            let index = transaction.getPreferencesEntry(key: PreferencesKeys.deletedMessageArchiveIndex)?.get(DeletedMessageArchiveIndex.self) ?? .empty
            let peerIdValue = peerId.toInt64()
            var deletedMessages: [EngineMessage] = []
            var versions: [EngineMessage.Id: [EngineMessage]] = [:]
            var seen = Set<MessageId>()
            for entry in index.messageIds + index.liveMessageIds where entry.peerId == peerIdValue {
                let id = entry.messageId
                if seen.contains(id) {
                    continue
                }
                seen.insert(id)
                guard let message = transaction.getMessage(id) else {
                    continue
                }
                if message.isArchivedDeletedMessage {
                    deletedMessages.append(EngineMessage(message))
                }
                if let attribute = message.archivedMessageAttribute, !attribute.versionIds.isEmpty {
                    let previous = attribute.versionIds.compactMap(transaction.getMessage).map(EngineMessage.init)
                    if !previous.isEmpty {
                        let key = attribute.originalMessageId
                        versions[key] = previous
                    }
                }
            }
            return ChatExportArchivedContent(deletedMessages: deletedMessages, versions: versions)
        }
    }
}
