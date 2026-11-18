import XCTest
import TelegramCore
import TelegramUIPreferences

final class PromotedPostDetectorTests: XCTestCase {
    private let keywords = ChatContentFilterSettings.defaultPromotedPostKeywords

    private func isPromoted(_ text: String, _ entities: [MessageTextEntity] = []) -> Bool {
        return PromotedPostDetector.isPromoted(text: text, entities: entities, keywords: self.keywords)
    }

    func testHashtagAloneIsAnAd() {
        XCTAssertTrue(self.isPromoted("#реклама"))
        XCTAssertTrue(self.isPromoted("Лучший курс по свифту\n\n#Реклама"))
    }

    func testHashtagEntityIsAnAd() {
        let text = "Скидки #реклама"
        let entity = MessageTextEntity(range: 7 ..< 15, type: .Hashtag)
        XCTAssertTrue(PromotedPostDetector.isPromoted(text: text, entities: [entity], keywords: []))
    }

    func testEridMarkerIsAnAd() {
        XCTAssertTrue(self.isPromoted("Реклама. ООО «Ромашка». erid: 2VtzqvWgxEU"))
        XCTAssertTrue(self.isPromoted("ERID 2VtzquvBfzm"))
    }

    func testEridInLinkIsAnAd() {
        let text = "Подробнее"
        let entity = MessageTextEntity(range: 0 ..< 9, type: .TextUrl(url: "https://example.com/?utm_source=tg&erid=2VtzqwHkL4b"))
        XCTAssertTrue(PromotedPostDetector.isPromoted(text: text, entities: [entity], keywords: []))
    }

    func testAdvertiserTaxIdIsAnAd() {
        XCTAssertTrue(self.isPromoted("Рекламодатель ИП Иванов, ИНН 771234567890"))
        XCTAssertTrue(self.isPromoted("ИНН: 7712345678"))
    }

    func testOrdinaryPostsAreNotAds() {
        XCTAssertFalse(self.isPromoted("Сегодня вышел длинный обзор нового айфона"))
        XCTAssertFalse(self.isPromoted("Реклама в метро стала навязчивее, считают горожане"))
        XCTAssertFalse(self.isPromoted("Вериди — новый бренд из Италии"))
        XCTAssertFalse(self.isPromoted(""))
    }

    func testKeywordNeedsWordBoundary() {
        XCTAssertFalse(PromotedPostDetector.isPromoted(text: "промокод", entities: [], keywords: ["промо"]))
        XCTAssertTrue(PromotedPostDetector.isPromoted(text: "Промо: скидка 20%", entities: [], keywords: ["промо"]))
    }

    func testSpoilerRevealRemovesOnlyRequestedKinds() {
        let attributes: [EngineMessage.Attribute] = [
            TextEntitiesMessageAttribute(entities: [MessageTextEntity(range: 0 ..< 3, type: .Spoiler), MessageTextEntity(range: 0 ..< 3, type: .Bold)]),
            MediaSpoilerMessageAttribute()
        ]
        XCTAssertNil(messageAttributesRevealingSpoilers(attributes, text: false, media: false))

        let textOnly = messageAttributesRevealingSpoilers(attributes, text: true, media: false)!
        XCTAssertEqual(textOnly.count, 2)
        XCTAssertEqual((textOnly[0] as! TextEntitiesMessageAttribute).entities.map(\.type), [.Bold])
        XCTAssertTrue(textOnly[1] is MediaSpoilerMessageAttribute)

        let mediaOnly = messageAttributesRevealingSpoilers(attributes, text: false, media: true)!
        XCTAssertEqual(mediaOnly.count, 1)
        XCTAssertTrue(mediaOnly[0] is TextEntitiesMessageAttribute)
    }

    func testOlderStoredSettingsGetNewDefaults() throws {
        let decoded = try JSONDecoder().decode(ChatContentFilterSettings.self, from: Data("{\"revealTextSpoilers\":true}".utf8))
        XCTAssertTrue(decoded.revealTextSpoilers)
        XCTAssertTrue(decoded.hidePromotedPosts)
        XCTAssertTrue(decoded.hideSponsoredMessages)
        XCTAssertEqual(decoded.promotedPostKeywords, ChatContentFilterSettings.defaultPromotedPostKeywords)
    }
}
