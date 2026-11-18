import XCTest
import ChatExport

final class ChatExportTests: XCTestCase {
    private let labels = ChatExportLabels(deleted: "deleted", edited: "edited", editHistory: "before", media: "media", reply: "reply to", forwarded: "forwarded from")

    private func sampleChat() -> ChatExportChat {
        let first = ChatExportMessage(id: 1, date: 0, editDate: 60, fromName: "Alice", fromId: "user1", isOutgoing: false, parts: chatExportTextParts(text: "hi <b>", entities: [(range: 0 ..< 2, kind: .bold)]), mediaType: nil, fileName: nil, replyToMessageId: nil, forwardedFrom: nil, isDeleted: false, editHistory: [ChatExportVersion(date: 30, text: "hey")])
        let second = ChatExportMessage(id: 2, date: 120, editDate: nil, fromName: "Bob", fromId: "user2", isOutgoing: true, parts: chatExportTextParts(text: "gone", entities: []), mediaType: "photo", fileName: nil, replyToMessageId: 1, forwardedFrom: nil, isDeleted: true, editHistory: [])
        return ChatExportChat(name: "Test", type: "personal_chat", id: 42, messages: [first, second])
    }

    func testTextPartsSplitAroundEntities() {
        let parts = chatExportTextParts(text: "a bold 🙂 end", entities: [(range: 2 ..< 6, kind: .bold), (range: 7 ..< 9, kind: .italic)])
        XCTAssertEqual(parts.map(\.text), ["a ", "bold", " ", "🙂", " end"])
        XCTAssertEqual(parts[1].kind, .bold)
        XCTAssertEqual(parts[3].kind, .italic)
    }

    func testOverlappingEntitiesKeepOutermost() {
        let parts = chatExportTextParts(text: "abcdef", entities: [(range: 0 ..< 6, kind: .bold), (range: 1 ..< 3, kind: .italic)])
        XCTAssertEqual(parts, [ChatExportTextPart(kind: .bold, text: "abcdef")])
    }

    func testJsonHasDesktopShape() throws {
        let renderer = ChatExportRenderer(labels: self.labels, timeZone: TimeZone(identifier: "UTC")!)
        let object = try JSONSerialization.jsonObject(with: renderer.renderJson(self.sampleChat())) as! [String: Any]
        XCTAssertEqual(object["name"] as? String, "Test")
        XCTAssertEqual(object["id"] as? Int, 42)
        let messages = object["messages"] as! [[String: Any]]
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["date"] as? String, "1970-01-01T00:00:00")
        XCTAssertEqual(messages[0]["edited_unixtime"] as? String, "60")
        XCTAssertNotNil(messages[0]["text"] as? [Any])
        XCTAssertEqual((messages[0]["edit_history"] as? [[String: Any]])?.first?["text"] as? String, "hey")
        XCTAssertEqual(messages[1]["text"] as? String, "gone")
        XCTAssertEqual(messages[1]["deleted"] as? Bool, true)
        XCTAssertEqual(messages[1]["reply_to_message_id"] as? Int, 1)
        XCTAssertEqual(messages[1]["media_type"] as? String, "photo")
    }

    func testHtmlEscapesText() {
        let html = ChatExportRenderer(labels: self.labels).renderHtml(self.sampleChat())
        XCTAssertTrue(html.contains("<b>hi</b> &lt;b&gt;"))
        XCTAssertTrue(html.contains("class=\"message out deleted\""))
        XCTAssertFalse(html.contains("hi <b>"))
    }

    func testTextMarksDeletedAndEdited() {
        let text = ChatExportRenderer(labels: self.labels, timeZone: TimeZone(identifier: "UTC")!).renderText(self.sampleChat())
        XCTAssertTrue(text.contains("[1970-01-01 00:00:00] Alice (edited): hi <b>"))
        XCTAssertTrue(text.contains("before [1970-01-01 00:00:30]: hey"))
        XCTAssertTrue(text.contains("Bob (deleted): reply to #1\n[media: photo]\ngone"))
    }
}
