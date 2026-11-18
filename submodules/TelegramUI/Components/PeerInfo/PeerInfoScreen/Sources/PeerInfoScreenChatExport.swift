import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import StorageUsageScreen
import PresentationDataUtils
import TelegramUIPreferences
import UndoUI
import ChatExport
import MadLockUI

private func chatExportPeerId(_ peer: EnginePeer) -> String {
    switch peer {
    case .user:
        return "user\(peer.id.id._internalGetInt64Value())"
    case .channel:
        return "channel\(peer.id.id._internalGetInt64Value())"
    default:
        return "chat\(peer.id.id._internalGetInt64Value())"
    }
}

private func chatExportChatType(_ peer: EnginePeer) -> String {
    switch peer {
    case let .user(user):
        return user.botInfo != nil ? "bot_chat" : "personal_chat"
    case .legacyGroup:
        return "private_group"
    case let .channel(channel):
        let isPublic = channel.addressName != nil
        if case .broadcast = channel.info {
            return isPublic ? "public_channel" : "private_channel"
        }
        return isPublic ? "public_supergroup" : "private_supergroup"
    default:
        return "personal_chat"
    }
}

private func chatExportEntityKind(_ type: MessageTextEntityType) -> ChatExportTextPart.Kind? {
    switch type {
    case .Mention:
        return .mention
    case .Hashtag:
        return .hashtag
    case .BotCommand:
        return .botCommand
    case .Url:
        return .link
    case .Email:
        return .email
    case .Bold:
        return .bold
    case .Italic:
        return .italic
    case .Code:
        return .code
    case let .Pre(language):
        return .pre(language: language)
    case let .TextUrl(url):
        return .textLink(url: url)
    case let .TextMention(peerId):
        return .mentionName(userId: peerId.id._internalGetInt64Value())
    case .PhoneNumber:
        return .phone
    case .Strikethrough:
        return .strikethrough
    case .BlockQuote:
        return .blockquote
    case .Underline:
        return .underline
    case .BankCard:
        return .bankCard
    case .Spoiler:
        return .spoiler
    case let .CustomEmoji(_, fileId):
        return .customEmoji(documentId: fileId)
    default:
        return nil
    }
}

private func chatExportMedia(_ message: EngineMessage) -> (String, String?)? {
    for media in message.media {
        if let _ = media as? TelegramMediaImage {
            return ("photo", nil)
        } else if let file = media as? TelegramMediaFile {
            let type: String
            if file.isInstantVideo {
                type = "video_message"
            } else if file.isVoice {
                type = "voice_message"
            } else if file.isSticker || file.isAnimatedSticker || file.isVideoSticker {
                type = "sticker"
            } else if file.isAnimated {
                type = "animation"
            } else if file.isVideo {
                type = "video_file"
            } else if file.isMusic {
                type = "audio_file"
            } else {
                type = "file"
            }
            return (type, file.fileName)
        } else if media is TelegramMediaPoll {
            return ("poll", nil)
        } else if media is TelegramMediaContact {
            return ("contact", nil)
        } else if media is TelegramMediaMap {
            return ("location", nil)
        } else if media is TelegramMediaDice {
            return ("dice", nil)
        } else if media is TelegramMediaWebpage {
            return nil
        }
    }
    return nil
}

private func chatExportMessage(_ message: EngineMessage, accountPeerId: EnginePeer.Id, versions: [EngineMessage.Id: [EngineMessage]], strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder) -> ChatExportMessage? {
    let rawMessage = message._asMessage()
    if message.media.contains(where: { $0 is TelegramMediaAction }) {
        return nil
    }
    let isDeleted = rawMessage.isArchivedDeletedMessage
    let originalId = rawMessage.archivedMessageAttribute?.originalMessageId ?? message.id

    var entities: [(range: Range<Int>, kind: ChatExportTextPart.Kind)] = []
    var editDate: Int32?
    var replyToMessageId: Int32?
    for attribute in message.attributes {
        if let attribute = attribute as? TextEntitiesMessageAttribute {
            for entity in attribute.entities {
                if let kind = chatExportEntityKind(entity.type) {
                    entities.append((entity.range, kind))
                }
            }
        } else if let attribute = attribute as? EditedMessageAttribute, !attribute.isHidden {
            editDate = attribute.date
        } else if let attribute = attribute as? ReplyMessageAttribute {
            replyToMessageId = attribute.messageId.id
        }
    }

    var forwardedFrom: String?
    if let forwardInfo = message.forwardInfo {
        if let author = forwardInfo.author {
            forwardedFrom = EnginePeer(author).displayTitle(strings: strings, displayOrder: nameDisplayOrder)
        } else if let authorSignature = forwardInfo.authorSignature {
            forwardedFrom = authorSignature
        }
    }

    let media = chatExportMedia(message)
    let author = message.author
    let editHistory = (versions[originalId] ?? []).map { version -> ChatExportVersion in
        return ChatExportVersion(date: version._asMessage().archivedVersionCapturedAt ?? version.timestamp, text: version.text)
    }

    return ChatExportMessage(
        id: originalId.id,
        date: message.timestamp,
        editDate: editDate,
        fromName: author.flatMap { $0.displayTitle(strings: strings, displayOrder: nameDisplayOrder) },
        fromId: author.flatMap(chatExportPeerId),
        isOutgoing: !message.effectivelyIncoming(accountPeerId),
        parts: chatExportTextParts(text: message.text, entities: entities),
        mediaType: media?.0,
        fileName: media?.1,
        replyToMessageId: replyToMessageId,
        forwardedFrom: forwardedFrom,
        isDeleted: isDeleted,
        editHistory: editHistory
    )
}

private func fetchAllMessages(context: AccountContext, peerId: EnginePeer.Id, progress: @escaping (Int, Int) -> Void) -> Signal<[EngineMessage], NoError> {
    func page(state: SearchMessagesState?, collected: [EngineMessage.Id: EngineMessage]) -> Signal<[EngineMessage], NoError> {
        return context.engine.messages.searchMessages(location: .peer(peerId: peerId, fromId: nil, tags: nil, reactions: nil, threadId: nil, minDate: nil, maxDate: nil), query: "", state: state, limit: 100)
        |> take(1)
        |> mapToSignal { result, nextState -> Signal<[EngineMessage], NoError> in
            var collected = collected
            let previousCount = collected.count
            for message in result.messages {
                collected[message.id] = EngineMessage(message)
            }
            progress(collected.count, max(Int(result.totalCount), collected.count))
            if result.completed || collected.count == previousCount {
                return .single(Array(collected.values))
            }
            return page(state: nextState, collected: collected)
        }
    }
    return page(state: nil, collected: [:])
}

extension PeerInfoScreenNode {
    func openChatExport() {
        guard let controller = self.controller, let peer = self.data?.chatPeer ?? self.data?.peer else {
            return
        }
        let presentationData = self.presentationData
        if MadChatLockSession.shared.isLocked(peerId: peer.id.toInt64()) {
            MadLock.unlockChat(peerId: peer.id.toInt64(), strings: presentationData.strings, completion: { [weak self] success in
                if success {
                    self?.openChatExport()
                }
            })
            return
        }
        let extras = presentationData.strings.localFeatures.extras
        let sheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = [ActionSheetTextItem(title: extras.exportFormatTitle)]
        for (format, title) in [(ChatExportFormat.text, extras.exportFormatText), (.json, extras.exportFormatJson), (.html, extras.exportFormatHtml)] {
            items.append(ActionSheetButtonItem(title: title, action: { [weak self, weak sheet] in
                sheet?.dismissAnimated()
                self?.runChatExport(peer: peer, format: format)
            }))
        }
        sheet.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak sheet] in
                    sheet?.dismissAnimated()
                })
            ])
        ])
        controller.present(sheet, in: .window(.root))
    }

    private func runChatExport(peer: EnginePeer, format: ChatExportFormat) {
        guard let controller = self.controller else {
            return
        }
        let context = self.context
        let presentationData = self.presentationData
        let extras = presentationData.strings.localFeatures.extras
        let peerId = peer.id

        let disposable = MetaDisposable()
        let statusController = StorageUsageProgressOverlayController(presentationData: presentationData, description: extras.exportKeepOpen)
        controller.present(statusController, in: .window(.root))
        let idleTimer = context.sharedContext.applicationBindings.pushIdleTimerExtension()
        let reportProgress: (Float) -> Void = { [weak statusController] value in
            Queue.mainQueue().async {
                statusController?.setProgress(value)
            }
        }
        reportProgress(0.01)

        let signal: Signal<Data?, NoError> = combineLatest(
            fetchAllMessages(context: context, peerId: peerId, progress: { current, total in
                reportProgress(max(0.01, min(0.9, Float(current) / Float(max(1, total)) * 0.9)))
            }),
            context.engine.messages.chatExportArchivedContent(peerId: peerId)
        )
        |> map { messages, archived -> Data? in
            reportProgress(0.95)
            var all = messages
            all.append(contentsOf: archived.deletedMessages)
            let exported = all.compactMap {
                chatExportMessage($0, accountPeerId: context.account.peerId, versions: archived.versions, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder)
            }.sorted(by: { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }
                return lhs.id < rhs.id
            })
            if exported.isEmpty {
                return nil
            }
            let chat = ChatExportChat(
                name: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder),
                type: chatExportChatType(peer),
                id: peerId.id._internalGetInt64Value(),
                messages: exported
            )
            let labels = ChatExportLabels(
                deleted: extras.exportLabelDeleted,
                edited: extras.exportLabelEdited,
                editHistory: extras.exportLabelEditHistory,
                media: extras.exportLabelMedia,
                reply: extras.exportLabelReply,
                forwarded: extras.exportLabelForwarded
            )
            return ChatExportRenderer(labels: labels).render(chat, format: format)
        }
        |> runOn(Queue.concurrentDefaultQueue())
        |> deliverOnMainQueue

        disposable.set(signal.start(next: { [weak self, weak statusController] (data: Data?) in
            idleTimer.dispose()
            statusController?.setProgress(1.0)
            Queue.mainQueue().after(0.5) {
                statusController?.dismiss()
            }
            guard let self, let controller = self.controller else {
                return
            }
            guard let data else {
                controller.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: extras.exportEmpty, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                return
            }
            let safeName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                .components(separatedBy: CharacterSet(charactersIn: "/\\\\?%*|\"<>:"))
                .joined(separator: "_")
            let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("chat-export-\(Int64.random(in: 1 ..< Int64.max))", isDirectory: true)
            let fileUrl = directory.appendingPathComponent("\(safeName.isEmpty ? "chat" : safeName).\(format.fileExtension)")
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try data.write(to: fileUrl, options: [.atomic, .completeFileProtection])
            } catch {
                controller.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: extras.exportFailed, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
                return
            }
            let activityController = UIActivityViewController(activityItems: [fileUrl], applicationActivities: nil)
            activityController.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: directory)
            }
            if let popover = activityController.popoverPresentationController {
                popover.sourceView = controller.view
                popover.sourceRect = CGRect(origin: CGPoint(x: controller.view.bounds.midX, y: controller.view.bounds.midY), size: CGSize())
                popover.permittedArrowDirections = []
            }
            context.sharedContext.applicationBindings.presentNativeController(activityController)
        }))
    }
}
