import XCTest
import MadProfileLinksCore

final class MadProfileLinksTests: XCTestCase {
    func testInitDataFromFragment() {
        let initData = "query_id=AAH&user=%7B%22id%22%3A42%2C%22first_name%22%3A%22a%26b%22%7D&auth_date=1700000000&hash=abc123"
        let encoded = initData.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let url = "https://b.mad.tg/tg/#tgWebAppData=\(encoded)&tgWebAppVersion=8.0&tgWebAppPlatform=ios"
        XCTAssertEqual(MadLinksParsing.initData(fromWebAppUrl: url), initData)
    }

    func testInitDataNotFirstParameter() {
        let url = "https://b.mad.tg/tg/?x=1#tgWebAppVersion=8.0&tgWebAppData=user%3D1%26hash%3Dff&tgWebAppPlatform=ios"
        XCTAssertEqual(MadLinksParsing.initData(fromWebAppUrl: url), "user=1&hash=ff")
    }

    func testInitDataMissing() {
        XCTAssertNil(MadLinksParsing.initData(fromWebAppUrl: "https://b.mad.tg/tg/"))
        XCTAssertNil(MadLinksParsing.initData(fromWebAppUrl: "https://b.mad.tg/tg/#tgWebAppVersion=8.0"))
        XCTAssertNil(MadLinksParsing.initData(fromWebAppUrl: "https://b.mad.tg/tg/#tgWebAppData="))
    }

    func testToken() {
        XCTAssertEqual(MadLinksParsing.token(from: Data("{\"token\":\"t.1\"}".utf8)), "t.1")
        XCTAssertNil(MadLinksParsing.token(from: Data("{\"token\":\"\"}".utf8)))
        XCTAssertNil(MadLinksParsing.token(from: Data("nope".utf8)))
    }

    func testPublicProfile() {
        let json = """
        {"design":"list","accounts":[
          {"id":7,"platform":"github","handle":"yaroslavmad","displayName":"Yaroslav","url":"https://github.com/yaroslavmad","verified":true},
          {"id":"3","platform":"steam","handle":"carcosa","displayName":null,"url":"https://steamcommunity.com/id/carcosa","verified":1},
          {"id":9,"handle":"broken"}
        ]}
        """
        guard let profile = MadLinksParsing.profile(from: Data(json.utf8)) else {
            return XCTFail()
        }
        XCTAssertEqual(profile.design, .list)
        XCTAssertEqual(profile.accounts.count, 2)
        XCTAssertEqual(profile.accounts[0].id, "7")
        XCTAssertEqual(profile.accounts[0].platform, "github")
        XCTAssertEqual(profile.accounts[0].displayName, "Yaroslav")
        XCTAssertTrue(profile.accounts[0].verified)
        XCTAssertTrue(profile.accounts[0].visible)
        XCTAssertEqual(profile.accounts[1].id, "3")
        XCTAssertNil(profile.accounts[1].displayName)
        XCTAssertTrue(profile.accounts[1].verified)
    }

    func testMyAccountsSortedByPositionAndFiltered() {
        let json = """
        {"design":"row","accounts":[
          {"id":1,"platform":"spotify","handle":"a","url":"https://open.spotify.com/user/a","verified":true,"visible":false,"position":2},
          {"id":2,"platform":"discord","handle":"b","url":"javascript:alert(1)","verified":true,"visible":true,"position":0},
          {"id":3,"platform":"reddit","handle":"c","url":null,"verified":false,"visible":true,"position":1}
        ]}
        """
        guard let profile = MadLinksParsing.profile(from: Data(json.utf8)) else {
            return XCTFail()
        }
        XCTAssertEqual(profile.design, .row)
        XCTAssertEqual(profile.accounts.map { $0.id }, ["2", "3", "1"])
        XCTAssertNil(profile.accounts[0].url)
        XCTAssertFalse(profile.accounts[2].visible)
        XCTAssertEqual(profile.publicProfile.accounts.map { $0.id }, ["2", "3"])
    }

    func testUnknownDesignFallsBackToRow() {
        let profile = MadLinksParsing.profile(from: Data("{\"design\":\"grid\",\"accounts\":[]}".utf8))
        XCTAssertEqual(profile, MadLinksProfile(design: .row, accounts: []))
        XCTAssertNil(MadLinksParsing.profile(from: Data("[]".utf8)))
    }

    func testAccountTitle() {
        let account = MadLinksAccount(id: "1", platform: "lastfm", handle: "", displayName: nil, url: nil, verified: false, visible: true, position: 0)
        XCTAssertEqual(account.title, "Last.fm")
        XCTAssertEqual(account.withVisible(false).visible, false)
        XCTAssertEqual(account.withPosition(4).position, 4)
    }

    func testPlatforms() {
        let json = """
        [
          {"id":"steam","name":"Steam","category":"games","method":"login","available":true},
          {"id":"soundcloud","name":"","category":"music","method":"login","available":false},
          {"id":"gitlab","category":"unknown","available":1},
          {"name":"no id"}
        ]
        """
        guard let platforms = MadLinksParsing.platforms(from: Data(json.utf8)) else {
            return XCTFail()
        }
        XCTAssertEqual(platforms.count, 3)
        XCTAssertEqual(platforms[0], MadLinksPlatform(id: "steam", name: "Steam", category: .games, method: "login", available: true))
        XCTAssertEqual(platforms[1].name, "SoundCloud")
        XCTAssertFalse(platforms[1].available)
        XCTAssertEqual(platforms[2].category, .work)
        XCTAssertEqual(platforms[2].method, "login")
        XCTAssertTrue(platforms[2].available)
    }

    func testPlatformsWrapped() {
        let platforms = MadLinksParsing.platforms(from: Data("{\"platforms\":[{\"id\":\"reddit\",\"available\":true}]}".utf8))
        XCTAssertEqual(platforms?.first?.name, "Reddit")
        XCTAssertEqual(platforms?.first?.category, .social)
        XCTAssertNil(MadLinksParsing.platforms(from: Data("{}".utf8)))
    }

    func testFallbackCatalog() {
        let catalog = MadLinksPlatformInfo.fallbackCatalog
        XCTAssertEqual(catalog.map { $0.id }, ["steam", "twitch", "spotify", "soundcloud", "lastfm", "github", "gitlab", "discord", "reddit"])
        XCTAssertTrue(catalog.allSatisfy { !$0.available && $0.category != nil })
        XCTAssertEqual(MadLinksPlatformInfo.iconName("github"), "Mad/Platforms/github")
        XCTAssertNil(MadLinksPlatformInfo.iconName("myspace"))
    }

    func testConnectCallback() {
        XCTAssertEqual(MadLinksParsing.connectResult(URL(string: "mad://accounts/linked?platform=steam")!), .linked("steam"))
        XCTAssertEqual(MadLinksParsing.connectResult(URL(string: "mad://accounts/failed?reason=denied")!), .failed("denied"))
        XCTAssertEqual(MadLinksParsing.connectResult(URL(string: "mad://accounts/failed")!), .failed(nil))
        XCTAssertEqual(MadLinksParsing.connectResult(URL(string: "mad://settings/ghost")!), .unknown)
        XCTAssertEqual(MadLinksParsing.connectResult(URL(string: "https://accounts/linked")!), .unknown)
    }

    func testConnectStartUrl() {
        let url = MadLinksParsing.connectStartUrl(base: URL(string: "https://b.mad.tg")!, platform: "steam", token: "a.b+c/d")
        XCTAssertEqual(url?.host, "b.mad.tg")
        XCTAssertEqual(url?.path, "/api/v1/connect/steam/start")
        let token = URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "token" })?.value
        XCTAssertEqual(token, "a.b+c/d")
    }
}

final class MadProfileLinksClientIdTests: XCTestCase {
    func testClientIdInConnectUrlAndCatalog() {
        let base = URL(string: "https://b.mad.tg")!
        let url = MadLinksParsing.connectStartUrl(base: base, platform: "spotify", token: "t", clientId: "0123456789abcdef0123456789abcdef")
        XCTAssertEqual(url?.absoluteString, "https://b.mad.tg/api/v1/connect/spotify/start?token=t&client_id=0123456789abcdef0123456789abcdef")
        XCTAssertNil(MadLinksParsing.connectStartUrl(base: base, platform: "spotify", token: "t", clientId: "nope"))
        let data = #"[{"id":"spotify","name":"Spotify","category":"music","method":"login","available":true,"needsClientId":true}]"#.data(using: .utf8)!
        XCTAssertEqual(MadLinksParsing.platforms(from: data)?.first?.needsClientId, true)
    }
}

final class MadProfileLinksLabelTests: XCTestCase {
    func testLabelParsingAndTitle() {
        let data = """
        {"id":"a1","platform":"steam","handle":"carcosa","displayName":"Король в жёлтом","url":"https://steamcommunity.com/id/carcosa","verified":true,"visible":true,"position":0,"label":"name"}
        """.data(using: .utf8)!
        let account = MadLinksParsing.account(from: data)
        XCTAssertEqual(account?.label, .name)
        XCTAssertEqual(account?.title, "Король в жёлтом")
        XCTAssertEqual(account?.hasLabelChoice, true)
        XCTAssertEqual(account?.withLabel(.handle).title, "carcosa")
    }

    func testUnknownLabelFallsBackToHandle() {
        let data = """
        {"id":"a1","platform":"github","handle":"yar","displayName":"yar","label":"weird"}
        """.data(using: .utf8)!
        let account = MadLinksParsing.account(from: data)
        XCTAssertEqual(account?.label, .handle)
        XCTAssertEqual(account?.hasLabelChoice, false)
        XCTAssertEqual(account?.title, "yar")
    }

    func testNameLabelWithoutNameUsesHandle() {
        let account = MadLinksAccount(id: "1", platform: "reddit", handle: "spez", displayName: nil, url: nil, verified: true, visible: true, position: 0, label: .name)
        XCTAssertEqual(account.title, "spez")
        XCTAssertFalse(account.hasLabelChoice)
    }
}

final class MadProfileLinksDomainTests: XCTestCase {
    func testDomainClaimParsing() {
        let data = """
        {"domain":"xn--e1afmkfd.xn--p1ai","displayDomain":"пример.рф","recordName":"_mad-verify.xn--e1afmkfd.xn--p1ai","recordValue":"mad-verify=abc"}
        """.data(using: .utf8)!
        let claim = MadLinksParsing.domainClaim(from: data)
        XCTAssertEqual(claim?.displayDomain, "пример.рф")
        XCTAssertEqual(claim?.recordName, "_mad-verify.xn--e1afmkfd.xn--p1ai")
        XCTAssertNil(MadLinksParsing.domainClaim(from: #"{"domain":"a.com","recordName":"x","recordValue":"evil"}"#.data(using: .utf8)!))
    }

    func testDomainCategory() {
        XCTAssertEqual(MadLinksPlatformInfo.category("domain"), .work)
    }
}
