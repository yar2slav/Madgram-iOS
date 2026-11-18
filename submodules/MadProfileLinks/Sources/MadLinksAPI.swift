import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import MadProfileLinksCore

public final class MadLinksAPI {
    private let context: AccountContext
    private let session: MadLinksSession

    public init(context: AccountContext) {
        self.context = context
        self.session = MadLinksSession.shared(context: context)
    }

    public func profile(peerId: EnginePeer.Id, interactive: Bool) async throws -> MadLinksProfile {
        let userId = peerId.id._internalGetInt64Value()
        let data = try await self.session.request(method: "GET", path: "/api/v1/profiles/\(userId)", interactive: interactive)
        guard let profile = MadLinksParsing.profile(from: data) else {
            throw MadLinksError.invalidResponse
        }
        return profile.publicProfile
    }

    public func myAccounts() async throws -> MadLinksProfile {
        let data = try await self.session.request(method: "GET", path: "/api/v1/me/accounts", interactive: true)
        guard let profile = MadLinksParsing.profile(from: data) else {
            throw MadLinksError.invalidResponse
        }
        self.publishOwn(profile)
        return profile
    }

    public func updateAccount(id: String, visible: Bool? = nil, position: Int? = nil, label: MadLinksAccountLabel? = nil, icon: String? = nil) async throws {
        var body: [String: Any] = [:]
        if let icon {
            body["icon"] = icon
        }
        if let label {
            body["label"] = label.rawValue
        }
        if let visible {
            body["visible"] = visible
        }
        if let position {
            body["position"] = position
        }
        _ = try await self.session.request(method: "PATCH", path: "/api/v1/me/accounts/\(self.encode(id))", body: body, interactive: true)
    }

    public func refreshAccount(id: String) async throws -> MadLinksAccount {
        let data = try await self.session.request(method: "POST", path: "/api/v1/me/accounts/\(self.encode(id))/refresh", interactive: true)
        guard let account = MadLinksParsing.account(from: data) else {
            throw MadLinksError.invalidResponse
        }
        return account
    }

    public func claimDomain(_ domain: String) async throws -> MadLinksDomainClaim {
        let data = try await self.session.request(method: "POST", path: "/api/v1/me/domains", body: ["domain": domain], interactive: true)
        guard let claim = MadLinksParsing.domainClaim(from: data) else {
            throw MadLinksError.invalidResponse
        }
        return claim
    }

    public func verifyDomain(_ domain: String) async throws -> MadLinksAccount {
        let data = try await self.session.request(method: "POST", path: "/api/v1/me/domains/verify", body: ["domain": domain], interactive: true)
        guard let account = MadLinksParsing.account(from: data) else {
            throw MadLinksError.invalidResponse
        }
        return account
    }

    public func deleteAccount(id: String) async throws {
        _ = try await self.session.request(method: "DELETE", path: "/api/v1/me/accounts/\(self.encode(id))", interactive: true)
    }

    public func setDesign(_ design: MadLinksDesign) async throws {
        _ = try await self.session.request(method: "PUT", path: "/api/v1/me/settings", body: ["design": design.rawValue], interactive: true)
    }

    public func platforms() async throws -> [MadLinksPlatform] {
        let data = try await self.session.request(method: "GET", path: "/api/v1/platforms", interactive: true)
        guard let platforms = MadLinksParsing.platforms(from: data) else {
            throw MadLinksError.invalidResponse
        }
        return platforms
    }

    public func connectUrl(platform: String, clientId: String? = nil) async throws -> URL {
        let token = try await self.session.validToken(interactive: true)
        guard let url = MadLinksParsing.connectStartUrl(base: MadLinksConfig.baseUrl, platform: platform, token: token, clientId: clientId) else {
            throw MadLinksError.invalidResponse
        }
        return url
    }

    public func publishOwn(_ profile: MadLinksProfile) {
        MadLinksCache.shared.store(accountPeerId: self.context.account.peerId, peerId: self.context.account.peerId, profile: profile.publicProfile)
    }

    private func encode(_ id: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
    }
}

public final class MadLinksCache {
    public static let shared = MadLinksCache()
    public static let didChangeNotification = Notification.Name("MadLinksCache.didChange")

    private struct Key: Hashable {
        let account: Int64
        let peer: Int64
    }

    private struct Entry {
        let profile: MadLinksProfile?
        let timestamp: Double
    }

    private let lock = NSLock()
    private var entries: [Key: Entry] = [:]
    private var loading = Set<Key>()
    private let lifetime: Double = 600.0
    private let failureLifetime: Double = 120.0

    public func profile(accountPeerId: EnginePeer.Id, peerId: EnginePeer.Id) -> MadLinksProfile? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.entries[Key(account: accountPeerId.toInt64(), peer: peerId.toInt64())]?.profile
    }

    public func store(accountPeerId: EnginePeer.Id, peerId: EnginePeer.Id, profile: MadLinksProfile?) {
        let key = Key(account: accountPeerId.toInt64(), peer: peerId.toInt64())
        self.lock.lock()
        let previous = self.entries[key]
        self.entries[key] = Entry(profile: profile, timestamp: CFAbsoluteTimeGetCurrent())
        self.lock.unlock()
        if previous?.profile != profile {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: MadLinksCache.didChangeNotification, object: nil, userInfo: ["account": key.account, "peer": key.peer])
            }
        }
    }

    private func needsLoad(_ key: Key) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if self.loading.contains(key) {
            return false
        }
        if let entry = self.entries[key] {
            let age = CFAbsoluteTimeGetCurrent() - entry.timestamp
            if age < (entry.profile == nil ? self.failureLifetime : self.lifetime) {
                return false
            }
        }
        self.loading.insert(key)
        return true
    }

    private func finishLoading(_ key: Key) {
        self.lock.lock()
        self.loading.remove(key)
        self.lock.unlock()
    }

    public func load(context: AccountContext, peerId: EnginePeer.Id) {
        let accountPeerId = context.account.peerId
        let key = Key(account: accountPeerId.toInt64(), peer: peerId.toInt64())
        guard self.needsLoad(key) else {
            return
        }
        let api = MadLinksAPI(context: context)
        Task {
            let profile: MadLinksProfile?
            do {
                profile = try await api.profile(peerId: peerId, interactive: false)
            } catch MadLinksError.server(404) {
                profile = MadLinksProfile(design: .row, accounts: [])
            } catch {
                profile = self.profile(accountPeerId: accountPeerId, peerId: peerId)
            }
            self.store(accountPeerId: accountPeerId, peerId: peerId, profile: profile)
            self.finishLoading(key)
        }
    }

    public func profileSignal(context: AccountContext, peerId: EnginePeer.Id) -> Signal<MadLinksProfile?, NoError> {
        let accountPeerId = context.account.peerId
        return Signal { subscriber in
            subscriber.putNext(self.profile(accountPeerId: accountPeerId, peerId: peerId))
            let observer = NotificationCenter.default.addObserver(forName: MadLinksCache.didChangeNotification, object: nil, queue: nil, using: { notification in
                guard let account = notification.userInfo?["account"] as? Int64, let peer = notification.userInfo?["peer"] as? Int64 else {
                    return
                }
                if account == accountPeerId.toInt64() && peer == peerId.toInt64() {
                    subscriber.putNext(self.profile(accountPeerId: accountPeerId, peerId: peerId))
                }
            })
            self.load(context: context, peerId: peerId)
            return ActionDisposable {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        |> distinctUntilChanged
    }
}
