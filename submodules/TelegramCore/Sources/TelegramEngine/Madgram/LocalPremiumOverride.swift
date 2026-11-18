import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

public final class LocalPremiumOverride {
    private struct StoredSettings: Decodable {
        var isEnabled: Bool
    }

    fileprivate struct EmojiStatusEntry: Codable {
        var status: PeerEmojiStatus?
    }

    private static let settingsKey = "localPremiumSettings.v1"
    private static let emojiStatusesKey = "localPremiumOverride.emojiStatuses.v1"
    private static let lock = NSLock()
    private static var accountPeerIds = Set<PeerId>()

    public static var isEnabled: Bool {
        guard let data = UserDefaults.standard.data(forKey: settingsKey), let settings = try? JSONDecoder().decode(StoredSettings.self, from: data) else {
            return false
        }
        return settings.isEnabled
    }

    static func registerAccountPeerId(_ peerId: PeerId) {
        lock.lock()
        accountPeerIds.insert(peerId)
        lock.unlock()
    }

    static func isAccountPeer(_ peerId: PeerId) -> Bool {
        lock.lock()
        defer {
            lock.unlock()
        }
        return accountPeerIds.contains(peerId)
    }

    private static func emojiStatuses() -> [String: EmojiStatusEntry] {
        guard let data = UserDefaults.standard.data(forKey: emojiStatusesKey), let value = try? JSONDecoder().decode([String: EmojiStatusEntry].self, from: data) else {
            return [:]
        }
        return value
    }

    fileprivate static func emojiStatusEntry(peerId: PeerId) -> EmojiStatusEntry? {
        return emojiStatuses()["\(peerId.toInt64())"]
    }

    static func setEmojiStatus(_ status: PeerEmojiStatus?, peerId: PeerId) {
        lock.lock()
        var value = emojiStatuses()
        value["\(peerId.toInt64())"] = EmojiStatusEntry(status: status)
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: emojiStatusesKey)
        }
        lock.unlock()
    }

    static func apply(_ peer: Peer) -> Peer {
        guard let user = peer as? TelegramUser, user.botInfo == nil, isEnabled, isAccountPeer(user.id) else {
            return peer
        }
        var result = user
        if !result.flags.contains(.isPremium) {
            result = result.withUpdatedFlags(result.flags.union(.isPremium))
        }
        if let entry = emojiStatusEntry(peerId: user.id) {
            var status = entry.status
            if let expirationDate = status?.expirationDate, expirationDate <= Int32(Date().timeIntervalSince1970) {
                status = nil
            }
            if status != result.emojiStatus {
                result = result.withUpdatedEmojiStatus(status)
            }
        }
        return result
    }
}

func _internal_applyLocalPremiumOverride(account: Account) -> Signal<Never, NoError> {
    let peerId = account.peerId
    let localApply: Signal<Never, NoError> = account.postbox.transaction { transaction -> Void in
        if let peer = transaction.getPeer(peerId) {
            updatePeersCustom(transaction: transaction, peers: [peer], update: { _, updated in
                return updated
            })
        }
    }
    |> ignoreValues
    if LocalPremiumOverride.isEnabled {
        return localApply
    }
    let remoteRefresh: Signal<Never, NoError> = account.network.request(Api.functions.users.getUsers(id: [.inputUserSelf]))
    |> map { users -> [Api.User]? in
        return users
    }
    |> `catch` { _ -> Signal<[Api.User]?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { users -> Signal<Never, NoError> in
        guard let users, let apiUser = users.first else {
            return .complete()
        }
        return account.postbox.transaction { transaction -> Void in
            updatePeersCustom(transaction: transaction, peers: [TelegramUser(user: apiUser)], update: { _, updated in
                return updated
            })
        }
        |> ignoreValues
    }
    return localApply |> then(remoteRefresh)
}

func _internal_serverPremiumStatus(account: Account) -> Signal<Bool?, NoError> {
    return account.network.request(Api.functions.users.getUsers(id: [.inputUserSelf]))
    |> map { users -> Bool? in
        guard let apiUser = users.first else {
            return nil
        }
        return TelegramUser(user: apiUser).flags.contains(.isPremium)
    }
    |> `catch` { _ -> Signal<Bool?, NoError> in
        return .single(nil)
    }
}
