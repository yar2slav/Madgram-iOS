import Foundation
import UIKit
import UserNotifications
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences

final class MadReactionNotifier {
    private static var instances: [Int64: MadReactionNotifier] = [:]

    static func attach(context: AccountContext) {
        let key = context.account.peerId.toInt64()
        if let current = MadReactionNotifier.instances[key], current.context === context {
            return
        }
        MadReactionNotifier.instances[key] = MadReactionNotifier(context: context)
    }

    private let context: AccountContext
    private var disposable: Disposable?
    private var settings: EngineGlobalNotificationSettings.ReactionSettings?
    private var settingsDisposable: Disposable?
    private var recent: [String: Double] = [:]

    private init(context: AccountContext) {
        self.context = context
        self.settingsDisposable = (context.engine.data.subscribe(TelegramEngine.EngineData.Item.NotificationSettings.Global())
        |> deliverOnMainQueue).start(next: { [weak self] settings in
            self?.settings = settings.reactionSettings
        })
        self.disposable = (context.account.stateManager.reactionNotifications
        |> deliverOnMainQueue).start(next: { [weak self] events in
            for event in events {
                self?.handle(author: EnginePeer(event.reactionAuthor), reaction: event.reaction, message: EngineMessage(event.message))
            }
        })
    }

    deinit {
        self.disposable?.dispose()
        self.settingsDisposable?.dispose()
    }

    private func handle(author: EnginePeer, reaction: MessageReaction.Reaction, message: EngineMessage) {
        guard let settings = self.settings, settings.messages != .nobody else {
            return
        }
        guard UIApplication.shared.applicationState != .active else {
            return
        }
        if author.id == self.context.account.peerId {
            return
        }
        let now = CFAbsoluteTimeGetCurrent()
        self.recent = self.recent.filter { now - $0.value < 60.0 }
        let key = "\(message.id.peerId.toInt64())-\(message.id.id)-\(author.id.toInt64())-\(reaction)"
        if self.recent[key] != nil {
            return
        }
        self.recent[key] = now
        if settings.messages == .contacts {
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.IsContact(id: author.id))
            |> deliverOnMainQueue).start(next: { [weak self] isContact in
                if isContact {
                    self?.post(author: author, reaction: reaction, message: message, settings: settings)
                }
            })
        } else {
            self.post(author: author, reaction: reaction, message: message, settings: settings)
        }
    }

    private func post(author: EnginePeer, reaction: MessageReaction.Reaction, message: EngineMessage, settings: EngineGlobalNotificationSettings.ReactionSettings) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings.localFeatures.more
        let reactionText: String
        switch reaction {
        case let .builtin(value):
            reactionText = value
        case .custom:
            reactionText = "⭐️"
        case .stars:
            reactionText = "⭐️"
        }
        let hasSpoiler = message.attributes.contains { attribute in
            return (attribute as? TextEntitiesMessageAttribute)?.entities.contains(where: { entity in
                if case .Spoiler = entity.type { return true }
                return false
            }) ?? false
        }
        let isLockedChat = MadChatLockSession.shared.isLockedChat(peerId: message.id.peerId.toInt64())
        var text = message.text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        if text.count > 60 {
            text = String(text.prefix(60)) + "…"
        }
        if text.isEmpty || hasSpoiler || isLockedChat {
            text = strings.reactionNotificationMessage
        }
        let content = UNMutableNotificationContent()
        if settings.hideSender == .hide {
            content.title = strings.reactionNotificationTitle
        } else {
            var title = author.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            if message.id.peerId != author.id, let chat = message.peers[message.id.peerId] {
                title += " → " + EnginePeer(chat).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            }
            content.title = title
        }
        content.body = strings.reactionNotification(reactionText, text)
        content.sound = .default
        content.threadIdentifier = "mad-reaction-\(message.id.peerId.toInt64())"
        content.userInfo = ["madAgentNote": true, "peerId": message.id.peerId.toInt64()]
        let request = UNNotificationRequest(identifier: "mad-reaction-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
