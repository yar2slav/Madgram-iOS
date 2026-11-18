import Foundation
import UserNotifications
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramUIPreferences
import TelegramPresentationData

final class MadPresenceWatcher {
    private static var instances: [Int64: MadPresenceWatcher] = [:]

    static func attach(context: AccountContext) {
        let key = context.account.peerId.toInt64()
        if let current = MadPresenceWatcher.instances[key], current.context === context {
            return
        }
        MadPresenceWatcher.instances[key] = MadPresenceWatcher(context: context)
    }

    private let context: AccountContext
    private var disposables: [Int64: Disposable] = [:]
    private var online: [Int64: Bool] = [:]
    private var names: [Int64: String] = [:]
    private var timers: [Int64: SwiftSignalKit.Timer] = [:]
    private var observer: NSObjectProtocol?

    private init(context: AccountContext) {
        self.context = context
        self.observer = NotificationCenter.default.addObserver(forName: MadStores.presenceWatched.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.sync()
        })
        self.sync()
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
        for (_, disposable) in self.disposables {
            disposable.dispose()
        }
        for (_, timer) in self.timers {
            timer.invalidate()
        }
    }

    private func sync() {
        let watched = MadStores.presenceWatched.current
        for (key, disposable) in self.disposables where !watched.contains(key) {
            disposable.dispose()
            self.disposables.removeValue(forKey: key)
            self.online.removeValue(forKey: key)
            self.timers[key]?.invalidate()
            self.timers.removeValue(forKey: key)
        }
        for key in watched where self.disposables[key] == nil {
            let peerId = EnginePeer.Id(key)
            self.disposables[key] = (self.context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                TelegramEngine.EngineData.Item.Peer.Presence(id: peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] peer, presence in
                guard let self else {
                    return
                }
                if let peer {
                    self.names[key] = peer.compactDisplayTitle
                }
                self.update(key: key, presence: presence)
            })
        }
    }

    private func update(key: Int64, presence: EnginePeer.Presence?) {
        self.timers[key]?.invalidate()
        self.timers.removeValue(forKey: key)
        var isOnline = false
        let now = Int32(Date().timeIntervalSince1970)
        if let presence, case let .present(until) = presence.status, until > now {
            isOnline = true
            let timer = SwiftSignalKit.Timer(timeout: Double(until - now) + 1.0, repeat: false, completion: { [weak self] in
                self?.update(key: key, presence: presence)
            }, queue: Queue.mainQueue())
            self.timers[key] = timer
            timer.start()
        }
        let previous = self.online[key]
        self.online[key] = isOnline
        if let previous, previous != isOnline {
            self.notify(key: key, isOnline: isOnline)
        }
    }

    private func notify(key: Int64, isOnline: Bool) {
        let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings.localFeatures.more
        let name = self.names[key] ?? ""
        let content = UNMutableNotificationContent()
        content.title = "mad"
        content.body = isOnline ? strings.userCameOnline(name) : strings.userWentOffline(name)
        content.sound = .default
        content.threadIdentifier = "mad-presence-\(key)"
        content.userInfo = ["madAgentNote": true, "peerId": key]
        let request = UNNotificationRequest(identifier: "mad-presence-\(key)-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
