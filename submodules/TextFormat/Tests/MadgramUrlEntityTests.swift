import TelegramCore
@testable import TextFormat
import XCTest

final class MadgramUrlEntityTests: XCTestCase {
    func testMadgramLinksAreDetected() {
        let text = "Open mad://ghost and MAD://settings/interface."
        let entities = generateTextEntities(text, enabledTypes: .all)
        let urls = entities.compactMap { entity -> String? in
            guard case .Url = entity.type else {
                return nil
            }
            return String(decoding: Array(text.utf16)[entity.range], as: UTF16.self)
        }
        XCTAssertEqual(urls, ["mad://ghost", "MAD://settings/interface"])
    }

    func testMadgramRootLinkIsDetectedAsInternalUrl() {
        let text = "mad://"
        let entities = generateTextEntities(text, enabledTypes: .internalUrl)
        XCTAssertEqual(entities.count, 1)
        guard case .Url = entities[0].type else {
            return XCTFail("Expected URL entity")
        }
        XCTAssertEqual(entities[0].range, 0 ..< text.utf16.count)
    }

    func testMadgramLinksAreIgnoredWhenUrlsAreDisabled() {
        let entities = generateTextEntities("mad://ghost", enabledTypes: [.mention, .hashtag])
        XCTAssertTrue(entities.isEmpty)
    }

    func testMadgramLinkDoesNotOverlapExistingEntity() {
        let text = "mad://ghost"
        let current = MessageTextEntity(range: 0 ..< text.utf16.count, type: .TextUrl(url: "https://example.com"))
        let entities = generateTextEntities(text, enabledTypes: .all, currentEntities: [current])
        XCTAssertEqual(entities.filter {
            if case .TextUrl = $0.type {
                return true
            }
            return false
        }.count, 1)
        XCTAssertTrue(entities.filter {
            if case .Url = $0.type {
                return true
            }
            return false
        }.isEmpty)
    }

    func testMadgramLinkIsAddedToServerEntities() {
        let text = "Open mad://ghost"
        let serverEntity = MessageTextEntity(range: 0 ..< 4, type: .Bold)
        guard let entities = addLocallyGeneratedEntities(text, enabledTypes: .all, entities: [serverEntity]) else {
            return XCTFail("Expected a locally generated URL")
        }
        XCTAssertEqual(entities.count, 2)
        XCTAssertTrue(entities.contains(where: { entity in
            if case .Url = entity.type {
                return String(decoding: Array(text.utf16)[entity.range], as: UTF16.self) == "mad://ghost"
            }
            return false
        }))
    }

    func testMadgramLinkIsAddedWithoutServerEntities() {
        let text = "mad://settings/interface"
        guard let entities = addLocallyGeneratedEntities(text, enabledTypes: .allUrl, entities: []) else {
            return XCTFail("Expected a locally generated URL")
        }
        XCTAssertEqual(entities, [
            MessageTextEntity(range: 0 ..< text.utf16.count, type: .Url)
        ])
    }
}
