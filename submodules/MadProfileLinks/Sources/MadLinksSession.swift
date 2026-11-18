import Foundation
import Security
import SwiftSignalKit
import TelegramCore
import AccountContext
import MadProfileLinksCore

public enum MadLinksConfig {
    public static let botUsername = "maddtgbot"
    public static let baseUrl = URL(string: "https://b.mad.tg")!
    public static let webAppUrl = "https://b.mad.tg/tg/"
    public static let callbackScheme = "mad"
}

public enum MadLinksError: Error, Equatable {
    case botUnavailable
    case authFailed
    case unauthorized
    case network
    case server(Int)
    case invalidResponse
}

enum MadLinksKeychain {
    private static let service = "org.madgram.links"

    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func store(account: String, token: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard let token, let data = token.data(using: .utf8) else {
            return
        }
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }
}

final class MadLinksAwaitState: @unchecked Sendable {
    let lock = NSLock()
    var finished = false
    let disposable = MetaDisposable()

    func finish() -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if self.finished {
            return false
        }
        self.finished = true
        return true
    }
}

func madLinksAwait<T, E>(_ signal: Signal<T, E>, mapError: @escaping (E) -> Error) async throws -> T {
    let state = MadLinksAwaitState()
    return try await withTaskCancellationHandler(operation: {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            state.disposable.set((signal |> take(1)).start(next: { value in
                if state.finish() {
                    continuation.resume(returning: value)
                }
            }, error: { error in
                if state.finish() {
                    continuation.resume(throwing: mapError(error))
                }
            }, completed: {
                if state.finish() {
                    continuation.resume(throwing: MadLinksError.invalidResponse)
                }
            }))
        }
    }, onCancel: {
        state.disposable.dispose()
    })
}

public actor MadLinksSession {
    private static let lock = NSLock()
    private static var sessions: [Int64: MadLinksSession] = [:]

    public static func shared(context: AccountContext) -> MadLinksSession {
        let key = context.account.peerId.toInt64()
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if let current = self.sessions[key], current.engine === context.engine {
            return current
        }
        let session = MadLinksSession(context: context)
        self.sessions[key] = session
        return session
    }

    nonisolated private let engine: TelegramEngine
    private let keychainAccount: String
    private var token: String?
    private var authTask: Task<String, Error>?
    private var lastAuthFailure: Date?

    private init(context: AccountContext) {
        self.engine = context.engine
        self.keychainAccount = "\(context.account.peerId.toInt64())"
        self.token = MadLinksKeychain.load(account: self.keychainAccount)
    }

    public var hasToken: Bool {
        return self.token != nil
    }

    public func validToken(interactive: Bool) async throws -> String {
        if let token = self.token {
            return token
        }
        return try await self.authorize(interactive: interactive)
    }

    public func request(method: String, path: String, body: [String: Any]? = nil, interactive: Bool) async throws -> Data {
        let token = try await self.validToken(interactive: interactive)
        do {
            return try await self.perform(method: method, path: path, body: body, token: token)
        } catch MadLinksError.unauthorized {
            self.invalidate(token: token)
            let newToken = try await self.authorize(interactive: interactive)
            return try await self.perform(method: method, path: path, body: body, token: newToken)
        }
    }

    private func invalidate(token: String) {
        if self.token == token {
            self.token = nil
            MadLinksKeychain.store(account: self.keychainAccount, token: nil)
        }
    }

    private func authorize(interactive: Bool) async throws -> String {
        if let authTask = self.authTask {
            return try await authTask.value
        }
        if !interactive, let lastAuthFailure = self.lastAuthFailure, Date().timeIntervalSince(lastAuthFailure) < 300.0 {
            throw MadLinksError.authFailed
        }
        let engine = self.engine
        let task = Task<String, Error> {
            let initData = try await MadLinksSession.fetchInitData(engine: engine)
            return try await MadLinksSession.exchange(initData: initData)
        }
        self.authTask = task
        do {
            let token = try await task.value
            self.authTask = nil
            self.token = token
            self.lastAuthFailure = nil
            MadLinksKeychain.store(account: self.keychainAccount, token: token)
            return token
        } catch {
            self.authTask = nil
            self.lastAuthFailure = Date()
            throw error
        }
    }

    private static func fetchInitData(engine: TelegramEngine) async throws -> String {
        let resolved = engine.peers.resolvePeerByName(name: MadLinksConfig.botUsername, referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            if case let .result(peer) = result {
                return .single(peer)
            }
            return .complete()
        }
        let peer = try await madLinksAwait(resolved, mapError: { _ in MadLinksError.botUnavailable })
        guard let peer, case let .user(user) = peer, user.botInfo != nil else {
            throw MadLinksError.botUnavailable
        }
        let botId = peer.id
        let simple = engine.messages.requestSimpleWebView(botId: botId, url: MadLinksConfig.webAppUrl, source: .generic, themeParams: nil)
        if let result = try? await madLinksAwait(simple, mapError: { _ in MadLinksError.authFailed }), let initData = MadLinksParsing.initData(fromWebAppUrl: result.url) {
            return initData
        }
        let main = engine.messages.requestMainWebView(peerId: botId, botId: botId, source: .generic, themeParams: nil)
        let result = try await madLinksAwait(main, mapError: { _ in MadLinksError.authFailed })
        guard let initData = MadLinksParsing.initData(fromWebAppUrl: result.url) else {
            throw MadLinksError.authFailed
        }
        return initData
    }

    private static func exchange(initData: String) async throws -> String {
        var request = URLRequest(url: MadLinksConfig.baseUrl.appendingPathComponent("api/v1/auth/telegram"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["initData": initData], options: [])
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw MadLinksError.network
        }
        guard let http = response as? HTTPURLResponse else {
            throw MadLinksError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw MadLinksError.authFailed
        }
        guard let token = MadLinksParsing.token(from: data) else {
            throw MadLinksError.invalidResponse
        }
        return token
    }

    private func perform(method: String, path: String, body: [String: Any]?, token: String) async throws -> Data {
        guard let url = URL(string: path, relativeTo: MadLinksConfig.baseUrl) else {
            throw MadLinksError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw MadLinksError.network
        }
        guard let http = response as? HTTPURLResponse else {
            throw MadLinksError.invalidResponse
        }
        if http.statusCode == 401 {
            throw MadLinksError.unauthorized
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw MadLinksError.server(http.statusCode)
        }
        return data
    }
}
