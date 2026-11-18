import Foundation

public enum AgentInbox {
    public static let didChangeNotification = Notification.Name("MadgramAgentInboxDidChange")

    private static func unreadKey(_ accountId: Int64) -> String {
        return "madgram.agent.unread.\(accountId)"
    }

    public static func unreadCount(accountId: Int64) -> Int {
        return UserDefaults.standard.integer(forKey: self.unreadKey(accountId))
    }

    public static func markRead(accountId: Int64) {
        guard self.unreadCount(accountId: accountId) != 0 else {
            return
        }
        UserDefaults.standard.removeObject(forKey: self.unreadKey(accountId))
        NotificationCenter.default.post(name: self.didChangeNotification, object: nil, userInfo: ["accountId": accountId])
    }

    public static func post(accountId: Int64, text: String, countsAsUnread: Bool) {
        var message = AgentMessage(role: .assistant, text: text)
        message.isNotice = true
        let store = AgentConversationStore(accountId: accountId)
        var messages = store.load()
        messages.append(message)
        store.save(messages)
        if countsAsUnread {
            UserDefaults.standard.set(self.unreadCount(accountId: accountId) + 1, forKey: self.unreadKey(accountId))
        }
        NotificationCenter.default.post(name: self.didChangeNotification, object: nil, userInfo: ["accountId": accountId, "conversationId": store.conversationId, "message": message])
    }
}
