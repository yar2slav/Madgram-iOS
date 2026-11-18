import Foundation

public enum MadChangelogPreferences {
    public static let didChangeNotification = Notification.Name("MadChangelogPreferencesDidChange")

    private static func key(_ name: String, _ accountId: Int64) -> String {
        return "madgram.changelog.\(name).\(accountId)"
    }

    public static func isHidden(accountId: Int64) -> Bool {
        return UserDefaults.standard.bool(forKey: self.key("hidden", accountId))
    }

    public static func setHidden(_ value: Bool, accountId: Int64) {
        UserDefaults.standard.set(value, forKey: self.key("hidden", accountId))
        NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
    }

    public static func isSilent(accountId: Int64) -> Bool {
        return UserDefaults.standard.bool(forKey: self.key("silent", accountId))
    }

    public static func setSilent(_ value: Bool, accountId: Int64) {
        UserDefaults.standard.set(value, forKey: self.key("silent", accountId))
        NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
    }

    public static func postedVersion(accountId: Int64) -> String? {
        return UserDefaults.standard.string(forKey: self.key("version", accountId))
    }

    public static func messageIds(accountId: Int64) -> [(namespace: Int32, id: Int32)] {
        guard let value = UserDefaults.standard.array(forKey: self.key("messages", accountId)) as? [Int], value.count % 2 == 0 else {
            return []
        }
        return stride(from: 0, to: value.count, by: 2).map { (Int32(value[$0]), Int32(value[$0 + 1])) }
    }

    public static func setPosted(version: String, messageIds: [(Int32, Int32)], accountId: Int64) {
        UserDefaults.standard.set(version, forKey: self.key("version", accountId))
        UserDefaults.standard.set(messageIds.flatMap { [Int($0.0), Int($0.1)] }, forKey: self.key("messages", accountId))
        UserDefaults.standard.removeObject(forKey: self.key("message", accountId))
    }
}
