import Foundation
import Security

public enum AgentProviderKind: String, Codable, CaseIterable, Equatable {
    case anthropic
    case openai
    case anthropicCompatible
    case openaiCompatible

    public var usesAnthropicProtocol: Bool {
        switch self {
        case .anthropic, .anthropicCompatible:
            return true
        case .openai, .openaiCompatible:
            return false
        }
    }

    public var isCustom: Bool {
        switch self {
        case .anthropicCompatible, .openaiCompatible:
            return true
        case .anthropic, .openai:
            return false
        }
    }

    public var officialBaseUrl: String? {
        switch self {
        case .anthropic:
            return "https://api.anthropic.com/v1"
        case .openai:
            return "https://api.openai.com/v1"
        case .anthropicCompatible, .openaiCompatible:
            return nil
        }
    }

    public var defaultModel: String {
        switch self {
        case .anthropic, .anthropicCompatible:
            return "claude-sonnet-5-5"
        case .openai, .openaiCompatible:
            return ""
        }
    }
}

public struct AgentAutoReply: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case peerId, title, scenario, isEnabled, maxRepliesPerHour, stopPhrases
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.peerId = try container.decode(Int64.self, forKey: .peerId)
        self.title = (try? container.decode(String.self, forKey: .title)) ?? ""
        self.scenario = (try? container.decode(String.self, forKey: .scenario)) ?? ""
        self.isEnabled = (try? container.decode(Bool.self, forKey: .isEnabled)) ?? false
        self.maxRepliesPerHour = (try? container.decode(Int.self, forKey: .maxRepliesPerHour)) ?? 30
        self.stopPhrases = (try? container.decode([String].self, forKey: .stopPhrases)) ?? AgentAutoReply.defaultStopPhrases
    }

    public var peerId: Int64
    public var title: String
    public var scenario: String
    public var isEnabled: Bool
    public var maxRepliesPerHour: Int
    public var stopPhrases: [String]

    public static let defaultStopPhrases = ["ты бот", "это бот", "ты ии", "это ии", "ты нейросеть", "это нейросеть", "ты chatgpt", "are you a bot"]

    public init(peerId: Int64, title: String, scenario: String, isEnabled: Bool, maxRepliesPerHour: Int = 30, stopPhrases: [String] = AgentAutoReply.defaultStopPhrases) {
        self.stopPhrases = stopPhrases
        self.peerId = peerId
        self.title = title
        self.scenario = scenario
        self.isEnabled = isEnabled
        self.maxRepliesPerHour = maxRepliesPerHour
    }
}

public struct AgentSettings: Codable, Equatable {
    public var provider: AgentProviderKind
    public var customBaseUrls: [String: String]
    public var models: [String: String]
    public var persona: String
    public var allowReadChats: Bool
    public var allowSendMessages: Bool
    public var maxTokens: Int
    public var sendWithoutConfirmation: Bool
    public var autoReplies: [AgentAutoReply]
    public var allowChatActions: Bool
    public var allowForwarding: Bool
    public var allowWebSearch: Bool
    public var autoReplyWebSearch: Bool
    public var autoReplyLiveStatus: Bool
    public var agentNotifications: Bool = true

    public static let defaultPersona = "Ты — ИИ-ассистент внутри mad. Общайся по-русски, на «ты», коротко и по делу, без канцелярита. Если просят пересказать переписку — выдели главное: кто что сказал, о чём договорились, что требует ответа."

    public static let defaultSettings = AgentSettings(
        provider: .anthropic,
        customBaseUrls: [:],
        models: [:],
        persona: AgentSettings.defaultPersona,
        allowReadChats: true,
        allowSendMessages: true,
        maxTokens: 8192,
        sendWithoutConfirmation: false,
        autoReplies: [],
        allowChatActions: false,
        allowForwarding: false,
        allowWebSearch: true,
        autoReplyWebSearch: false,
        autoReplyLiveStatus: false
    )

    public init(provider: AgentProviderKind, customBaseUrls: [String: String], models: [String: String], persona: String, allowReadChats: Bool, allowSendMessages: Bool, maxTokens: Int, sendWithoutConfirmation: Bool, autoReplies: [AgentAutoReply], allowChatActions: Bool, allowForwarding: Bool, allowWebSearch: Bool, autoReplyWebSearch: Bool, autoReplyLiveStatus: Bool) {
        self.autoReplyLiveStatus = autoReplyLiveStatus
        self.autoReplyWebSearch = autoReplyWebSearch
        self.allowChatActions = allowChatActions
        self.allowForwarding = allowForwarding
        self.allowWebSearch = allowWebSearch
        self.sendWithoutConfirmation = sendWithoutConfirmation
        self.autoReplies = autoReplies
        self.provider = provider
        self.customBaseUrls = customBaseUrls
        self.models = models
        self.persona = persona
        self.allowReadChats = allowReadChats
        self.allowSendMessages = allowSendMessages
        self.maxTokens = maxTokens
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AgentSettings.defaultSettings
        self.provider = (try? container.decode(AgentProviderKind.self, forKey: .provider)) ?? defaults.provider
        self.customBaseUrls = (try? container.decode([String: String].self, forKey: .customBaseUrls)) ?? [:]
        self.models = (try? container.decode([String: String].self, forKey: .models)) ?? [:]
        self.persona = (try? container.decode(String.self, forKey: .persona)) ?? defaults.persona
        self.allowReadChats = (try? container.decode(Bool.self, forKey: .allowReadChats)) ?? defaults.allowReadChats
        self.allowSendMessages = (try? container.decode(Bool.self, forKey: .allowSendMessages)) ?? defaults.allowSendMessages
        self.maxTokens = (try? container.decode(Int.self, forKey: .maxTokens)) ?? defaults.maxTokens
        self.sendWithoutConfirmation = (try? container.decode(Bool.self, forKey: .sendWithoutConfirmation)) ?? false
        self.autoReplies = (try? container.decode([AgentAutoReply].self, forKey: .autoReplies)) ?? []
        self.allowChatActions = (try? container.decode(Bool.self, forKey: .allowChatActions)) ?? false
        self.allowForwarding = (try? container.decode(Bool.self, forKey: .allowForwarding)) ?? false
        self.allowWebSearch = (try? container.decode(Bool.self, forKey: .allowWebSearch)) ?? true
        self.autoReplyWebSearch = (try? container.decode(Bool.self, forKey: .autoReplyWebSearch)) ?? false
        self.autoReplyLiveStatus = (try? container.decode(Bool.self, forKey: .autoReplyLiveStatus)) ?? false
        self.agentNotifications = (try? container.decode(Bool.self, forKey: .agentNotifications)) ?? true
    }

    public func baseUrl(for provider: AgentProviderKind) -> String {
        if let official = provider.officialBaseUrl {
            return official
        }
        return self.customBaseUrls[provider.rawValue] ?? ""
    }

    public func model(for provider: AgentProviderKind) -> String {
        if let model = self.models[provider.rawValue], !model.isEmpty {
            return model
        }
        return provider.defaultModel
    }

    public var currentBaseUrl: String {
        return self.baseUrl(for: self.provider)
    }

    public var currentModel: String {
        return self.model(for: self.provider)
    }

    public func autoReply(peerId: Int64) -> AgentAutoReply? {
        return self.autoReplies.first(where: { $0.peerId == peerId })
    }

    public mutating func setAutoReply(_ value: AgentAutoReply) {
        if let index = self.autoReplies.firstIndex(where: { $0.peerId == value.peerId }) {
            self.autoReplies[index] = value
        } else {
            self.autoReplies.append(value)
        }
    }
}

public final class AgentSettingsStore {
    public static let shared = AgentSettingsStore()
    public static let didChangeNotification = Notification.Name("MadgramAgentSettingsDidChange")

    private let key = "madgram.agent.settings.v1"
    private let lock = NSLock()
    private var cached: AgentSettings?

    public var current: AgentSettings {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let cached = self.cached {
            return cached
        }
        var value = AgentSettings.defaultSettings
        if let data = UserDefaults.standard.data(forKey: self.key), let decoded = try? JSONDecoder().decode(AgentSettings.self, from: data) {
            value = decoded
        }
        self.cached = value
        return value
    }

    public func update(_ f: (inout AgentSettings) -> Void) {
        self.lock.lock()
        var value = self.cached ?? self.loadUnlocked()
        let previous = value
        f(&value)
        self.cached = value
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: self.key)
        }
        self.lock.unlock()
        if previous != value {
            NotificationCenter.default.post(name: AgentSettingsStore.didChangeNotification, object: nil)
        }
    }

    private func loadUnlocked() -> AgentSettings {
        if let data = UserDefaults.standard.data(forKey: self.key), let decoded = try? JSONDecoder().decode(AgentSettings.self, from: data) {
            return decoded
        }
        return AgentSettings.defaultSettings
    }
}

public enum AgentKeychain {
    private static let service = "org.madgram.agent"

    public static func apiKey(for provider: AgentProviderKind) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AgentKeychain.service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8), !value.isEmpty else {
            return nil
        }
        return value
    }

    public static func setApiKey(_ value: String?, for provider: AgentProviderKind) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AgentKeychain.service,
            kSecAttrAccount as String: provider.rawValue
        ]
        SecItemDelete(query as CFDictionary)
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty, let data = value.data(using: .utf8) else {
            NotificationCenter.default.post(name: AgentSettingsStore.didChangeNotification, object: nil)
            return
        }
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
        NotificationCenter.default.post(name: AgentSettingsStore.didChangeNotification, object: nil)
    }
}
