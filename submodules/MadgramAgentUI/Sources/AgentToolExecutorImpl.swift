import Foundation
import MadgramText
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import LocalizedPeerData
import MadgramAgent
import ChatInterfaceState
import ConvertOpusToAAC
import LocalAudioTranscription
import TelegramUIPreferences

private func agentFirstValue<T>(_ signal: Signal<T, NoError>) async -> T? {
    return await withCheckedContinuation { continuation in
        let resumed = Atomic<Bool>(value: false)
        let disposable = MetaDisposable()
        disposable.set((signal |> take(1)).start(next: { value in
            if !resumed.swap(true) {
                continuation.resume(returning: value)
            }
        }, completed: {
            if !resumed.swap(true) {
                continuation.resume(returning: nil)
            }
        }))
    }
}

struct AgentPendingSend: Equatable {
    let id: String
    let chatTitle: String
    let text: String
    var title: String? = nil
}

@MainActor
final class AgentToolExecutorImpl: AgentToolExecutor {
    private let context: AccountContext
    private var strings: AgentStrings
    private var titles: [Int64: String] = [:]
    private var pendingConfirmation: (AgentPendingSend, CheckedContinuation<Bool, Never>)?
    private var hasReadChats = false

    var pendingSendUpdated: ((AgentPendingSend?) -> Void)?

    init(context: AccountContext, strings: AgentStrings) {
        self.context = context
        self.strings = strings
    }

    var pendingSend: AgentPendingSend? {
        return self.pendingConfirmation?.0
    }

    func resolvePendingSend(_ approved: Bool) {
        guard let (_, continuation) = self.pendingConfirmation else {
            return
        }
        self.pendingConfirmation = nil
        self.pendingSendUpdated?(nil)
        continuation.resume(returning: approved)
    }

    func cancelPendingSend() {
        self.resolvePendingSend(false)
    }

    private func confirm(_ pending: AgentPendingSend) async -> Bool {
        self.cancelPendingSend()
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            self.pendingConfirmation = (pending, continuation)
            self.pendingSendUpdated?(pending)
        }
    }

    private func isLockedChat(_ peerId: EnginePeer.Id) -> Bool {
        return MadChatLockSession.shared.isLocked(peerId: peerId.toInt64())
    }

    private var presentationData: PresentationData {
        return self.context.sharedContext.currentPresentationData.with { $0 }
    }

    private func title(_ peer: EnginePeer) -> String {
        let presentationData = self.presentationData
        if peer.id == self.context.account.peerId {
            return presentationData.strings.DialogList_SavedMessages
        }
        let title = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        self.titles[peer.id.toInt64()] = title
        return title
    }

    private func kind(_ peer: EnginePeer) -> String {
        switch peer {
        case let .user(user):
            return user.botInfo != nil ? "bot" : "private"
        case .legacyGroup:
            return "group"
        case let .channel(channel):
            if case .broadcast = channel.info {
                return "channel"
            }
            return "group"
        case .secretChat:
            return "secret"
        case .community:
            return "community"
        }
    }

    private func chatId(_ value: Any?) -> EnginePeer.Id? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespaces)
            if let number = Int64(trimmed) {
                return EnginePeer.Id(number)
            }
            return nil
        }
        if let number = value as? NSNumber {
            return EnginePeer.Id(number.int64Value)
        }
        return nil
    }

    func runningTitle(for call: AgentToolCall) -> String {
        let arguments = call.argumentsObject
        switch call.name {
        case AgentToolName.listChats:
            return arguments["unread_only"] as? Bool == true ? self.strings.toolListUnread : self.strings.toolListChats
        case AgentToolName.searchChats:
            return self.strings.toolSearch(arguments["query"] as? String ?? "")
        case AgentToolName.readChat:
            let title = self.chatId(arguments["chat_id"]).flatMap { self.titles[$0.toInt64()] } ?? self.strings.unknownChat
            return self.strings.toolRead(title)
        case AgentToolName.sendMessage:
            let title = self.chatId(arguments["chat_id"]).flatMap { self.titles[$0.toInt64()] } ?? self.strings.unknownChat
            return self.strings.toolSending(title)
        case AgentToolName.setAutoReply:
            let title = self.chatId(arguments["chat_id"]).flatMap { self.titles[$0.toInt64()] } ?? self.strings.unknownChat
            return arguments["enabled"] as? Bool == false ? self.strings.autoReplyOff(title) : self.strings.autoReplyOn(title)
        case AgentToolName.searchMessages:
            return self.strings.toolSearchMessages(arguments["query"] as? String ?? "")
        case AgentToolName.chatAction:
            let title = self.chatId(arguments["chat_id"]).flatMap { self.titles[$0.toInt64()] } ?? self.strings.unknownChat
            return self.strings.toolChatAction(title)
        case AgentToolName.forwardMessages:
            let title = self.chatId(arguments["to_chat_id"]).flatMap { self.titles[$0.toInt64()] } ?? self.strings.unknownChat
            return self.strings.toolForward(title)
        case AgentToolName.scheduleMessage:
            let title = self.chatId(arguments["chat_id"]).flatMap { self.titles[$0.toInt64()] } ?? self.strings.unknownChat
            return self.strings.toolSchedule(title)
        case AgentToolName.remind:
            return self.strings.toolRemind
        case AgentToolName.draftReply:
            let title = self.chatId(arguments["chat_id"]).flatMap { self.titles[$0.toInt64()] } ?? self.strings.unknownChat
            return self.strings.toolDraft(title)
        case AgentToolName.transcribe:
            return self.strings.toolTranscribe
        case AgentToolName.viewPhoto:
            return self.strings.toolViewPhoto
        case AgentWeb.searchToolName:
            return self.strings.toolWebSearch(arguments["query"] as? String ?? "")
        case AgentWeb.fetchToolName:
            return self.strings.toolWebFetch(URL(string: arguments["url"] as? String ?? "")?.host ?? "")
        default:
            return call.name
        }
    }

    func execute(_ call: AgentToolCall) async -> AgentToolOutcome {
        let arguments = call.argumentsObject
        let settings = AgentSettingsStore.shared.current
        for key in ["chat_id", "from_chat_id", "to_chat_id"] {
            if let peerId = self.chatId(arguments[key]), self.isLockedChat(peerId) {
                return AgentToolOutcome(content: "Чат закрыт паролем, агенту он недоступен.", title: self.runningTitle(for: call), isError: true)
            }
        }
        if [AgentToolName.listChats, AgentToolName.readChat, AgentToolName.searchMessages, AgentToolName.transcribe, AgentToolName.viewPhoto].contains(call.name) {
            self.hasReadChats = true
        }
        switch call.name {
        case AgentToolName.listChats:
            guard settings.allowReadChats || settings.allowSendMessages else {
                return AgentToolOutcome(content: "Доступ к чатам выключен в настройках.", title: self.runningTitle(for: call), isError: true)
            }
            return await self.listChats(limit: arguments["limit"] as? Int ?? 30, unreadOnly: arguments["unread_only"] as? Bool ?? false, title: self.runningTitle(for: call))
        case AgentToolName.searchChats:
            guard settings.allowReadChats || settings.allowSendMessages else {
                return AgentToolOutcome(content: "Доступ к чатам выключен в настройках.", title: self.runningTitle(for: call), isError: true)
            }
            return await self.searchChats(query: arguments["query"] as? String ?? "", title: self.runningTitle(for: call))
        case AgentToolName.readChat:
            guard settings.allowReadChats else {
                return AgentToolOutcome(content: "Чтение чатов выключено в настройках.", title: self.runningTitle(for: call), isError: true)
            }
            guard let peerId = self.chatId(arguments["chat_id"]) else {
                return AgentToolOutcome(content: "Нужен chat_id из list_chats или search_chats.", title: self.runningTitle(for: call), isError: true)
            }
            if let fromString = arguments["from_date"] as? String, let from = self.parseDay(fromString) {
                let to = (arguments["to_date"] as? String).flatMap { self.parseDay($0) }.map { $0.addingTimeInterval(86400.0) } ?? Date()
                return await self.readPeriod(peerId: peerId, from: from, to: to)
            }
            return await self.readChat(peerId: peerId, limit: arguments["limit"] as? Int ?? 60)
        case AgentToolName.sendMessage:
            guard settings.allowSendMessages else {
                return AgentToolOutcome(content: "Отправка сообщений выключена в настройках.", title: self.runningTitle(for: call), isError: true)
            }
            guard let peerId = self.chatId(arguments["chat_id"]) else {
                return AgentToolOutcome(content: "Нужен chat_id из list_chats или search_chats.", title: self.runningTitle(for: call), isError: true)
            }
            let text = (arguments["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return AgentToolOutcome(content: "Пустой текст.", title: self.runningTitle(for: call), isError: true)
            }
            return await self.sendMessage(peerId: peerId, text: text, callId: call.id)
        case AgentToolName.setAutoReply:
            guard settings.allowSendMessages else {
                return AgentToolOutcome(content: "Отправка сообщений выключена в настройках, автоответчик недоступен.", title: self.runningTitle(for: call), isError: true)
            }
            guard let peerId = self.chatId(arguments["chat_id"]) else {
                return AgentToolOutcome(content: "Нужен chat_id из list_chats или search_chats.", title: self.runningTitle(for: call), isError: true)
            }
            let enabled = arguments["enabled"] as? Bool ?? true
            let scenario = (arguments["scenario"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return await self.setAutoReply(peerId: peerId, enabled: enabled, scenario: scenario, callId: call.id)
        case AgentToolName.searchMessages:
            guard settings.allowReadChats else {
                return AgentToolOutcome(content: "Чтение чатов выключено в настройках.", title: self.runningTitle(for: call), isError: true)
            }
            if let peerId = self.chatId(arguments["chat_id"]) {
                return await self.searchWithContext(peerId: peerId, query: arguments["query"] as? String ?? "", title: self.runningTitle(for: call))
            }
            return await self.searchMessages(query: arguments["query"] as? String ?? "", peerId: nil, limit: arguments["limit"] as? Int ?? 20, title: self.runningTitle(for: call))
        case AgentToolName.transcribe:
            guard settings.allowReadChats, let peerId = self.chatId(arguments["chat_id"]), let messageId = (arguments["message_id"] as? NSNumber)?.int32Value else {
                return AgentToolOutcome(content: "Нужны chat_id и message_id.", title: self.runningTitle(for: call), isError: true)
            }
            return await self.transcribe(peerId: peerId, messageId: messageId)
        case AgentToolName.chatAction:
            guard settings.allowChatActions else {
                return AgentToolOutcome(content: "Действия с чатами выключены в настройках.", title: self.runningTitle(for: call), isError: true)
            }
            guard let peerId = self.chatId(arguments["chat_id"]), let action = arguments["action"] as? String else {
                return AgentToolOutcome(content: "Нужны chat_id и action.", title: self.runningTitle(for: call), isError: true)
            }
            return await self.chatAction(peerId: peerId, action: action)
        case AgentToolName.forwardMessages:
            guard settings.allowForwarding else {
                return AgentToolOutcome(content: "Пересылка выключена в настройках.", title: self.runningTitle(for: call), isError: true)
            }
            guard let from = self.chatId(arguments["from_chat_id"]), let to = self.chatId(arguments["to_chat_id"]), let ids = arguments["message_ids"] as? [Any] else {
                return AgentToolOutcome(content: "Нужны from_chat_id, message_ids и to_chat_id.", title: self.runningTitle(for: call), isError: true)
            }
            let messageIds = ids.compactMap { ($0 as? NSNumber)?.int32Value }
            return await self.forward(from: from, ids: messageIds, to: to, callId: call.id)
        case AgentToolName.scheduleMessage:
            guard settings.allowSendMessages else {
                return AgentToolOutcome(content: "Отправка сообщений выключена в настройках.", title: self.runningTitle(for: call), isError: true)
            }
            guard let peerId = self.chatId(arguments["chat_id"]) else {
                return AgentToolOutcome(content: "Нужен chat_id.", title: self.runningTitle(for: call), isError: true)
            }
            let text = (arguments["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, let date = self.parseTime(arguments["send_at"] as? String, minutes: arguments["in_minutes"] as? Int) else {
                return AgentToolOutcome(content: "Нужны текст и время: send_at (YYYY-MM-DD HH:MM) или in_minutes, в будущем.", title: self.runningTitle(for: call), isError: true)
            }
            return await self.sendMessage(peerId: peerId, text: text, callId: call.id, scheduleAt: date)
        case AgentToolName.remind:
            let text = (arguments["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, let date = self.parseTime(arguments["remind_at"] as? String, minutes: arguments["in_minutes"] as? Int) else {
                return AgentToolOutcome(content: "Нужны текст и время: remind_at (YYYY-MM-DD HH:MM) или in_minutes, в будущем.", title: self.runningTitle(for: call), isError: true)
            }
            return await self.remind(text: text, at: date)
        case AgentToolName.draftReply:
            guard settings.allowSendMessages || settings.allowReadChats else {
                return AgentToolOutcome(content: "Доступ к чатам выключен в настройках.", title: self.runningTitle(for: call), isError: true)
            }
            guard let peerId = self.chatId(arguments["chat_id"]) else {
                return AgentToolOutcome(content: "Нужен chat_id.", title: self.runningTitle(for: call), isError: true)
            }
            return await self.draft(peerId: peerId, text: arguments["text"] as? String ?? "")
        case AgentToolName.viewPhoto:
            guard settings.allowReadChats, let peerId = self.chatId(arguments["chat_id"]), let messageId = (arguments["message_id"] as? NSNumber)?.int32Value else {
                return AgentToolOutcome(content: "Нужны chat_id и message_id.", title: self.runningTitle(for: call), isError: true)
            }
            return await self.viewPhoto(peerId: peerId, messageId: messageId)
        case AgentWeb.searchToolName:
            let (content, isError) = await AgentWeb.search(arguments["query"] as? String ?? "")
            return AgentToolOutcome(content: content, title: self.runningTitle(for: call), isError: isError)
        case AgentWeb.fetchToolName:
            let urlString = arguments["url"] as? String ?? ""
            if self.hasReadChats && !settings.sendWithoutConfirmation {
                let host = URL(string: urlString)?.host ?? urlString
                guard await self.confirm(AgentPendingSend(id: call.id, chatTitle: host, text: urlString)) else {
                    return AgentToolOutcome(content: self.strings.sendDeclined, title: self.runningTitle(for: call), isError: true)
                }
            }
            let (content, isError) = await AgentWeb.fetch(urlString)
            return AgentToolOutcome(content: content, title: self.runningTitle(for: call), isError: isError)
        default:
            return AgentToolOutcome(content: "Неизвестный инструмент \(call.name).", title: call.name, isError: true)
        }
    }

    private func previewText(_ message: EngineMessage) -> String {
        var text = message.text.replacingOccurrences(of: "\n", with: " ")
        if text.isEmpty {
            text = AgentToolExecutorImpl.mediaDescription(message) ?? ""
        }
        if text.count > 120 {
            text = String(text.prefix(120)) + "…"
        }
        return text
    }

    nonisolated static func mediaDescription(_ message: EngineMessage) -> String? {
        for media in message.media {
            if media is TelegramMediaImage {
                return "[фото]"
            } else if let file = media as? TelegramMediaFile {
                if file.isInstantVideo {
                    return "[видеосообщение]"
                } else if file.isVoice {
                    return "[голосовое]"
                } else if file.isSticker || file.isAnimatedSticker || file.isVideoSticker {
                    return "[стикер]"
                } else if file.isAnimated {
                    return "[GIF]"
                } else if file.isVideo {
                    return "[видео]"
                } else if file.isMusic {
                    return "[аудио\(file.fileName.flatMap { " \($0)" } ?? "")]"
                } else {
                    return "[файл\(file.fileName.flatMap { " \($0)" } ?? "")]"
                }
            } else if let poll = media as? TelegramMediaPoll {
                return "[опрос: \(poll.text)]"
            } else if media is TelegramMediaContact {
                return "[контакт]"
            } else if media is TelegramMediaMap {
                return "[геопозиция]"
            } else if media is TelegramMediaAction {
                return "[служебное сообщение]"
            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                return "[ссылка: \(content.title ?? content.url)]"
            }
        }
        return nil
    }

    private func listChats(limit: Int, unreadOnly: Bool, title: String) async -> AgentToolOutcome {
        let limit = max(1, min(100, limit))
        guard let chatList = await agentFirstValue(self.context.engine.messages.chatList(group: .root, count: unreadOnly ? 200 : limit + 10)) else {
            return AgentToolOutcome(content: "Не удалось получить список чатов.", title: title, isError: true)
        }
        var lines: [String] = []
        for item in chatList.items.sorted(by: { $0.index > $1.index }) {
            guard case .chatList = item.id, let peer = item.renderedPeer.peer else {
                continue
            }
            if case .secretChat = peer {
                continue
            }
            if self.isLockedChat(peer.id) {
                continue
            }
            let unread = Int(item.readCounters?.count ?? 0)
            let markedUnread = item.readCounters?.markedUnread ?? false
            if unreadOnly && unread == 0 && !markedUnread {
                continue
            }
            var line = "chat_id=\(peer.id.toInt64()) | \(self.title(peer)) | \(self.kind(peer))"
            if unread > 0 {
                line += " | непрочитано: \(unread)"
            } else if markedUnread {
                line += " | отмечен непрочитанным"
            }
            if item.isMuted {
                line += " | без звука"
            }
            if let message = item.messages.last {
                let author = message.author.flatMap { $0.id == self.context.account.peerId ? "Я" : self.title($0) }
                line += " | последнее: \(author.flatMap { "\($0): " } ?? "")\(self.previewText(message))"
            }
            lines.append(line)
            if lines.count >= limit {
                break
            }
        }
        if lines.isEmpty {
            return AgentToolOutcome(content: unreadOnly ? "Непрочитанных чатов нет." : "Чатов нет.", title: title)
        }
        return AgentToolOutcome(content: lines.joined(separator: "\n"), title: title)
    }

    private func searchChats(query: String, title: String) async -> AgentToolOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AgentToolOutcome(content: "Пустой запрос.", title: title, isError: true)
        }
        let peers = await agentFirstValue(self.context.engine.contacts.searchLocalPeers(query: trimmed)) ?? []
        var lines: [String] = []
        var seen = Set<Int64>()
        for rendered in peers {
            guard let peer = rendered.peer, !seen.contains(peer.id.toInt64()) else {
                continue
            }
            if case .secretChat = peer {
                continue
            }
            if self.isLockedChat(peer.id) {
                continue
            }
            seen.insert(peer.id.toInt64())
            var line = "chat_id=\(peer.id.toInt64()) | \(self.title(peer)) | \(self.kind(peer))"
            if let username = peer.addressName {
                line += " | @\(username)"
            }
            lines.append(line)
            if lines.count >= 20 {
                break
            }
        }
        if lines.isEmpty {
            return AgentToolOutcome(content: "Ничего не нашлось по «\(trimmed)».", title: title)
        }
        return AgentToolOutcome(content: lines.joined(separator: "\n"), title: title)
    }

    private func resolvePeer(_ peerId: EnginePeer.Id) async -> EnginePeer? {
        return await agentFirstValue(self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))) ?? nil
    }

    private func readChat(peerId: EnginePeer.Id, limit: Int) async -> AgentToolOutcome {
        let limit = max(1, min(300, limit))
        guard let peer = await self.resolvePeer(peerId) else {
            return AgentToolOutcome(content: "Чат \(peerId.toInt64()) не найден. Возьми chat_id из list_chats или search_chats.", title: self.strings.toolRead(self.strings.unknownChat), isError: true)
        }
        if case .secretChat = peer {
            return AgentToolOutcome(content: "Секретные чаты агенту недоступны.", title: self.strings.toolRead(self.strings.unknownChat), isError: true)
        }
        let chatTitle = self.title(peer)
        var collected: [EngineMessage] = []
        var state: SearchMessagesState?
        for _ in 0 ..< 4 {
            let page = await agentFirstValue(self.context.engine.messages.searchMessages(location: .peer(peerId: peerId, fromId: nil, tags: nil, reactions: nil, threadId: nil, minDate: nil, maxDate: nil), query: "", state: state, limit: Int32(min(100, limit - collected.count))))
            guard let (result, nextState) = page else {
                break
            }
            let previous = collected.count
            for message in result.messages {
                if !collected.contains(where: { $0.id == message.id }) {
                    collected.append(EngineMessage(message))
                }
            }
            state = nextState
            if result.completed || collected.count >= limit || collected.count == previous {
                break
            }
        }
        let messages = collected.sorted(by: { $0.index < $1.index }).suffix(limit)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yy HH:mm"
        var lines: [String] = ["Чат «\(chatTitle)» (\(self.kind(peer))), последние \(messages.count) сообщений, от старых к новым:"]
        var total = 0
        for message in messages {
            let author: String
            if let messageAuthor = message.author {
                author = messageAuthor.id == self.context.account.peerId ? "Я" : self.title(messageAuthor)
            } else {
                author = chatTitle
            }
            var text = message.text
            if text.count > 2000 {
                text = String(text.prefix(2000)) + "…"
            }
            if let media = AgentToolExecutorImpl.mediaDescription(message) {
                text = text.isEmpty ? media : "\(media) \(text)"
            }
            if message.forwardInfo != nil {
                text = "[пересланное] " + text
            }
            let line = "#\(message.id.id) [\(formatter.string(from: Date(timeIntervalSince1970: TimeInterval(message.timestamp))))] \(author): \(text)"
            total += line.count
            lines.append(line)
            if total > 60000 {
                lines.append("…дальше обрезано по объёму.")
                break
            }
        }
        if messages.isEmpty {
            lines.append("Сообщений нет.")
        }
        return AgentToolOutcome(content: lines.joined(separator: "\n"), title: self.strings.toolReadDone(chatTitle, messages.count))
    }

    private func sendMessage(peerId: EnginePeer.Id, text: String, callId: String, scheduleAt: Date? = nil) async -> AgentToolOutcome {
        guard let peer = await self.resolvePeer(peerId) else {
            return AgentToolOutcome(content: "Чат \(peerId.toInt64()) не найден.", title: self.strings.toolSending(self.strings.unknownChat), isError: true)
        }
        if case .secretChat = peer {
            return AgentToolOutcome(content: "В секретные чаты агент не пишет.", title: self.strings.toolSending(self.strings.unknownChat), isError: true)
        }
        let chatTitle = self.title(peer)
        var approved = true
        if !AgentSettingsStore.shared.current.sendWithoutConfirmation {
            approved = await self.confirm(AgentPendingSend(id: callId, chatTitle: chatTitle, text: text))
        }
        guard approved else {
            return AgentToolOutcome(content: self.strings.sendDeclined, title: self.strings.toolSending(chatTitle), isError: true)
        }
        let formatted = MadMarkdown.parse(text)
        let formattedAttributes: [EngineMessage.Attribute] = formatted.entities.isEmpty ? [] : [TextEntitiesMessageAttribute(entities: formatted.entities)]
        if let scheduleAt {
            let _ = await agentFirstValue(enqueueMessages(account: self.context.account, peerId: peerId, messages: [
                .message(text: formatted.text, attributes: formattedAttributes + [OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(scheduleAt.timeIntervalSince1970), repeatPeriod: nil)], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
            ]))
            let when = self.formatTime(scheduleAt)
            return AgentToolOutcome(content: "Запланировано в «\(chatTitle)» на \(when).", title: self.strings.scheduled(chatTitle, when))
        }
        let _ = await agentFirstValue(enqueueMessages(account: self.context.account, peerId: peerId, messages: [
            .message(text: formatted.text, attributes: formattedAttributes, inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
        ]))
        return AgentToolOutcome(content: "Отправлено в «\(chatTitle)».", title: self.strings.sent(chatTitle))
    }

    private func setAutoReply(peerId: EnginePeer.Id, enabled: Bool, scenario: String, callId: String) async -> AgentToolOutcome {
        guard let peer = await self.resolvePeer(peerId) else {
            return AgentToolOutcome(content: "Чат \(peerId.toInt64()) не найден.", title: self.strings.autoReplyOn(self.strings.unknownChat), isError: true)
        }
        let chatTitle = self.title(peer)
        guard case let .user(user) = peer, user.botInfo == nil, peer.id != self.context.account.peerId else {
            return AgentToolOutcome(content: "Автоответчик работает только в личке с человеком.", title: self.strings.autoReplyOn(chatTitle), isError: true)
        }
        if enabled && scenario.isEmpty {
            return AgentToolOutcome(content: "Нужен сценарий: как общаться и чего добиться.", title: self.strings.autoReplyOn(chatTitle), isError: true)
        }
        if enabled {
            let shownScenario = scenario.isEmpty ? (AgentSettingsStore.shared.current.autoReply(peerId: peerId.toInt64())?.scenario ?? "") : scenario
            guard await self.confirm(AgentPendingSend(id: callId, chatTitle: chatTitle, text: shownScenario, title: self.strings.autoReplyOn(chatTitle) + "?")) else {
                return AgentToolOutcome(content: self.strings.sendDeclined, title: self.strings.autoReplyOn(chatTitle), isError: true)
            }
        }
        AgentSettingsStore.shared.update { settings in
            var entry = settings.autoReply(peerId: peerId.toInt64()) ?? AgentAutoReply(peerId: peerId.toInt64(), title: chatTitle, scenario: scenario, isEnabled: enabled)
            entry.title = chatTitle
            entry.isEnabled = enabled
            if !scenario.isEmpty {
                entry.scenario = scenario
            }
            settings.setAutoReply(entry)
        }
        if enabled {
            return AgentToolOutcome(content: "Автоответчик включён для «\(chatTitle)». Он отвечает на новые сообщения, пока приложение открыто или живо в фоне.", title: self.strings.autoReplyOn(chatTitle))
        } else {
            return AgentToolOutcome(content: "Автоответчик для «\(chatTitle)» выключен.", title: self.strings.autoReplyOff(chatTitle))
        }
    }

    private func parseTime(_ value: String?, minutes: Int?) -> Date? {
        if let minutes, minutes > 0 {
            return Date().addingTimeInterval(TimeInterval(minutes) * 60.0)
        }
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else {
            return nil
        }
        for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            if let date = formatter.date(from: value), date.timeIntervalSinceNow > 30.0 {
                return date
            }
        }
        return nil
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM HH:mm"
        return formatter.string(from: date)
    }

    func viewPhoto(peerId: EnginePeer.Id, messageId: Int32) async -> AgentToolOutcome {
        let id = EngineMessage.Id(peerId: peerId, namespace: Namespaces.Message.Cloud, id: messageId)
        guard let message = await agentFirstValue(self.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: id))) ?? nil else {
            return AgentToolOutcome(content: "Сообщение не найдено.", title: self.strings.toolViewPhoto, isError: true)
        }
        if let peer = await self.resolvePeer(peerId), case .secretChat = peer {
            return AgentToolOutcome(content: "Секретные чаты агенту недоступны.", title: self.strings.toolViewPhoto, isError: true)
        }
        guard AgentImageLoader.hasPhoto(message) else {
            return AgentToolOutcome(content: "В этом сообщении нет фото.", title: self.strings.toolViewPhoto, isError: true)
        }
        guard let image = await AgentImageLoader.load(context: self.context, message: message) else {
            return AgentToolOutcome(content: "Фото не загрузилось.", title: self.strings.toolViewPhoto, isError: true)
        }
        let caption = message.text.isEmpty ? "" : " Подпись: \(message.text)"
        return AgentToolOutcome(content: "Фото из сообщения #\(messageId).\(caption)", title: self.strings.toolViewPhotoDone, images: [image])
    }

    func searchMessages(query: String, peerId: EnginePeer.Id?, limit: Int, title: String) async -> AgentToolOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AgentToolOutcome(content: "Пустой запрос.", title: title, isError: true)
        }
        let limit = max(1, min(50, limit))
        let location: SearchMessagesLocation
        if let peerId {
            location = .peer(peerId: peerId, fromId: nil, tags: nil, reactions: nil, threadId: nil, minDate: nil, maxDate: nil)
        } else {
            location = .general(scope: .everywhere, groupId: nil, tags: nil, minDate: nil, maxDate: nil, folderId: nil, communityId: nil)
        }
        guard let (result, _) = await agentFirstValue(self.context.engine.messages.searchMessages(location: location, query: trimmed, state: nil, limit: Int32(limit))) else {
            return AgentToolOutcome(content: "Поиск не удался.", title: title, isError: true)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yy HH:mm"
        var lines: [String] = []
        for raw in result.messages.prefix(limit) {
            let message = EngineMessage(raw)
            if let peer = message.peers[message.id.peerId].flatMap(EnginePeer.init), case .secretChat = peer {
                continue
            }
            if self.isLockedChat(message.id.peerId) {
                continue
            }
            let chatTitle = message.peers[message.id.peerId].flatMap { self.title(EnginePeer($0)) } ?? self.strings.unknownChat
            let author = message.author.flatMap { $0.id == self.context.account.peerId ? "Я" : self.title($0) } ?? chatTitle
            var text = message.text
            if text.count > 400 {
                text = String(text.prefix(400)) + "…"
            }
            if let media = AgentToolExecutorImpl.mediaDescription(message) {
                text = text.isEmpty ? media : "\(media) \(text)"
            }
            lines.append("chat_id=\(message.id.peerId.toInt64()) «\(chatTitle)» #\(message.id.id) [\(formatter.string(from: Date(timeIntervalSince1970: TimeInterval(message.timestamp))))] \(author): \(text)")
        }
        if lines.isEmpty {
            return AgentToolOutcome(content: "Ничего не нашлось по «\(trimmed)».", title: title)
        }
        return AgentToolOutcome(content: lines.joined(separator: "\n"), title: self.strings.toolSearchMessagesDone(trimmed, lines.count))
    }

    private func chatAction(peerId: EnginePeer.Id, action: String) async -> AgentToolOutcome {
        guard let peer = await self.resolvePeer(peerId) else {
            return AgentToolOutcome(content: "Чат не найден.", title: self.strings.toolChatAction(self.strings.unknownChat), isError: true)
        }
        let chatTitle = self.title(peer)
        let engine = self.context.engine
        let done: String
        switch action {
        case "mark_read":
            let _ = await agentFirstValue(engine.messages.togglePeersUnreadMarkInteractively(peerIds: [peerId], setToValue: false) |> map { _ -> Void in } |> then(.single(Void())))
            done = "прочитан"
        case "mark_unread":
            let _ = await agentFirstValue(engine.messages.togglePeersUnreadMarkInteractively(peerIds: [peerId], setToValue: true) |> map { _ -> Void in } |> then(.single(Void())))
            done = "отмечен непрочитанным"
        case "mute":
            let _ = await agentFirstValue(engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: nil, muteInterval: Int32.max))
            done = "заглушён"
        case "unmute":
            let _ = await agentFirstValue(engine.peers.updatePeerMuteSetting(peerId: peerId, threadId: nil, muteInterval: 0))
            done = "звук включён"
        case "archive":
            let _ = await agentFirstValue(engine.peers.updatePeersGroupIdInteractively(peerIds: [peerId], groupId: .archive) |> map { _ -> Void in } |> then(.single(Void())))
            done = "в архиве"
        case "unarchive":
            let _ = await agentFirstValue(engine.peers.updatePeersGroupIdInteractively(peerIds: [peerId], groupId: .root) |> map { _ -> Void in } |> then(.single(Void())))
            done = "вынут из архива"
        case "pin", "unpin":
            var isPinned = false
            if let list = await agentFirstValue(engine.messages.chatList(group: .root, count: 300)) {
                for item in list.items {
                    if case let .chatList(itemPeerId) = item.id, itemPeerId == peerId, case let .chatList(index) = item.index {
                        isPinned = index.pinningIndex != nil
                    }
                }
            }
            if isPinned == (action == "pin") {
                done = action == "pin" ? "уже закреплён" : "и так не закреплён"
            } else {
                let result = await agentFirstValue(engine.peers.toggleItemPinned(location: .group(.root), itemId: .peer(peerId)))
                if case .limitExceeded = result {
                    return AgentToolOutcome(content: "Не закрепить: лимит закрепов.", title: self.strings.toolChatAction(chatTitle), isError: true)
                }
                done = action == "pin" ? "закреплён" : "откреплён"
            }
        default:
            return AgentToolOutcome(content: "Неизвестное действие \(action).", title: self.strings.toolChatAction(chatTitle), isError: true)
        }
        return AgentToolOutcome(content: "Чат «\(chatTitle)» \(done).", title: self.strings.toolChatActionDone(chatTitle, done))
    }

    private func forward(from: EnginePeer.Id, ids: [Int32], to: EnginePeer.Id, callId: String) async -> AgentToolOutcome {
        guard !ids.isEmpty else {
            return AgentToolOutcome(content: "Нет message_ids.", title: self.strings.toolForward(self.strings.unknownChat), isError: true)
        }
        guard let target = await self.resolvePeer(to) else {
            return AgentToolOutcome(content: "Чат назначения не найден.", title: self.strings.toolForward(self.strings.unknownChat), isError: true)
        }
        if case .secretChat = target {
            return AgentToolOutcome(content: "В секретные чаты агент не пересылает.", title: self.strings.toolForward(self.strings.unknownChat), isError: true)
        }
        let targetTitle = self.title(target)
        if !AgentSettingsStore.shared.current.sendWithoutConfirmation {
            let sourceTitle = await self.resolvePeer(from).flatMap { self.title($0) } ?? self.strings.unknownChat
            guard await self.confirm(AgentPendingSend(id: callId, chatTitle: targetTitle, text: "↪︎ \(min(ids.count, 100)) · «\(sourceTitle)»")) else {
                return AgentToolOutcome(content: self.strings.sendDeclined, title: self.strings.toolForward(targetTitle), isError: true)
            }
        }
        let messages: [EnqueueMessage] = ids.prefix(100).map { id in
            return .forward(source: EngineMessage.Id(peerId: from, namespace: Namespaces.Message.Cloud, id: id), threadId: nil, grouping: .auto, attributes: [], correlationId: nil)
        }
        let _ = await agentFirstValue(enqueueMessages(account: self.context.account, peerId: to, messages: messages))
        return AgentToolOutcome(content: "Переслано \(messages.count) в «\(targetTitle)».", title: self.strings.toolForwardDone(targetTitle, messages.count))
    }

    private func remind(text: String, at date: Date) async -> AgentToolOutcome {
        let accountPeerId = self.context.account.peerId
        let _ = await agentFirstValue(enqueueMessages(account: self.context.account, peerId: accountPeerId, messages: [
            .message(text: "⏰ " + text, attributes: [OutgoingScheduleInfoMessageAttribute(scheduleTime: Int32(date.timeIntervalSince1970), repeatPeriod: nil)], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
        ]))
        let when = self.formatTime(date)
        return AgentToolOutcome(content: "Напоминание придёт в избранное \(when).", title: self.strings.reminded(when))
    }

    private func draft(peerId: EnginePeer.Id, text: String) async -> AgentToolOutcome {
        guard let peer = await self.resolvePeer(peerId) else {
            return AgentToolOutcome(content: "Чат не найден.", title: self.strings.toolDraft(self.strings.unknownChat), isError: true)
        }
        let chatTitle = self.title(peer)
        let _ = await agentFirstValue(ChatInterfaceState.update(engine: self.context.engine, peerId: peerId, threadId: nil, { state in
            return state.withUpdatedComposeInputState(ChatTextInputState(inputText: NSAttributedString(string: text)))
        }) |> map { _ -> Void in } |> then(.single(Void())))
        return AgentToolOutcome(content: "Черновик лежит в поле ввода чата «\(chatTitle)». Пользователь отправит его сам.", title: self.strings.drafted(chatTitle))
    }

    func transcribe(peerId: EnginePeer.Id, messageId: Int32) async -> AgentToolOutcome {
        let id = EngineMessage.Id(peerId: peerId, namespace: Namespaces.Message.Cloud, id: messageId)
        guard let message = await agentFirstValue(self.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: id))) ?? nil else {
            return AgentToolOutcome(content: "Сообщение не найдено.", title: self.strings.toolTranscribe, isError: true)
        }
        guard let file = message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile, file.isVoice || file.isInstantVideo else {
            return AgentToolOutcome(content: "Это не голосовое и не кружок.", title: self.strings.toolTranscribe, isError: true)
        }
        if let existing = message.attributes.compactMap({ $0 as? AudioTranscriptionMessageAttribute }).first, !existing.isPending, !existing.text.isEmpty {
            return AgentToolOutcome(content: existing.text, title: self.strings.toolTranscribeDone)
        }
        let serverResult = await agentFirstValue(self.context.engine.messages.transcribeAudio(messageId: id))
        if case .success = serverResult, let updated = await agentFirstValue(self.context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: id))) ?? nil, let attribute = updated.attributes.compactMap({ $0 as? AudioTranscriptionMessageAttribute }).first, !attribute.text.isEmpty {
            return AgentToolOutcome(content: attribute.text, title: self.strings.toolTranscribeDone)
        }
        let _ = await agentFirstValue(freeMediaFileInteractiveFetched(account: self.context.account, userLocation: .peer(peerId), fileReference: .message(message: MessageReference(message._asMessage()), media: file)) |> map { _ -> Void in } |> `catch` { _ -> Signal<Void, NoError> in return .single(Void()) })
        guard let data = await agentFirstValue(self.context.engine.resources.data(id: EngineMediaResource.Id(file.resource.id)) |> filter { $0.isComplete }), data.isComplete else {
            return AgentToolOutcome(content: "Не удалось скачать аудио.", title: self.strings.toolTranscribe, isError: true)
        }
        guard let converted = await agentFirstValue(convertOpusToAAC(sourcePath: data.path, allocateTempFile: { return EngineTempBox.shared.tempFile(fileName: "agent-audio.m4a").path })) ?? nil else {
            return AgentToolOutcome(content: "Не удалось подготовить аудио.", title: self.strings.toolTranscribe, isError: true)
        }
        let presentationData = self.presentationData
        var text = ""
        let finalResult: LocallyTranscribedAudio? = await withCheckedContinuation { continuation in
            let resumed = Atomic<Bool>(value: false)
            let _ = (transcribeAudio(path: converted, appLocale: presentationData.strings.baseLanguageCode)
            |> filter { value in value.map { $0.isFinal } ?? true }
            |> take(1)).start(next: { value in
                if !resumed.swap(true) {
                    continuation.resume(returning: value)
                }
            }, completed: {
                if !resumed.swap(true) {
                    continuation.resume(returning: nil)
                }
            })
        }
        text = finalResult?.text ?? ""
        if text.isEmpty {
            return AgentToolOutcome(content: "Не удалось расшифровать: распознавание речи недоступно или ничего не разобрано.", title: self.strings.toolTranscribe, isError: true)
        }
        return AgentToolOutcome(content: text, title: self.strings.toolTranscribeDone)
    }

    func parseDay(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value.trimmingCharacters(in: .whitespaces))
    }

    private func line(for message: EngineMessage, chatTitle: String, maxLength: Int, mark: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yy HH:mm"
        let author: String
        if let messageAuthor = message.author {
            author = messageAuthor.id == self.context.account.peerId ? "Я" : self.title(messageAuthor)
        } else {
            author = chatTitle
        }
        var text = message.text
        if text.count > maxLength {
            text = String(text.prefix(maxLength)) + "…"
        }
        if let media = AgentToolExecutorImpl.mediaDescription(message) {
            text = text.isEmpty ? media : "\(media) \(text)"
        }
        if message.forwardInfo != nil {
            text = "[пересланное] " + text
        }
        return "\(mark ? "→ " : "")#\(message.id.id) [\(formatter.string(from: Date(timeIntervalSince1970: TimeInterval(message.timestamp))))] \(author): \(text)"
    }

    func searchWithContext(peerId: EnginePeer.Id, query: String, title: String) async -> AgentToolOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AgentToolOutcome(content: "Пустой запрос.", title: title, isError: true)
        }
        guard let peer = await self.resolvePeer(peerId) else {
            return AgentToolOutcome(content: "Чат не найден.", title: title, isError: true)
        }
        if case .secretChat = peer {
            return AgentToolOutcome(content: "Секретные чаты агенту недоступны.", title: title, isError: true)
        }
        let chatTitle = self.title(peer)
        guard let (result, _) = await agentFirstValue(self.context.engine.messages.searchMessages(location: .peer(peerId: peerId, fromId: nil, tags: nil, reactions: nil, threadId: nil, minDate: nil, maxDate: nil), query: trimmed, state: nil, limit: 30)) else {
            return AgentToolOutcome(content: "Поиск не удался.", title: title, isError: true)
        }
        let hits = result.messages.map(EngineMessage.init).sorted(by: { $0.index > $1.index })
        if hits.isEmpty {
            return AgentToolOutcome(content: "В чате «\(chatTitle)» ничего не нашлось по «\(trimmed)».", title: self.strings.toolSearchMessagesDone(trimmed, 0))
        }
        var blocks: [String] = []
        var covered = Set<Int32>()
        for hit in hits.prefix(6) {
            if covered.contains(hit.id.id) {
                continue
            }
            let around = await agentFirstValue(self.context.engine.messages.madHistoryAround(peerId: peerId, messageId: hit.id.id, before: 5, after: 5)) ?? []
            let messages = around.isEmpty ? [hit] : around
            var lines: [String] = []
            for message in messages {
                covered.insert(message.id.id)
                lines.append(self.line(for: message, chatTitle: chatTitle, maxLength: 600, mark: message.id == hit.id))
            }
            blocks.append(lines.joined(separator: "\n"))
        }
        var content = "Найдено \(hits.count) совпадений по «\(trimmed)» в «\(chatTitle)». Совпадение помечено →, вокруг по 5 сообщений.\n\n" + blocks.joined(separator: "\n———\n")
        if hits.count > 6 {
            content += "\n\nЕщё совпадения (без контекста):\n" + hits.dropFirst(6).prefix(20).map { self.line(for: $0, chatTitle: chatTitle, maxLength: 200) }.joined(separator: "\n")
        }
        return AgentToolOutcome(content: content, title: self.strings.toolSearchMessagesDone(trimmed, hits.count))
    }

    func readPeriod(peerId: EnginePeer.Id, from: Date, to: Date) async -> AgentToolOutcome {
        guard let peer = await self.resolvePeer(peerId) else {
            return AgentToolOutcome(content: "Чат не найден.", title: self.strings.toolReadPeriod(self.strings.unknownChat), isError: true)
        }
        if case .secretChat = peer {
            return AgentToolOutcome(content: "Секретные чаты агенту недоступны.", title: self.strings.toolReadPeriod(self.strings.unknownChat), isError: true)
        }
        let chatTitle = self.title(peer)
        let fromStamp = Int32(from.timeIntervalSince1970)
        var beforeDate = Int32(min(to, Date()).timeIntervalSince1970) + 1
        var collected: [EngineMessage] = []
        var seen = Set<Int32>()
        for _ in 0 ..< 8 {
            let page = await agentFirstValue(self.context.engine.messages.madHistoryPage(peerId: peerId, beforeDate: beforeDate, limit: 100)) ?? []
            var oldest: Int32?
            var added = 0
            for message in page where !seen.contains(message.id.id) {
                seen.insert(message.id.id)
                oldest = min(oldest ?? message.timestamp, message.timestamp)
                if message.timestamp >= fromStamp {
                    collected.append(message)
                    added += 1
                }
            }
            guard let oldest, oldest >= fromStamp, added > 0, collected.count < 600 else {
                break
            }
            beforeDate = oldest
        }
        collected.sort(by: { $0.index < $1.index })
        var lines: [String] = ["Чат «\(chatTitle)», \(collected.count) сообщений за период, от старых к новым:"]
        var total = 0
        for message in collected {
            let line = self.line(for: message, chatTitle: chatTitle, maxLength: 300)
            total += line.count
            if total > 70000 {
                lines.append("…дальше обрезано по объёму.")
                break
            }
            lines.append(line)
        }
        if collected.isEmpty {
            lines.append("Сообщений за этот период нет.")
        }
        return AgentToolOutcome(content: lines.joined(separator: "\n"), title: self.strings.toolReadPeriodDone(chatTitle, collected.count))
    }
}
