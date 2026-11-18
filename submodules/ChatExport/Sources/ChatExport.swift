import Foundation

public enum ChatExportFormat: String, CaseIterable {
    case text = "txt"
    case json = "json"
    case html = "html"

    public var fileExtension: String {
        return self.rawValue
    }

    public var mimeType: String {
        switch self {
        case .text:
            return "text/plain"
        case .json:
            return "application/json"
        case .html:
            return "text/html"
        }
    }
}

public struct ChatExportTextPart: Equatable {
    public enum Kind: Equatable {
        case plain
        case bold
        case italic
        case underline
        case strikethrough
        case code
        case pre(language: String?)
        case spoiler
        case link
        case textLink(url: String)
        case mention
        case mentionName(userId: Int64)
        case hashtag
        case cashtag
        case botCommand
        case email
        case phone
        case bankCard
        case blockquote
        case customEmoji(documentId: Int64)
    }

    public var kind: Kind
    public var text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }

    var typeName: String {
        switch self.kind {
        case .plain: return "plain"
        case .bold: return "bold"
        case .italic: return "italic"
        case .underline: return "underline"
        case .strikethrough: return "strikethrough"
        case .code: return "code"
        case .pre: return "pre"
        case .spoiler: return "spoiler"
        case .link: return "link"
        case .textLink: return "text_link"
        case .mention: return "mention"
        case .mentionName: return "mention_name"
        case .hashtag: return "hashtag"
        case .cashtag: return "cashtag"
        case .botCommand: return "bot_command"
        case .email: return "email"
        case .phone: return "phone"
        case .bankCard: return "bank_card"
        case .blockquote: return "blockquote"
        case .customEmoji: return "custom_emoji"
        }
    }
}

public struct ChatExportVersion: Equatable {
    public var date: Int32
    public var text: String

    public init(date: Int32, text: String) {
        self.date = date
        self.text = text
    }
}

public struct ChatExportMessage: Equatable {
    public var id: Int32
    public var date: Int32
    public var editDate: Int32?
    public var fromName: String?
    public var fromId: String?
    public var isOutgoing: Bool
    public var parts: [ChatExportTextPart]
    public var mediaType: String?
    public var fileName: String?
    public var replyToMessageId: Int32?
    public var forwardedFrom: String?
    public var isDeleted: Bool
    public var editHistory: [ChatExportVersion]

    public init(id: Int32, date: Int32, editDate: Int32?, fromName: String?, fromId: String?, isOutgoing: Bool, parts: [ChatExportTextPart], mediaType: String?, fileName: String?, replyToMessageId: Int32?, forwardedFrom: String?, isDeleted: Bool, editHistory: [ChatExportVersion]) {
        self.id = id
        self.date = date
        self.editDate = editDate
        self.fromName = fromName
        self.fromId = fromId
        self.isOutgoing = isOutgoing
        self.parts = parts
        self.mediaType = mediaType
        self.fileName = fileName
        self.replyToMessageId = replyToMessageId
        self.forwardedFrom = forwardedFrom
        self.isDeleted = isDeleted
        self.editHistory = editHistory
    }

    public var plainText: String {
        return self.parts.map(\.text).joined()
    }
}

public struct ChatExportChat: Equatable {
    public var name: String
    public var type: String
    public var id: Int64
    public var messages: [ChatExportMessage]

    public init(name: String, type: String, id: Int64, messages: [ChatExportMessage]) {
        self.name = name
        self.type = type
        self.id = id
        self.messages = messages
    }
}

public struct ChatExportLabels: Equatable {
    public var deleted: String
    public var edited: String
    public var editHistory: String
    public var media: String
    public var reply: String
    public var forwarded: String

    public init(deleted: String, edited: String, editHistory: String, media: String, reply: String, forwarded: String) {
        self.deleted = deleted
        self.edited = edited
        self.editHistory = editHistory
        self.media = media
        self.reply = reply
        self.forwarded = forwarded
    }
}

public func chatExportTextParts(text: String, entities: [(range: Range<Int>, kind: ChatExportTextPart.Kind)]) -> [ChatExportTextPart] {
    let utf16 = Array(text.utf16)
    func substring(_ range: Range<Int>) -> String {
        let lower = max(0, min(range.lowerBound, utf16.count))
        let upper = max(lower, min(range.upperBound, utf16.count))
        return String(decoding: utf16[lower ..< upper], as: UTF16.self)
    }
    let sorted = entities
        .filter { !$0.range.isEmpty && $0.range.lowerBound < utf16.count }
        .sorted(by: { lhs, rhs in
            if lhs.range.lowerBound != rhs.range.lowerBound {
                return lhs.range.lowerBound < rhs.range.lowerBound
            }
            return lhs.range.count > rhs.range.count
        })
    var result: [ChatExportTextPart] = []
    var position = 0
    for entity in sorted {
        if entity.range.lowerBound < position {
            continue
        }
        if entity.range.lowerBound > position {
            result.append(ChatExportTextPart(kind: .plain, text: substring(position ..< entity.range.lowerBound)))
        }
        let upper = min(entity.range.upperBound, utf16.count)
        result.append(ChatExportTextPart(kind: entity.kind, text: substring(entity.range.lowerBound ..< upper)))
        position = upper
    }
    if position < utf16.count {
        result.append(ChatExportTextPart(kind: .plain, text: substring(position ..< utf16.count)))
    }
    return result
}

private func makeDateFormatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = format
    return formatter
}

public struct ChatExportRenderer {
    public let labels: ChatExportLabels
    private let isoFormatter: DateFormatter
    private let textFormatter: DateFormatter

    public init(labels: ChatExportLabels, timeZone: TimeZone = .current) {
        self.labels = labels
        self.isoFormatter = makeDateFormatter("yyyy-MM-dd'T'HH:mm:ss", timeZone: timeZone)
        self.textFormatter = makeDateFormatter("yyyy-MM-dd HH:mm:ss", timeZone: timeZone)
    }

    private func isoDate(_ timestamp: Int32) -> String {
        return self.isoFormatter.string(from: Date(timeIntervalSince1970: Double(timestamp)))
    }

    private func textDate(_ timestamp: Int32) -> String {
        return self.textFormatter.string(from: Date(timeIntervalSince1970: Double(timestamp)))
    }

    public func render(_ chat: ChatExportChat, format: ChatExportFormat) -> Data {
        switch format {
        case .text:
            return Data(self.renderText(chat).utf8)
        case .json:
            return self.renderJson(chat)
        case .html:
            return Data(self.renderHtml(chat).utf8)
        }
    }

    public func renderText(_ chat: ChatExportChat) -> String {
        var lines: [String] = [chat.name, ""]
        for message in chat.messages {
            var header = "[\(self.textDate(message.date))] \(message.fromName ?? "")"
            var markers: [String] = []
            if message.isDeleted {
                markers.append(self.labels.deleted)
            }
            if message.editDate != nil || !message.editHistory.isEmpty {
                markers.append(self.labels.edited)
            }
            if !markers.isEmpty {
                header += " (\(markers.joined(separator: ", ")))"
            }
            var body: [String] = []
            if let forwardedFrom = message.forwardedFrom {
                body.append("\(self.labels.forwarded): \(forwardedFrom)")
            }
            if let replyToMessageId = message.replyToMessageId {
                body.append("\(self.labels.reply) #\(replyToMessageId)")
            }
            if let mediaType = message.mediaType {
                if let fileName = message.fileName {
                    body.append("[\(self.labels.media): \(mediaType), \(fileName)]")
                } else {
                    body.append("[\(self.labels.media): \(mediaType)]")
                }
            }
            let text = message.plainText
            if !text.isEmpty {
                body.append(text)
            }
            lines.append("\(header): \(body.joined(separator: "\n"))")
            for version in message.editHistory {
                lines.append("    \(self.labels.editHistory) [\(self.textDate(version.date))]: \(version.text)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func entityObject(_ part: ChatExportTextPart) -> [String: Any] {
        var object: [String: Any] = ["type": part.typeName, "text": part.text]
        switch part.kind {
        case let .textLink(url):
            object["href"] = url
        case let .mentionName(userId):
            object["user_id"] = userId
        case let .pre(language):
            object["language"] = language ?? ""
        case let .customEmoji(documentId):
            object["document_id"] = "\(documentId)"
        default:
            break
        }
        return object
    }

    public func jsonObject(_ chat: ChatExportChat) -> [String: Any] {
        var messages: [[String: Any]] = []
        for message in chat.messages {
            var object: [String: Any] = [
                "id": Int(message.id),
                "type": "message",
                "date": self.isoDate(message.date),
                "date_unixtime": "\(message.date)"
            ]
            if let editDate = message.editDate {
                object["edited"] = self.isoDate(editDate)
                object["edited_unixtime"] = "\(editDate)"
            }
            if let fromName = message.fromName {
                object["from"] = fromName
            }
            if let fromId = message.fromId {
                object["from_id"] = fromId
            }
            if let replyToMessageId = message.replyToMessageId {
                object["reply_to_message_id"] = Int(replyToMessageId)
            }
            if let forwardedFrom = message.forwardedFrom {
                object["forwarded_from"] = forwardedFrom
            }
            if let mediaType = message.mediaType {
                object["media_type"] = mediaType
            }
            if let fileName = message.fileName {
                object["file_name"] = fileName
            }
            if message.parts.allSatisfy({ $0.kind == .plain }) {
                object["text"] = message.plainText
            } else {
                object["text"] = message.parts.map { part -> Any in
                    if part.kind == .plain {
                        return part.text
                    }
                    return self.entityObject(part)
                }
            }
            object["text_entities"] = message.parts.map(self.entityObject)
            if message.isDeleted {
                object["deleted"] = true
            }
            if !message.editHistory.isEmpty {
                object["edit_history"] = message.editHistory.map { version -> [String: Any] in
                    return [
                        "date": self.isoDate(version.date),
                        "date_unixtime": "\(version.date)",
                        "text": version.text
                    ]
                }
            }
            messages.append(object)
        }
        return [
            "name": chat.name,
            "type": chat.type,
            "id": chat.id,
            "messages": messages
        ]
    }

    public func renderJson(_ chat: ChatExportChat) -> Data {
        let object = self.jsonObject(chat)
        return (try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data()
    }

    private func escape(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&":
                result += "&amp;"
            case "<":
                result += "&lt;"
            case ">":
                result += "&gt;"
            case "\"":
                result += "&quot;"
            case "\n":
                result += "<br>"
            default:
                result.append(character)
            }
        }
        return result
    }

    private func htmlPart(_ part: ChatExportTextPart) -> String {
        let text = self.escape(part.text)
        switch part.kind {
        case .plain, .mention, .hashtag, .cashtag, .botCommand, .phone, .bankCard, .customEmoji:
            return text
        case .bold:
            return "<b>\(text)</b>"
        case .italic:
            return "<i>\(text)</i>"
        case .underline:
            return "<u>\(text)</u>"
        case .strikethrough:
            return "<s>\(text)</s>"
        case .code:
            return "<code>\(text)</code>"
        case .pre:
            return "<pre>\(text)</pre>"
        case .spoiler:
            return "<span class=\"spoiler\">\(text)</span>"
        case .link:
            return "<a href=\"\(self.escape(part.text))\">\(text)</a>"
        case let .textLink(url):
            return "<a href=\"\(self.escape(url))\">\(text)</a>"
        case .mentionName:
            return "<b>\(text)</b>"
        case .email:
            return "<a href=\"mailto:\(self.escape(part.text))\">\(text)</a>"
        case .blockquote:
            return "<blockquote>\(text)</blockquote>"
        }
    }

    public func renderHtml(_ chat: ChatExportChat) -> String {
        var body = ""
        for message in chat.messages {
            var classes = ["message", message.isOutgoing ? "out" : "in"]
            if message.isDeleted {
                classes.append("deleted")
            }
            body += "<div class=\"\(classes.joined(separator: " "))\" id=\"message\(message.id)\">"
            body += "<div class=\"meta\"><span class=\"from\">\(self.escape(message.fromName ?? ""))</span> <span class=\"date\">\(self.escape(self.textDate(message.date)))</span>"
            if message.isDeleted {
                body += " <span class=\"tag\">\(self.escape(self.labels.deleted))</span>"
            }
            if message.editDate != nil || !message.editHistory.isEmpty {
                body += " <span class=\"tag\">\(self.escape(self.labels.edited))</span>"
            }
            body += "</div>"
            if let forwardedFrom = message.forwardedFrom {
                body += "<div class=\"aux\">\(self.escape(self.labels.forwarded)): \(self.escape(forwardedFrom))</div>"
            }
            if let replyToMessageId = message.replyToMessageId {
                body += "<div class=\"aux\"><a href=\"#message\(replyToMessageId)\">\(self.escape(self.labels.reply)) #\(replyToMessageId)</a></div>"
            }
            if let mediaType = message.mediaType {
                let name = message.fileName.map { ", \(self.escape($0))" } ?? ""
                body += "<div class=\"aux\">[\(self.escape(self.labels.media)): \(self.escape(mediaType))\(name)]</div>"
            }
            if !message.parts.isEmpty {
                body += "<div class=\"text\">\(message.parts.map(self.htmlPart).joined())</div>"
            }
            if !message.editHistory.isEmpty {
                body += "<details><summary>\(self.escape(self.labels.editHistory))</summary>"
                for version in message.editHistory {
                    body += "<div class=\"version\"><span class=\"date\">\(self.escape(self.textDate(version.date)))</span><div>\(self.escape(version.text))</div></div>"
                }
                body += "</details>"
            }
            body += "</div>\n"
        }
        let style = """
        body{margin:0;background:#e7ebf0;font:15px -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;color:#000}
        header{position:sticky;top:0;background:#fff;padding:14px 20px;font-weight:600;font-size:17px;box-shadow:0 1px 2px rgba(0,0,0,.1)}
        main{max-width:720px;margin:0 auto;padding:12px}
        .message{background:#fff;border-radius:14px;padding:8px 12px;margin:6px 0;max-width:85%;word-wrap:break-word}
        .message.out{margin-left:auto;background:#effdde}
        .message.deleted{opacity:.6}
        .meta{font-size:13px;color:#707579;margin-bottom:3px}
        .from{color:#3a6d99;font-weight:600}
        .tag{background:#f0f0f0;border-radius:6px;padding:0 5px}
        .aux{font-size:13px;color:#707579}
        .spoiler{background:#ccc;color:transparent}
        .spoiler:hover{color:inherit;background:none}
        pre,code{font-family:ui-monospace,Menlo,monospace;background:#f4f4f4;border-radius:4px;padding:0 3px}
        pre{padding:6px;white-space:pre-wrap}
        blockquote{border-left:3px solid #3a6d99;margin:4px 0;padding-left:8px}
        details{font-size:13px;color:#707579;margin-top:4px}
        .version{margin:4px 0}
        @media (prefers-color-scheme:dark){body{background:#0e1621;color:#fff}header{background:#17212b}.message{background:#182533}.message.out{background:#2b5278}.tag,pre,code{background:#242f3d}}
        """
        return "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>\(self.escape(chat.name))</title><style>\(style)</style></head><body><header>\(self.escape(chat.name))</header><main>\n\(body)</main></body></html>\n"
    }
}
