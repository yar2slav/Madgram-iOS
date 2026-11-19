#if DEBUG
import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramUIPreferences
import MadgramAgent
import MadLockUI
import MadProfileLinks
import MadProfileLinksCore

enum MadDemoMode {
    private struct Spec: Decodable {
        struct NameStyle: Decodable {
            var colors: [String]
            var effect: String?
        }
        struct Link: Decodable {
            var platform: String
            var handle: String
            var displayName: String?
            var url: String?
        }
        struct Links: Decodable {
            var design: String?
            var accounts: [Link]
        }
        struct Decoration: Decodable {
            var firstName: String?
            var lastName: String?
            var username: String?
            var avatar: String?
            var badge: String?
            var nameStyle: NameStyle?
            var links: Links?
        }
        struct Peer: Decodable {
            var key: String
            var kind: String?
            var firstName: String
            var lastName: String?
            var username: String?
            var avatar: String?
            var online: Bool?
            var lastSeenMinutesAgo: Int?
            var verified: Bool?
            var pinned: Bool?
            var unread: Int32?
            var muted: Bool?
            var locked: Bool?
            var badge: String?
            var nameStyle: NameStyle?
            var links: Links?
        }
        struct Message: Decodable {
            var chat: String
            var author: String?
            var out: Bool?
            var text: String
            var min: Int
            var deleted: Bool?
            var versions: [String]?
            var views: Int?
            var photo: String?
        }
        struct AgentTool: Decodable {
            var name: String
            var title: String
            var args: String?
        }
        struct AgentMessage: Decodable {
            var role: String
            var text: String?
            var tools: [AgentTool]?
            var min: Int?
        }
        var peers: [Peer]
        var messages: [Message]
        var me: Decoration?
        struct ScriptTool: Decodable {
            var name: String
            var args: String?
            var running: String
            var done: String
            var seconds: Double?
        }
        struct ScriptStep: Decodable {
            var think: Double?
            var tools: [ScriptTool]?
            var text: String?
            var speed: Double?
        }
        struct ScriptExchange: Decodable {
            var match: String
            var steps: [ScriptStep]
        }
        var agent: [AgentMessage]?
        var agentScript: [ScriptExchange]?
        var lockPin: String?
    }

    private static var directory: URL? {
        guard let path = UserDefaults.standard.string(forKey: "MadDemoDir"), !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private static func loadSpec() -> (URL, Spec)? {
        guard let directory = self.directory else {
            return nil
        }
        do {
            let data = try Data(contentsOf: directory.appendingPathComponent("demo.json"))
            return (directory, try JSONDecoder().decode(Spec.self, from: data))
        } catch {
            NSLog("MadDemo: failed to load spec: \(error)")
            return nil
        }
    }

    private static func peerIds(_ spec: Spec) -> [String: EnginePeer.Id] {
        var result: [String: EnginePeer.Id] = [:]
        for (index, peer) in spec.peers.enumerated() {
            let kind = MadDemo.PeerKind(rawValue: peer.kind ?? "user") ?? .user
            result[peer.key] = MadDemo.peerId(kind: kind, index: index)
        }
        return result
    }

    private static func profile(_ links: Spec.Links) -> MadLinksProfile {
        let accounts = links.accounts.enumerated().map { index, link in
            MadLinksAccount(id: "demo-\(index)", platform: link.platform, handle: link.handle, displayName: link.displayName, url: link.url, verified: true, visible: true, position: index, label: link.displayName != nil ? .name : .handle)
        }
        return MadLinksProfile(design: MadLinksDesign(rawValue: links.design ?? "row") ?? .row, accounts: accounts)
    }

    static let offlinePeerId: Int64 = 7000000001

    static func prepareOfflineAccount(accountManager: AccountManager<TelegramAccountManagerTypes>) {
        guard UserDefaults.standard.bool(forKey: "MadDemoOffline") else {
            return
        }
        let _ = accountManager.transaction { transaction -> Void in
            let deadProxy = ProxyServerSettings(host: "127.0.0.1", port: 9, connection: .socks5(username: nil, password: nil))
            let _ = updateProxySettingsInteractively(transaction: transaction, { _ in
                return ProxySettings(enabled: true, servers: [deadProxy], activeServer: deadProxy, useForCalls: false)
            })
            guard transaction.getRecords().isEmpty else {
                return
            }
            transaction.removeAuth()
            var key = Data(count: 256)
            key.withUnsafeMutableBytes { bytes in
                if let base = bytes.baseAddress {
                    arc4random_buf(base, 256)
                }
            }
            let backup = AccountBackupData(masterDatacenterId: 2, peerId: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(self.offlinePeerId)).toInt64(), masterDatacenterKey: key, masterDatacenterKeyId: Int64.random(in: 1 ..< Int64.max), notificationEncryptionKeyId: nil, notificationEncryptionKey: nil, additionalDatacenterKeys: [:])
            let id = transaction.createRecord([.backupData(AccountBackupDataAttribute(data: backup))])
            transaction.setCurrentId(id)
        }.start()
    }

    static func prepare(context: AccountContext) {
        guard let (_, spec) = self.loadSpec() else {
            return
        }
        let ids = self.peerIds(spec)
        let accountPeerId = context.account.peerId

        var badgeIds: [EnginePeer.Id: String] = [:]
        var nameStyles: [EnginePeer.Id: (colors: [String], effect: String?)] = [:]
        func decorate(_ peerId: EnginePeer.Id, badge: String?, nameStyle: Spec.NameStyle?, links: Spec.Links?) {
            if let badge {
                badgeIds[peerId] = badge
            }
            if let nameStyle {
                nameStyles[peerId] = (nameStyle.colors, nameStyle.effect)
            }
            if let links {
                MadLinksCache.shared.storeDemo(accountPeerId: accountPeerId, peerId: peerId, profile: self.profile(links))
            }
        }
        for peer in spec.peers {
            if let peerId = ids[peer.key] {
                decorate(peerId, badge: peer.badge, nameStyle: peer.nameStyle, links: peer.links)
            }
        }
        if let me = spec.me {
            decorate(accountPeerId, badge: me.badge, nameStyle: me.nameStyle, links: me.links)
        }
        PeerBadgeRegistryStore.shared.setDemoOverlay(badgeIds: badgeIds, nameStyles: nameStyles)

        let locked = spec.peers.filter { $0.locked == true }.compactMap { ids[$0.key]?.toInt64() }
        if let pin = spec.lockPin, !locked.isEmpty {
            MadLockDemo.setPin(pin)
            let _ = MadStores.lockedChats.update { _ in Set(locked) }
        }

        let _ = InterfaceTuningSettingsStore.shared.update { current in
            var updated = current
            updated.showAgentTab = true
            return updated
        }
        AgentDemoScript.exchanges = (spec.agentScript ?? []).map { exchange in
            AgentDemoScript.Exchange(match: exchange.match, steps: exchange.steps.compactMap { step -> AgentDemoScript.Step? in
                if let think = step.think {
                    return .thinking(seconds: think)
                }
                if let tools = step.tools {
                    return .tools(tools.map { (name: $0.name, arguments: $0.args ?? "{}", running: $0.running, done: $0.done, seconds: $0.seconds ?? 1.2) })
                }
                if let text = step.text {
                    return .text(text, charactersPerSecond: step.speed ?? 90)
                }
                return nil
            })
        }
        if let agent = spec.agent, !agent.isEmpty {
            let accountId = accountPeerId.toInt64()
            let conversationId = "mad-demo"
            var messages: [MadgramAgent.AgentMessage] = []
            let now = Date()
            for (index, item) in agent.enumerated() {
                let date = now.addingTimeInterval(-Double((item.min ?? (agent.count - index)) * 60))
                switch item.role {
                case "user":
                    var message = MadgramAgent.AgentMessage(role: .user, text: item.text ?? "")
                    message.date = date
                    messages.append(message)
                default:
                    if let tools = item.tools, !tools.isEmpty {
                        let calls = tools.enumerated().map { offset, tool in AgentToolCall(id: "demo-\(index)-\(offset)", name: tool.name, arguments: tool.args ?? "{}") }
                        var call = MadgramAgent.AgentMessage(role: .assistant, text: "", toolCalls: calls)
                        call.date = date
                        messages.append(call)
                        for (offset, tool) in tools.enumerated() {
                            var result = MadgramAgent.AgentMessage(role: .tool, text: "ok", toolCallId: calls[offset].id, toolTitle: tool.title)
                            result.date = date
                            messages.append(result)
                        }
                    }
                    if let text = item.text, !text.isEmpty {
                        var message = MadgramAgent.AgentMessage(role: .assistant, text: text)
                        message.date = date
                        messages.append(message)
                    }
                }
            }
            AgentConversationStore(accountId: accountId, conversationId: conversationId).save(messages)
            AgentConversations.setCurrent(accountId: accountId, id: conversationId)
        }
    }

    static func seed(context: AccountContext) {
        guard let (directory, spec) = self.loadSpec() else {
            return
        }
        let ids = self.peerIds(spec)
        func image(_ name: String?) -> Data? {
            guard let name else {
                return nil
            }
            return try? Data(contentsOf: directory.appendingPathComponent(name))
        }
        let peers: [MadDemo.Peer] = spec.peers.enumerated().map { index, peer in
            MadDemo.Peer(index: index, kind: MadDemo.PeerKind(rawValue: peer.kind ?? "user") ?? .user, firstName: peer.firstName, lastName: peer.lastName, username: peer.username, avatarJpeg: image(peer.avatar), online: peer.online ?? false, lastSeenMinutesAgo: peer.lastSeenMinutesAgo, verified: peer.verified ?? false, pinned: peer.pinned ?? false, unreadCount: peer.unread ?? 0, muted: peer.muted ?? false)
        }
        let messages: [MadDemo.Message] = spec.messages.compactMap { message in
            guard let chat = ids[message.chat] else {
                return nil
            }
            let photo = image(message.photo)
            let photoSize = photo.flatMap { UIImage(data: $0)?.size }
            return MadDemo.Message(chat: chat, author: message.author.flatMap { ids[$0] }, outgoing: message.out ?? false, text: message.text, minutesAgo: message.min, deleted: message.deleted ?? false, previousVersions: message.versions ?? [], views: message.views, photoJpeg: photo, photoSize: photoSize)
        }
        let me = spec.me.flatMap { me -> MadDemo.Peer? in
            guard let firstName = me.firstName else {
                return nil
            }
            return MadDemo.Peer(index: 0, kind: .user, firstName: firstName, lastName: me.lastName, username: me.username, avatarJpeg: image(me.avatar), online: true, lastSeenMinutesAgo: nil, verified: false, pinned: false, unreadCount: 0, muted: false)
        }
        let _ = context.engine.messages.madDemoSeed(me: me, peers: peers, messages: messages).startStandalone()
    }
}
#endif
