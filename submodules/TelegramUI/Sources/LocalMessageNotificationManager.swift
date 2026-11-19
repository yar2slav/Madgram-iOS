import Foundation
import UIKit
import UserNotifications
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import AccountContext
import PlatformRestrictionMatching
import MadgramText

/// A fallback for sideloaded builds: it can notify only while iOS lets the process run.
/// It never requests background audio or changes the normal APNs registration.
final class LocalMessageNotificationManager {
    private let context: AccountContext
    private let center = UNUserNotificationCenter.current()
    private let deliveryState = LocalNotificationDeliveryState()
    private let disposables = DisposableSet()
    private var settings = InAppNotificationSettings.defaultSettings
    private var inForeground = true
    private var isCurrentAccount = false
    private var isLocked = true
    private var backgroundSince: Int32?
    private var foregroundSince: Int32?
    private var session: UInt64 = 0
    private var requestIdentifiers = Set<String>()

    init(context: AccountContext) {
        self.context = context
        self.disposables.add((context.sharedContext.applicationBindings.applicationInForeground
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self else { return }
            self.inForeground = value
            self.backgroundSince = value ? nil : Int32(Date().timeIntervalSince1970)
            self.foregroundSince = value ? Int32(Date().timeIntervalSince1970) : nil
            self.cancelPending()
        }))
        self.disposables.add((context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
        |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let self else { return }
            let settings = data.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) ?? .defaultSettings
            if self.settings != settings {
                self.settings = settings
                self.cancelPending()
            }
        }))
        self.disposables.add((context.sharedContext.activeAccountContexts
        |> map { primary, _, _ in primary?.account.id == context.account.id }
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] isCurrent in
            guard let self else { return }
            self.isCurrentAccount = isCurrent
            if !isCurrent {
                self.cancelPending()
            }
        }))
        self.disposables.add((context.sharedContext.appLockContext.isPasscodeLocked
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] locked in
            guard let self else { return }
            self.isLocked = locked
            self.cancelPending()
        }))
    }

    deinit {
        self.disposables.dispose()
        self.center.removePendingNotificationRequests(withIdentifiers: Array(self.requestIdentifiers))
    }

    private var canNotify: Bool {
        return self.settings.useLocalNotifications && !self.inForeground && self.isCurrentAccount && UIApplication.shared.applicationState == .background
    }

    private func cancelPending() {
        self.session &+= 1
        self.deliveryState.cancelPending()
        self.center.removePendingNotificationRequests(withIdentifiers: Array(self.requestIdentifiers))
        self.requestIdentifiers.removeAll()
    }

    private func deliveryKey(_ message: EngineRawMessage) -> String {
        return "m\(message.id.peerId.toInt64()):\(message.id.namespace):\(message.id.id)_local_\(self.context.account.id.int64)"
    }

    func suppressesInAppNotification(for messages: [EngineRawMessage]) -> Bool {
        guard self.settings.useLocalNotifications else {
            return false
        }
        let now = ProcessInfo.processInfo.systemUptime
        for message in messages {
            if self.deliveryState.wasDelivered(self.deliveryKey(message), now: now) {
                return true
            }
            if let foregroundSince = self.foregroundSince, message.timestamp < foregroundSince - 1 {
                return true
            }
        }
        return false
    }

    static let readCheckDelay: Double = 4.0

    func enqueue(messages: [EngineRawMessage], notify: Bool) {
        guard self.canNotify, notify, let backgroundSince = self.backgroundSince else { return }
        for message in messages {
            guard message.flags.contains(.Incoming), message.timestamp >= backgroundSince else { continue }
            let key = self.deliveryKey(message)
            guard let token = self.deliveryState.reserve(key, now: ProcessInfo.processInfo.systemUptime) else { continue }
            let session = self.session
            let engine = self.context.engine
            let messageId = message.id
            let _ = (Signal<Void, NoError>.single(Void())
            |> delay(LocalMessageNotificationManager.readCheckDelay, queue: .mainQueue())
            |> mapToSignal { _ in
                return engine.messages.localNotificationMessage(id: messageId)
            }
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let self, self.canNotify, self.session == session, self.deliveryState.isPending(key, token: token) else { return }
                guard result.notify, let message = result.message, self.isVisible(message) else {
                    self.deliveryState.complete(key, token: token, delivered: false, now: ProcessInfo.processInfo.systemUptime)
                    return
                }
                let content = self.content(message: message, sound: result.sound, displayContents: result.displayContents, threadData: result.threadData)
                // Let a normal push win if it has already arrived; the delay also lets a
                // quick return to the app cancel the local banner before it is delivered.
                self.center.getDeliveredNotifications { [weak self] notifications in
                    Queue.mainQueue().async {
                        guard let self, self.canNotify, self.session == session else { return }
                        if notifications.contains(where: { self.matches($0.request.content.userInfo, message: message) }) {
                            self.deliveryState.complete(key, token: token, delivered: true, now: ProcessInfo.processInfo.systemUptime)
                            return
                        }
                        let identifier = key + "_\(session)"
                        if self.requestIdentifiers.count >= 400, let first = self.requestIdentifiers.first {
                            self.requestIdentifiers.remove(first)
                        }
                        self.requestIdentifiers.insert(identifier)
                        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false))
                        let center = self.center
                        center.add(request) { [weak self] error in
                            Queue.mainQueue().async {
                                guard let self, self.canNotify, self.session == session else {
                                    center.removePendingNotificationRequests(withIdentifiers: [identifier])
                                    return
                                }
                                self.deliveryState.complete(key, token: token, delivered: error == nil, now: ProcessInfo.processInfo.systemUptime)
                                if error != nil {
                                    self.requestIdentifiers.remove(identifier)
                                    Logger.shared.log("LocalNotifications", "Could not schedule notification")
                                }
                            }
                        }
                    }
                }
            })
        }
    }

    private func isVisible(_ message: EngineMessage) -> Bool {
        let filter = MessageFilterSettingsStore.shared.current
        var authorIds = message.author.map { [$0.id.toInt64()] } ?? []
        if message.id.peerId.isReplies, let author = message.forwardInfo?.author {
            authorIds.append(author.id.toInt64())
        }
        guard !filter.visibleNotificationMessages([message], authorIds: { _ in authorIds }).isEmpty else { return false }
        let madRulesSource = ChatContentFilterSettingsStore.shared.current.hiddenRulesSource
        if !madRulesSource.isEmpty, InterfaceTuningSettingsStore.shared.cached.sub(.hiddenRulesNotifications), message.flags.contains(.Incoming), MadHideRuleSet.cached(madRulesSource).matches(message.text) { return false }
        if message.forwardInfo?.flags.contains(.isImported) == true { return false }
        if message._asMessage().restrictionReason(platform: "ios", contentSettings: self.context.currentContentSettings.with { $0 }) != nil { return false }
        if let peer = message.peers[message.id.peerId], EnginePeer(peer).restrictionText(platform: "ios", contentSettings: self.context.currentContentSettings.with { $0 }) != nil { return false }
        for media in message.media {
            if let action = media as? TelegramMediaAction {
                switch action.action {
                case .messageAutoremoveTimeoutUpdated, .conferenceCall: return false
                default: break
                }
            }
        }
        return true
    }

    private func content(message: EngineMessage, sound: PeerMessageSound, displayContents: Bool, threadData: EngineMessageHistoryThreadData?) -> UNMutableNotificationContent {
        let data = self.context.sharedContext.currentPresentationData.with { $0 }
        let content = UNMutableNotificationContent()
        content.title = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String) ?? "Telegram"
        content.body = data.strings.PUSH_ENCRYPTED_MESSAGE("").string
        var userInfo: [AnyHashable: Any] = [
            "accountId": self.context.account.id.int64,
            "peerId": message.id.peerId.toInt64(),
            "messageId.namespace": message.id.namespace,
            "messageId.id": message.id.id,
            "localNotification": true
        ]
        if threadData != nil, let threadId = message.threadId {
            userInfo["threadId"] = threadId
        }
        content.userInfo = userInfo
        content.threadIdentifier = "local_\(self.context.account.id.int64)_\(message.id.peerId.toInt64())_\(message.threadId ?? 0)"
        content.categoryIdentifier = "unknown"
        if !self.isLocked && self.settings.displayNameOnLockscreen {
            if let peer = message.peers[message.id.peerId] {
                content.title = EnginePeer(peer).displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder)
            }
            let hasSpoiler = message.attributes.contains { attribute in
                return (attribute as? TextEntitiesMessageAttribute)?.entities.contains(where: { entity in
                    if case .Spoiler = entity.type { return true }
                    return false
                }) ?? false
            }
            if MadChatLockSession.shared.isLockedChat(peerId: message.id.peerId.toInt64()) {
                content.body = data.strings.localFeatures.more.lockedChatPreview
            } else if displayContents && !hasSpoiler && !message.containsSecretMedia {
                content.body = String(descriptionStringForMessage(contentSettings: self.context.currentContentSettings.with { $0 }, message: message, strings: data.strings, nameDisplayOrder: data.nameDisplayOrder, dateTimeFormat: data.dateTimeFormat, accountPeerId: self.context.account.peerId).0.string.prefix(160))
                if let author = message.author, author.id != message.id.peerId {
                    content.body = author.displayTitle(strings: data.strings, displayOrder: data.nameDisplayOrder) + ": " + content.body
                }
            }
        }
        switch sound {
        case .none:
            break
        default:
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "0.m4a"))
        }
        return content
    }

    private func matches(_ payload: [AnyHashable: Any], message: EngineMessage) -> Bool {
        let accountId = (payload["accountId"] as? NSNumber)?.int64Value ?? (payload["accountId"] as? String).flatMap(Int64.init)
        let peerId = (payload["peerId"] as? NSNumber)?.int64Value ?? (payload["peerId"] as? String).flatMap(Int64.init)
        let messageId = (payload["messageId.id"] as? NSNumber)?.int32Value ?? (payload["msg_id"] as? String).flatMap(Int32.init)
        return accountId == self.context.account.id.int64 && peerId == message.id.peerId.toInt64() && messageId == message.id.id
    }
}
