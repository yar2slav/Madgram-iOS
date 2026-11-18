import Foundation
import Postbox

public final class MadMediaUploadDates {
    public static let shared = MadMediaUploadDates()

    private let lock = NSLock()
    private var dates: [MediaId: Int32] = [:]

    func set(_ id: MediaId, date: Int32) {
        guard date != 0 else {
            return
        }
        self.lock.lock()
        if self.dates.count > 50000 {
            self.dates.removeAll()
        }
        self.dates[id] = date
        self.lock.unlock()
    }

    public func date(for id: EngineMedia.Id) -> Int32? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.dates[id]
    }
}
