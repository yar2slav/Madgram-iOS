import Foundation
import SwiftSignalKit
import TelegramCore

public struct ChatContentFilterSettings: Codable, Equatable {
    public static let defaultPromotedPostKeywords: [String] = ["#реклама", "#промо", "на правах рекламы", "реклама."]

    public var hidePromotedPosts: Bool
    public var hideSponsoredMessages: Bool
    public var promotedPostKeywords: [String]
    public var revealTextSpoilers: Bool
    public var revealMediaSpoilers: Bool
    public var hiddenRulesSource: String

    public static let defaultSettings = ChatContentFilterSettings(
        hidePromotedPosts: true,
        hideSponsoredMessages: true,
        promotedPostKeywords: ChatContentFilterSettings.defaultPromotedPostKeywords,
        revealTextSpoilers: false,
        revealMediaSpoilers: false
    )

    public init(hidePromotedPosts: Bool, hideSponsoredMessages: Bool, promotedPostKeywords: [String], revealTextSpoilers: Bool, revealMediaSpoilers: Bool, hiddenRulesSource: String = "") {
        self.hiddenRulesSource = hiddenRulesSource
        self.hidePromotedPosts = hidePromotedPosts
        self.hideSponsoredMessages = hideSponsoredMessages
        self.promotedPostKeywords = promotedPostKeywords
        self.revealTextSpoilers = revealTextSpoilers
        self.revealMediaSpoilers = revealMediaSpoilers
    }

    private enum CodingKeys: String, CodingKey {
        case hidePromotedPosts
        case hideSponsoredMessages
        case promotedPostKeywords
        case revealTextSpoilers
        case revealMediaSpoilers
        case hiddenRulesSource
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ChatContentFilterSettings.defaultSettings
        self.hidePromotedPosts = try container.decodeIfPresent(Bool.self, forKey: .hidePromotedPosts) ?? defaults.hidePromotedPosts
        self.hideSponsoredMessages = try container.decodeIfPresent(Bool.self, forKey: .hideSponsoredMessages) ?? defaults.hideSponsoredMessages
        self.promotedPostKeywords = try container.decodeIfPresent([String].self, forKey: .promotedPostKeywords) ?? defaults.promotedPostKeywords
        self.revealTextSpoilers = try container.decodeIfPresent(Bool.self, forKey: .revealTextSpoilers) ?? defaults.revealTextSpoilers
        self.revealMediaSpoilers = try container.decodeIfPresent(Bool.self, forKey: .revealMediaSpoilers) ?? defaults.revealMediaSpoilers
        self.hiddenRulesSource = try container.decodeIfPresent(String.self, forKey: .hiddenRulesSource) ?? ""
    }

    public var revealsSpoilers: Bool {
        return self.revealTextSpoilers || self.revealMediaSpoilers
    }
}

public final class ChatContentFilterSettingsStore {
    public static let shared = ChatContentFilterSettingsStore()
    public static let didChangeNotification = Notification.Name("ChatContentFilterSettingsStore.didChange")

    private let defaults: UserDefaults
    private let key = "chatContentFilterSettings.v1"
    private let lock = NSLock()
    private var cachedValue: ChatContentFilterSettings

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.cachedValue = ChatContentFilterSettingsStore.read(defaults: defaults, key: self.key) ?? .defaultSettings
    }

    private static func read(defaults: UserDefaults, key: String) -> ChatContentFilterSettings? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(ChatContentFilterSettings.self, from: data)
    }

    public var current: ChatContentFilterSettings {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.cachedValue
    }

    public func update(_ f: (ChatContentFilterSettings) -> ChatContentFilterSettings) {
        self.lock.lock()
        let currentValue = self.cachedValue
        let updatedValue = f(currentValue)
        self.cachedValue = updatedValue
        if let data = try? JSONEncoder().encode(updatedValue) {
            self.defaults.set(data, forKey: self.key)
        }
        self.lock.unlock()

        if updatedValue != currentValue {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }
}

public func chatContentFilterSettingsSignal() -> Signal<ChatContentFilterSettings, NoError> {
    return Signal { subscriber in
        subscriber.putNext(ChatContentFilterSettingsStore.shared.current)
        let observer = NotificationCenter.default.addObserver(
            forName: ChatContentFilterSettingsStore.didChangeNotification,
            object: nil,
            queue: nil,
            using: { _ in
                subscriber.putNext(ChatContentFilterSettingsStore.shared.current)
            }
        )
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    |> distinctUntilChanged
}

public func messageAttributesRevealingSpoilers(_ attributes: [EngineMessage.Attribute], text: Bool, media: Bool) -> [EngineMessage.Attribute]? {
    if !text && !media {
        return nil
    }
    var changed = false
    let result = attributes.compactMap { attribute -> EngineMessage.Attribute? in
        if media, attribute is MediaSpoilerMessageAttribute {
            changed = true
            return nil
        }
        if text, let entities = attribute as? TextEntitiesMessageAttribute, entities.entities.contains(where: { $0.type == .Spoiler }) {
            changed = true
            return TextEntitiesMessageAttribute(entities: entities.entities.filter { $0.type != .Spoiler })
        }
        return attribute
    }
    return changed ? result : nil
}

public enum PromotedPostDetector {
    private static func isWordCharacter(_ character: Character) -> Bool {
        return character.isLetter || character.isNumber
    }

    static func containsKeyword(_ keyword: String, in text: String) -> Bool {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = keyword.first, let last = keyword.last else {
            return false
        }
        let checksStart = isWordCharacter(first)
        let checksEnd = isWordCharacter(last)
        var searchRange = text.startIndex ..< text.endIndex
        while let range = text.range(of: keyword, options: [.caseInsensitive], range: searchRange) {
            let startIsBoundary = !checksStart || range.lowerBound == text.startIndex || !isWordCharacter(text[text.index(before: range.lowerBound)])
            let endIsBoundary = !checksEnd || range.upperBound == text.endIndex || !isWordCharacter(text[range.upperBound])
            if startIsBoundary && endIsBoundary {
                return true
            }
            searchRange = range.upperBound ..< text.endIndex
        }
        return false
    }

    static func containsAdvertiserMarker(_ text: String) -> Bool {
        if text.range(of: "erid\\s*[:=]?\\s*[A-Za-z0-9]{6,}", options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        if text.range(of: "(^|[^\\p{L}\\p{N}])(инн|inn)\\s*:?\\s*\\d{10}(\\d{2})?([^\\d]|$)", options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        return false
    }

    static func urlHasAdvertiserMarker(_ url: String) -> Bool {
        guard let components = URLComponents(string: url) else {
            return url.range(of: "[?&]erid=", options: [.regularExpression, .caseInsensitive]) != nil
        }
        return components.queryItems?.contains(where: { $0.name.lowercased() == "erid" }) ?? false
    }

    public static func isPromoted(text: String, entities: [MessageTextEntity], keywords: [String]) -> Bool {
        let nsText = text as NSString
        for entity in entities {
            switch entity.type {
            case let .TextUrl(url):
                if urlHasAdvertiserMarker(url) {
                    return true
                }
            case .Url:
                if entity.range.lowerBound >= 0 && entity.range.upperBound <= nsText.length {
                    if urlHasAdvertiserMarker(nsText.substring(with: NSRange(location: entity.range.lowerBound, length: entity.range.count))) {
                        return true
                    }
                }
            case .Hashtag:
                if entity.range.lowerBound >= 0 && entity.range.upperBound <= nsText.length {
                    let hashtag = nsText.substring(with: NSRange(location: entity.range.lowerBound, length: entity.range.count)).lowercased()
                    if hashtag == "#реклама" {
                        return true
                    }
                }
            default:
                break
            }
        }
        if text.isEmpty {
            return false
        }
        if containsKeyword("#реклама", in: text) {
            return true
        }
        if containsAdvertiserMarker(text) {
            return true
        }
        for keyword in keywords {
            if containsKeyword(keyword, in: text) {
                return true
            }
        }
        return false
    }
}

public func madSpoilerRevealAllowed(peerId: EnginePeer.Id, accountPeerId: EnginePeer.Id, isBroadcast: Bool) -> Bool {
    let tuning = InterfaceTuningSettingsStore.shared.cached
    if peerId == accountPeerId {
        return tuning.sub(.spoilersSaved)
    }
    switch peerId.namespace {
    case Namespaces.Peer.CloudUser, Namespaces.Peer.SecretChat:
        return tuning.sub(.spoilersPrivate)
    case Namespaces.Peer.CloudChannel:
        return tuning.sub(isBroadcast ? .spoilersChannels : .spoilersGroups)
    default:
        return tuning.sub(.spoilersGroups)
    }
}

public func madProfileMediaSpoilerRevealAllowed(peerId: EnginePeer.Id, accountPeerId: EnginePeer.Id) -> Bool {
    let tuning = InterfaceTuningSettingsStore.shared.cached
    if peerId == accountPeerId && !tuning.sub(.spoilersSaved) {
        return false
    }
    return tuning.sub(.spoilersProfileMedia)
}
