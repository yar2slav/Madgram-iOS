import Foundation

public enum MadLinksDesign: String, Equatable {
    case row
    case list
}

public enum MadLinksCategory: String, Equatable, CaseIterable {
    case social
    case games
    case music
    case work
}

public enum MadLinksAccountLabel: String {
    case handle
    case name
}

public struct MadLinksAccount: Equatable {
    public let id: String
    public let platform: String
    public let handle: String
    public let displayName: String?
    public let url: String?
    public let verified: Bool
    public let visible: Bool
    public let position: Int
    public let label: MadLinksAccountLabel
    public let icon: String

    public init(id: String, platform: String, handle: String, displayName: String?, url: String?, verified: Bool, visible: Bool, position: Int, label: MadLinksAccountLabel = .handle, icon: String = "default") {
        self.id = id
        self.platform = platform
        self.handle = handle
        self.displayName = displayName
        self.url = url
        self.verified = verified
        self.visible = visible
        self.position = position
        self.label = label
        self.icon = icon
    }

    public var usesFavicon: Bool {
        return self.platform == "domain" && self.icon == "favicon"
    }

    public var faviconHost: String? {
        guard self.platform == "domain", let url = self.url, let host = URL(string: url)?.host, !host.isEmpty else {
            return nil
        }
        return host
    }

    public var title: String {
        let name = self.displayName ?? ""
        if self.label == .name, !name.isEmpty {
            return name
        }
        if !self.handle.isEmpty {
            return self.handle
        }
        if !name.isEmpty {
            return name
        }
        return MadLinksPlatformInfo.name(self.platform)
    }

    public var hasLabelChoice: Bool {
        guard let displayName = self.displayName, !displayName.isEmpty, !self.handle.isEmpty else {
            return false
        }
        return displayName != self.handle
    }

    public func withVisible(_ visible: Bool) -> MadLinksAccount {
        return MadLinksAccount(id: self.id, platform: self.platform, handle: self.handle, displayName: self.displayName, url: self.url, verified: self.verified, visible: visible, position: self.position, label: self.label, icon: self.icon)
    }

    public func withPosition(_ position: Int) -> MadLinksAccount {
        return MadLinksAccount(id: self.id, platform: self.platform, handle: self.handle, displayName: self.displayName, url: self.url, verified: self.verified, visible: self.visible, position: position, label: self.label, icon: self.icon)
    }

    public func withIcon(_ icon: String) -> MadLinksAccount {
        return MadLinksAccount(id: self.id, platform: self.platform, handle: self.handle, displayName: self.displayName, url: self.url, verified: self.verified, visible: self.visible, position: self.position, label: self.label, icon: icon)
    }

    public func withLabel(_ label: MadLinksAccountLabel) -> MadLinksAccount {
        return MadLinksAccount(id: self.id, platform: self.platform, handle: self.handle, displayName: self.displayName, url: self.url, verified: self.verified, visible: self.visible, position: self.position, label: label, icon: self.icon)
    }
}

public struct MadLinksProfile: Equatable {
    public let design: MadLinksDesign
    public let accounts: [MadLinksAccount]

    public init(design: MadLinksDesign, accounts: [MadLinksAccount]) {
        self.design = design
        self.accounts = accounts
    }

    public var publicProfile: MadLinksProfile {
        return MadLinksProfile(design: self.design, accounts: self.accounts.filter { $0.visible })
    }
}

public struct MadLinksPlatform: Equatable {
    public let id: String
    public let name: String
    public let category: MadLinksCategory?
    public let method: String
    public let available: Bool
    public let needsClientId: Bool

    public init(id: String, name: String, category: MadLinksCategory?, method: String, available: Bool, needsClientId: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.method = method
        self.available = available
        self.needsClientId = needsClientId
    }
}

public enum MadLinksConnectResult: Equatable {
    case linked(String?)
    case failed(String?)
    case unknown
}

public enum MadLinksPlatformInfo {
    public static let known: [String] = ["steam", "twitch", "spotify", "soundcloud", "lastfm", "github", "gitlab", "discord", "reddit"]

    public static func name(_ platform: String) -> String {
        switch platform {
        case "steam":
            return "Steam"
        case "twitch":
            return "Twitch"
        case "spotify":
            return "Spotify"
        case "soundcloud":
            return "SoundCloud"
        case "lastfm":
            return "Last.fm"
        case "github":
            return "GitHub"
        case "gitlab":
            return "GitLab"
        case "discord":
            return "Discord"
        case "reddit":
            return "Reddit"
        case "domain":
            return (Locale.preferredLanguages.first ?? "").hasPrefix("ru") ? "Домен" : "Domain"
        default:
            return platform.prefix(1).uppercased() + platform.dropFirst()
        }
    }

    public static func category(_ platform: String) -> MadLinksCategory? {
        switch platform {
        case "steam", "twitch":
            return .games
        case "spotify", "soundcloud", "lastfm":
            return .music
        case "github", "gitlab", "domain":
            return .work
        case "discord", "reddit":
            return .social
        default:
            return nil
        }
    }

    public static func iconName(_ platform: String) -> String? {
        guard self.known.contains(platform) else {
            return nil
        }
        return "Mad/Platforms/" + platform
    }

    public static var fallbackCatalog: [MadLinksPlatform] {
        return self.known.map { MadLinksPlatform(id: $0, name: self.name($0), category: self.category($0), method: "login", available: false) }
    }
}

public struct MadLinksDomainClaim: Equatable {
    public let domain: String
    public let displayDomain: String
    public let recordName: String
    public let recordValue: String

    public init(domain: String, displayDomain: String, recordName: String, recordValue: String) {
        self.domain = domain
        self.displayDomain = displayDomain
        self.recordName = recordName
        self.recordValue = recordValue
    }
}

public enum MadLinksParsing {
    public static func domainClaim(from data: Data) -> MadLinksDomainClaim? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let domain = object["domain"] as? String, let recordName = object["recordName"] as? String, let recordValue = object["recordValue"] as? String, !domain.isEmpty, recordValue.hasPrefix("mad-verify=") else {
            return nil
        }
        return MadLinksDomainClaim(domain: domain, displayDomain: (object["displayDomain"] as? String) ?? domain, recordName: recordName, recordValue: recordValue)
    }

    public static func initData(fromWebAppUrl string: String) -> String? {
        guard let hashIndex = string.firstIndex(of: "#") else {
            return nil
        }
        let fragment = string[string.index(after: hashIndex)...]
        for pair in fragment.split(separator: "&", omittingEmptySubsequences: true) {
            guard let equalIndex = pair.firstIndex(of: "=") else {
                continue
            }
            let key = pair[pair.startIndex ..< equalIndex]
            guard key == "tgWebAppData" else {
                continue
            }
            let rawValue = String(pair[pair.index(after: equalIndex)...])
            guard let value = rawValue.removingPercentEncoding, !value.isEmpty else {
                return nil
            }
            return value
        }
        return nil
    }

    public static func token(from data: Data) -> String? {
        guard let object = self.jsonObject(data), let token = object["token"] as? String, !token.isEmpty else {
            return nil
        }
        return token
    }

    public static func profile(from data: Data) -> MadLinksProfile? {
        guard let object = self.jsonObject(data) else {
            return nil
        }
        let design = (object["design"] as? String).flatMap(MadLinksDesign.init(rawValue:)) ?? .row
        guard let rawAccounts = object["accounts"] as? [Any] else {
            return MadLinksProfile(design: design, accounts: [])
        }
        var accounts: [MadLinksAccount] = []
        for (index, item) in rawAccounts.enumerated() {
            guard let item = item as? [String: Any], let account = self.account(item, index: index) else {
                continue
            }
            accounts.append(account)
        }
        let sorted = accounts.enumerated().sorted { lhs, rhs in
            if lhs.element.position != rhs.element.position {
                return lhs.element.position < rhs.element.position
            }
            return lhs.offset < rhs.offset
        }.map { $0.element }
        return MadLinksProfile(design: design, accounts: sorted)
    }

    public static func platforms(from data: Data) -> [MadLinksPlatform]? {
        guard let parsed = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }
        let rawList: [Any]
        if let list = parsed as? [Any] {
            rawList = list
        } else if let object = parsed as? [String: Any], let list = object["platforms"] as? [Any] {
            rawList = list
        } else {
            return nil
        }
        var result: [MadLinksPlatform] = []
        for item in rawList {
            guard let item = item as? [String: Any], let id = item["id"] as? String, !id.isEmpty else {
                continue
            }
            let name = (item["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? MadLinksPlatformInfo.name(id)
            let category = (item["category"] as? String).flatMap(MadLinksCategory.init(rawValue:)) ?? MadLinksPlatformInfo.category(id)
            let method = (item["method"] as? String) ?? "login"
            let available = self.bool(item["available"]) ?? false
            let needsClientId = self.bool(item["needsClientId"]) ?? false
            result.append(MadLinksPlatform(id: id, name: name, category: category, method: method, available: available, needsClientId: needsClientId))
        }
        return result
    }

    public static func connectResult(_ url: URL) -> MadLinksConnectResult {
        guard url.scheme?.lowercased() == "mad", url.host?.lowercased() == "accounts" else {
            return .unknown
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = components?.queryItems ?? []
        let platform = query.first(where: { $0.name == "platform" })?.value
        switch url.pathComponents.filter({ $0 != "/" }).first?.lowercased() {
        case "linked":
            return .linked(platform)
        case "failed":
            return .failed(query.first(where: { $0.name == "reason" || $0.name == "error" })?.value)
        default:
            return .unknown
        }
    }

    public static func isValidClientId(_ value: String) -> Bool {
        return value.count == 32 && value.allSatisfy { $0.isHexDigit }
    }

    public static func connectStartUrl(base: URL, platform: String, token: String, clientId: String? = nil) -> URL? {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        guard let encodedPlatform = platform.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        components.percentEncodedPath = "/api/v1/connect/\(encodedPlatform)/start"
        var tokenAllowed = CharacterSet.alphanumerics
        tokenAllowed.insert(charactersIn: "-._~")
        guard let encodedToken = token.addingPercentEncoding(withAllowedCharacters: tokenAllowed) else {
            return nil
        }
        var query = "token=" + encodedToken
        if let clientId {
            guard self.isValidClientId(clientId) else {
                return nil
            }
            query += "&client_id=" + clientId
        }
        components.percentEncodedQuery = query
        return components.url
    }

    static func account(_ item: [String: Any], index: Int) -> MadLinksAccount? {
        let id: String
        if let value = item["id"] as? String {
            id = value
        } else if let value = item["id"] as? NSNumber {
            id = value.stringValue
        } else {
            return nil
        }
        guard let platform = item["platform"] as? String, !platform.isEmpty else {
            return nil
        }
        let handle = (item["handle"] as? String) ?? ""
        let displayName = (item["displayName"] as? String) ?? (item["display_name"] as? String)
        var url = item["url"] as? String
        if let value = url, !(value.lowercased().hasPrefix("https://") || value.lowercased().hasPrefix("http://")) {
            url = nil
        }
        let verified = self.bool(item["verified"]) ?? false
        let visible = self.bool(item["visible"]) ?? true
        let position = (item["position"] as? NSNumber)?.intValue ?? index
        let label = (item["label"] as? String).flatMap(MadLinksAccountLabel.init(rawValue:)) ?? .handle
        let icon = (item["icon"] as? String).flatMap { ["default", "favicon"].contains($0) ? $0 : nil } ?? "default"
        return MadLinksAccount(id: id, platform: platform, handle: handle, displayName: displayName, url: url, verified: verified, visible: visible, position: position, label: label, icon: icon)
    }

    public static func account(from data: Data) -> MadLinksAccount? {
        guard let item = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        return self.account(item, index: 0)
    }

    public static func needsReconnect(_ data: Data) -> Bool {
        guard let item = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return false
        }
        return self.bool(item["reconnect"]) ?? false
    }

    static func bool(_ value: Any?) -> Bool? {
        if let value = value as? Bool {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue != 0
        }
        return nil
    }

    static func jsonObject(_ data: Data) -> [String: Any]? {
        return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
    }
}
