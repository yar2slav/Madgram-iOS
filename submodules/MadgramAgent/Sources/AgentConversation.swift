import Foundation

public struct AgentToolCall: Codable, Equatable {
    public var id: String
    public var name: String
    public var arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }

    public var argumentsObject: [String: Any] {
        guard let data = self.arguments.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }
}

public struct AgentImage: Codable, Equatable {
    public var mediaType: String
    public var base64: String

    public init(mediaType: String, base64: String) {
        self.mediaType = mediaType
        self.base64 = base64
    }
}

public struct AgentMessage: Codable, Equatable {
    public enum Role: String, Codable {
        case user
        case assistant
        case tool
    }

    public var id: String
    public var role: Role
    public var text: String
    public var toolCalls: [AgentToolCall]
    public var toolCallId: String?
    public var toolTitle: String?
    public var isError: Bool
    public var anthropicBlocks: String?
    public var anthropicModel: String?
    public var contextPrefix: String?
    public var images: [AgentImage]?
    public var isNotice: Bool?
    public var date: Date

    public init(role: Role, text: String, toolCalls: [AgentToolCall] = [], toolCallId: String? = nil, toolTitle: String? = nil, isError: Bool = false, anthropicBlocks: String? = nil, anthropicModel: String? = nil) {
        self.id = UUID().uuidString
        self.role = role
        self.text = text
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.toolTitle = toolTitle
        self.isError = isError
        self.anthropicBlocks = anthropicBlocks
        self.anthropicModel = anthropicModel
        self.contextPrefix = nil
        self.images = nil
        self.isNotice = nil
        self.date = Date()
    }
}

extension AgentMessage {
    var requestText: String {
        if let contextPrefix = self.contextPrefix, !contextPrefix.isEmpty {
            return contextPrefix + "\n\n" + self.text
        }
        return self.text
    }
}

public struct AgentConversationInfo: Codable, Equatable {
    public var id: String
    public var title: String
    public var updatedAt: Date
}

private struct AgentConversationIndex: Codable {
    var current: String
    var items: [AgentConversationInfo]
}

public enum AgentConversations {
    public static let didChangeNotification = Notification.Name("MadgramAgentConversationsDidChange")
    public static let legacyId = "default"

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("madgram-agent", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func fileUrl(accountId: Int64, conversationId: String) -> URL {
        if conversationId == self.legacyId {
            return self.directory.appendingPathComponent("conversation-\(accountId).json")
        }
        return self.directory.appendingPathComponent("conversation-\(accountId)-\(conversationId).json")
    }

    private static func indexUrl(_ accountId: Int64) -> URL {
        return self.directory.appendingPathComponent("index-\(accountId).json")
    }

    private static func loadIndex(_ accountId: Int64) -> AgentConversationIndex {
        if let data = try? Data(contentsOf: self.indexUrl(accountId)), let index = try? JSONDecoder().decode(AgentConversationIndex.self, from: data) {
            return index
        }
        var items: [AgentConversationInfo] = []
        let legacy = self.fileUrl(accountId: accountId, conversationId: self.legacyId)
        if let data = try? Data(contentsOf: legacy), let messages = try? JSONDecoder().decode([AgentMessage].self, from: data), !messages.isEmpty {
            items.append(AgentConversationInfo(id: self.legacyId, title: self.title(for: messages), updatedAt: messages.last?.date ?? Date()))
        }
        return AgentConversationIndex(current: self.legacyId, items: items)
    }

    private static func saveIndex(_ index: AgentConversationIndex, accountId: Int64) {
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: self.indexUrl(accountId), options: [.atomic])
        }
        NotificationCenter.default.post(name: self.didChangeNotification, object: nil, userInfo: ["accountId": accountId])
    }

    public static func title(for messages: [AgentMessage]) -> String {
        guard let first = messages.first(where: { $0.role == .user && !$0.text.isEmpty }) else {
            return ""
        }
        let text = first.text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count > 60 ? String(text.prefix(60)) + "…" : text
    }

    public static func list(accountId: Int64) -> [AgentConversationInfo] {
        return self.loadIndex(accountId).items.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    public static func currentId(accountId: Int64) -> String {
        return self.loadIndex(accountId).current
    }

    public static func setCurrent(accountId: Int64, id: String) {
        var index = self.loadIndex(accountId)
        guard index.current != id else {
            return
        }
        index.current = id
        self.saveIndex(index, accountId: accountId)
    }

    public static func create(accountId: Int64) -> String {
        var index = self.loadIndex(accountId)
        if !index.items.contains(where: { $0.id == index.current }) {
            return index.current
        }
        let id = UUID().uuidString.lowercased()
        index.current = id
        self.saveIndex(index, accountId: accountId)
        return id
    }

    public static func delete(accountId: Int64, id: String) {
        var index = self.loadIndex(accountId)
        try? FileManager.default.removeItem(at: self.fileUrl(accountId: accountId, conversationId: id))
        index.items.removeAll(where: { $0.id == id })
        if index.current == id {
            index.current = index.items.sorted(by: { $0.updatedAt > $1.updatedAt }).first?.id ?? UUID().uuidString.lowercased()
        }
        self.saveIndex(index, accountId: accountId)
    }

    static func didSave(accountId: Int64, conversationId: String, messages: [AgentMessage]) {
        var index = self.loadIndex(accountId)
        if messages.isEmpty {
            guard index.items.contains(where: { $0.id == conversationId }) else {
                return
            }
            index.items.removeAll(where: { $0.id == conversationId })
        } else {
            let info = AgentConversationInfo(id: conversationId, title: self.title(for: messages), updatedAt: messages.last?.date ?? Date())
            if let position = index.items.firstIndex(where: { $0.id == conversationId }) {
                if index.items[position] == info {
                    return
                }
                index.items[position] = info
            } else {
                index.items.append(info)
            }
        }
        self.saveIndex(index, accountId: accountId)
    }
}

public final class AgentConversationStore {
    private let url: URL
    public let accountId: Int64
    public let conversationId: String

    public convenience init(accountId: Int64) {
        self.init(accountId: accountId, conversationId: AgentConversations.currentId(accountId: accountId))
    }

    public init(accountId: Int64, conversationId: String) {
        self.accountId = accountId
        self.conversationId = conversationId
        self.url = AgentConversations.fileUrl(accountId: accountId, conversationId: conversationId)
    }

    public func load() -> [AgentMessage] {
        guard let data = try? Data(contentsOf: self.url), let messages = try? JSONDecoder().decode([AgentMessage].self, from: data) else {
            return []
        }
        return messages
    }

    public func save(_ messages: [AgentMessage]) {
        defer {
            AgentConversations.didSave(accountId: self.accountId, conversationId: self.conversationId, messages: messages)
        }
        if messages.isEmpty {
            try? FileManager.default.removeItem(at: self.url)
            return
        }
        if let data = try? JSONEncoder().encode(messages) {
            try? data.write(to: self.url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }
}
