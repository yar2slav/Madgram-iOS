import XCTest
import TelegramCore
import MadgramText

final class MadLinkCleanerTests: XCTestCase {
    func testGlobalParams() {
        XCTAssertEqual(MadLinkCleaner.clean(url: "https://example.com/a?utm_source=tg&id=5&fbclid=xx"), "https://example.com/a?id=5")
        XCTAssertEqual(MadLinkCleaner.clean(url: "https://example.com/a?utm_source=tg"), "https://example.com/a")
    }

    func testProviderParams() {
        XCTAssertEqual(MadLinkCleaner.clean(url: "https://open.spotify.com/track/1?si=abc&context=x"), "https://open.spotify.com/track/1")
        XCTAssertEqual(MadLinkCleaner.clean(url: "https://youtu.be/xyz?si=abc&t=10"), "https://youtu.be/xyz?t=10")
        XCTAssertEqual(MadLinkCleaner.clean(url: "https://x.com/a/status/1?s=20&t=abc"), "https://x.com/a/status/1")
    }

    func testAmazonPath() {
        XCTAssertEqual(MadLinkCleaner.clean(url: "https://www.amazon.com/dp/B0/ref=sr_1_1?tag=aff&keywords=a"), "https://www.amazon.com/dp/B0?keywords=a")
    }

    func testTelegramUntouched() {
        let url = "https://t.me/channel/1?utm_source=x"
        XCTAssertEqual(MadLinkCleaner.clean(url: url), url)
    }

    func testFragment() {
        XCTAssertEqual(MadLinkCleaner.clean(url: "https://example.com/#utm_source=a&utm_medium=b"), "https://example.com/")
    }

    func testLoose() {
        XCTAssertEqual(MadLinkCleaner.cleanLoose("example.com/a?utm_source=x"), "example.com/a")
    }

    func testTextWithEntities() {
        let text = "смотри https://example.com/a?utm_source=tg круто"
        let bold = MessageTextEntity(range: 0 ..< 6, type: .Bold)
        let after = MessageTextEntity(range: 43 ..< 48, type: .Italic)
        let result = MadLinkCleaner.clean(text: text, entities: [bold, after])
        XCTAssertEqual(result.text, "смотри https://example.com/a круто")
        XCTAssertEqual(result.entities[0].range, 0 ..< 6)
        XCTAssertEqual(result.entities[1].range, 29 ..< 34)
    }

    func testTextUrlEntity() {
        let entity = MessageTextEntity(range: 0 ..< 3, type: .TextUrl(url: "https://example.com/?fbclid=1"))
        let result = MadLinkCleaner.clean(text: "тык", entities: [entity])
        XCTAssertEqual(result.entities.first?.type, .TextUrl(url: "https://example.com/"))
    }

    func testCodeSkipped() {
        let text = "https://example.com/?utm_source=x"
        let code = MessageTextEntity(range: 0 ..< (text as NSString).length, type: .Code)
        XCTAssertEqual(MadLinkCleaner.clean(text: text, entities: [code]).text, text)
    }
}

final class MadForeignAgentStripperTests: XCTestCase {
    func testDisclaimerRemoved() {
        let text = "НАСТОЯЩИЙ МАТЕРИАЛ (ИНФОРМАЦИЯ) ПРОИЗВЕДЕН И (ИЛИ) РАСПРОСТРАНЕН ИНОСТРАННЫМ АГЕНТОМ ИВАНОВЫМ ИВАНОМ ЛИБО КАСАЕТСЯ ДЕЯТЕЛЬНОСТИ ИНОСТРАННОГО АГЕНТА ИВАНОВА ИВАНА. 18+\n\nНовости дня"
        let result = MadForeignAgentStripper.strip(text: text, entities: [])
        XCTAssertEqual(result?.text, "Новости дня")
    }

    func testFootnoteRemoved() {
        let text = "Пост про что-то\n* номер в списке Минюста 777"
        XCTAssertEqual(MadForeignAgentStripper.strip(text: text, entities: [])?.text, "Пост про что-то")
    }

    func testEntitiesShift() {
        let text = "ДАННОЕ СООБЩЕНИЕ (МАТЕРИАЛ) СОЗДАНО И (ИЛИ) РАСПРОСТРАНЕНО ИНОСТРАННЫМ СРЕДСТВОМ МАССОВОЙ ИНФОРМАЦИИ.\nжир"
        let length = (text as NSString).length
        let bold = MessageTextEntity(range: (length - 3) ..< length, type: .Bold)
        let result = MadForeignAgentStripper.strip(text: text, entities: [bold])
        XCTAssertEqual(result?.text, "жир")
        XCTAssertEqual(result?.entities.first?.range, 0 ..< 3)
    }

    func testPlainUntouched() {
        XCTAssertNil(MadForeignAgentStripper.strip(text: "обычный текст про агентов", entities: []))
    }

    func testOnlyDisclaimerKept() {
        XCTAssertNil(MadForeignAgentStripper.strip(text: "18+", entities: []))
    }
}

final class MadHideRulesTests: XCTestCase {
    func testSubstringAndRegex() {
        let set = MadHideRuleSet(source: "крипта\n/бесплатн\\w+/i\n\n/(/")
        XCTAssertTrue(set.matches("лучшая КРИПТА тут"))
        XCTAssertTrue(set.matches("Бесплатные курсы"))
        XCTAssertFalse(set.matches("привет"))
        XCTAssertEqual(set.errors.map(\.line), [4])
    }
}

final class MadInvisibleCharsTests: XCTestCase {
    func testVisualize() {
        XCTAssertEqual(MadInvisibleChars.visualize("\u{3164}\u{200B}"), "⟨U+3164⟩⟨U+200B⟩")
        XCTAssertNil(MadInvisibleChars.visualize("Вова"))
    }
}

final class MadTextEditingTests: XCTestCase {
    func testRemoveMiddle() {
        let entity = MessageTextEntity(range: 0 ..< 10, type: .Bold)
        let result = MadTextEditing.removing([NSRange(location: 2, length: 3)], text: "0123456789", entities: [entity])
        XCTAssertEqual(result.text, "0156789")
        XCTAssertEqual(result.entities.first?.range, 0 ..< 7)
    }

    func testRemoveWholeEntity() {
        let entity = MessageTextEntity(range: 2 ..< 5, type: .Bold)
        let result = MadTextEditing.removing([NSRange(location: 2, length: 3)], text: "0123456789", entities: [entity])
        XCTAssertTrue(result.entities.isEmpty)
    }
}

final class MadMarkdownTests: XCTestCase {
    func testInline() {
        let result = MadMarkdown.parse("привет **жир** и `код` и *курсив*")
        XCTAssertEqual(result.text, "привет жир и код и курсив")
        XCTAssertEqual(result.entities.map(\.range), [7 ..< 10, 13 ..< 16, 19 ..< 25])
        XCTAssertEqual(result.entities.map(\.type), [.Bold, .Code, .Italic])
    }

    func testQuoteAndCode() {
        let result = MadMarkdown.parse("> цитата\n> вторая\n```swift\nlet a = 1\n```\nконец")
        XCTAssertEqual(result.text, "цитата\nвторая\nlet a = 1\nконец")
        XCTAssertEqual(result.entities.first?.type, .BlockQuote(isCollapsed: false))
        XCTAssertEqual(result.entities.first?.range, 0 ..< 13)
        XCTAssertEqual(result.entities[1].type, .Pre(language: "swift"))
    }

    func testSnakeCaseUntouched() {
        XCTAssertEqual(MadMarkdown.parse("some_snake_case 2*3*4").text, "some_snake_case 2*3*4")
    }

    func testLinkAndSpoiler() {
        let result = MadMarkdown.parse("[сайт](https://example.com) ||тайна||")
        XCTAssertEqual(result.text, "сайт тайна")
        XCTAssertEqual(result.entities.map(\.type), [.TextUrl(url: "https://example.com"), .Spoiler])
    }
}
