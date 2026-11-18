import Foundation
import TelegramCore

final class MadJoinDateCache {
    struct Entry {
        let groupTitle: String
        let date: Int32
    }

    static let shared = MadJoinDateCache()

    private let lock = NSLock()
    private var entries: [EnginePeer.Id: Entry] = [:]

    func set(userId: EnginePeer.Id, entry: Entry) {
        self.lock.lock()
        self.entries[userId] = entry
        self.lock.unlock()
    }

    func remove(userId: EnginePeer.Id) {
        self.lock.lock()
        self.entries.removeValue(forKey: userId)
        self.lock.unlock()
    }

    func entry(userId: EnginePeer.Id) -> Entry? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.entries[userId]
    }
}
