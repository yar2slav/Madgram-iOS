import CryptoKit
import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences
import XCTest

final class PeerBadgeTests: XCTestCase {
    func testMediaRoundTrip() throws {
        let badge = PeerBadge(
            id: "badge-1",
            title: "MAD Early",
            description: "Early member",
            linkUrl: "https://mad.tg",
            media: .image(
                image64: "https://b.mad.tg/assets/a-64.webp",
                image128: "https://b.mad.tg/assets/a-128.webp",
                contentHash: String(repeating: "a", count: 64),
                image64Hash: String(repeating: "b", count: 64),
                image128Hash: String(repeating: "c", count: 64)
            ),
            updatedAt: 100
        )
        let data = try JSONEncoder().encode(badge)
        XCTAssertEqual(try JSONDecoder().decode(PeerBadge.self, from: data), badge)
    }

    func testPeerNamespacesDoNotCollide() {
        let user = PeerBadgeTarget(peerType: .user, peerId: 42)
        let channel = PeerBadgeTarget(peerType: .channel, peerId: 42)
        XCTAssertNotEqual(user, channel)

        XCTAssertEqual(
            PeerBadgeTarget(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(42))),
            user
        )
        XCTAssertEqual(
            PeerBadgeTarget(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(42))),
            channel
        )
    }

    func testSignedEnvelopeAndTampering() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let registry = PeerBadgeRegistry(
            revision: 7,
            generatedAt: 100,
            badges: [],
            assignments: []
        )
        let payload = try JSONEncoder().encode(registry)
        let signature = try privateKey.signature(for: payload)
        let envelope: [String: Any] = [
            "schemaVersion": 1,
            "keyId": "test",
            "payload": payload.base64EncodedString(),
            "signature": signature.base64EncodedString()
        ]
        let data = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        XCTAssertEqual(
            PeerBadgeRegistryVerifier.decode(
                data: data,
                keyId: "test",
                publicKeyData: privateKey.publicKey.rawRepresentation
            ),
            registry
        )

        var tampered = data
        tampered[tampered.startIndex] ^= 1
        XCTAssertNil(
            PeerBadgeRegistryVerifier.decode(
                data: tampered,
                keyId: "test",
                publicKeyData: privateKey.publicKey.rawRepresentation
            )
        )
    }

    func testExpirationIsPreserved() throws {
        let assignment = PeerBadgeAssignment(
            peerType: .legacyGroup,
            peerId: 99,
            badgeId: "badge",
            expiresAt: 1234
        )
        let data = try JSONEncoder().encode(assignment)
        XCTAssertEqual(try JSONDecoder().decode(PeerBadgeAssignment.self, from: data), assignment)
    }

    private func signedEnvelope(payloadJson: String, key: Curve25519.Signing.PrivateKey) throws -> Data {
        let payload = Data(payloadJson.utf8)
        let signature = try key.signature(for: payload)
        let envelope: [String: Any] = [
            "schemaVersion": 1,
            "keyId": "test",
            "payload": payload.base64EncodedString(),
            "signature": signature.base64EncodedString()
        ]
        return try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
    }

    func testNameStylesDecodeFromLiveShape() throws {
        let key = Curve25519.Signing.PrivateKey()
        let json = """
        {"revision":83,"generatedAt":1,"badges":[],"assignments":[],"names":[{"peerType":"user","peerId":182259550,"colors":["#64d8f4","#23C0EF","#006ea2"],"effect":"shimmer","expiresAt":null},{"peerType":"channel","peerId":5,"colors":["#ff0000"]}]}
        """
        let registry = try XCTUnwrap(PeerBadgeRegistryVerifier.decode(data: try self.signedEnvelope(payloadJson: json, key: key), keyId: "test", publicKeyData: key.publicKey.rawRepresentation))
        XCTAssertEqual(registry.names.count, 2)
        XCTAssertEqual(registry.names[0].rgbColors, [0x64d8f4, 0x23c0ef, 0x006ea2])
        XCTAssertEqual(registry.names[0].parsedEffect, .shimmer)
        XCTAssertNil(registry.names[1].parsedEffect)
    }

    func testRegistryWithoutNamesStillDecodes() throws {
        let key = Curve25519.Signing.PrivateKey()
        let json = """
        {"revision":1,"generatedAt":1,"badges":[],"assignments":[]}
        """
        let registry = try XCTUnwrap(PeerBadgeRegistryVerifier.decode(data: try self.signedEnvelope(payloadJson: json, key: key), keyId: "test", publicKeyData: key.publicKey.rawRepresentation))
        XCTAssertTrue(registry.names.isEmpty)
    }

    func testInvalidNamesRejectTheRegistry() throws {
        let key = Curve25519.Signing.PrivateKey()
        let invalid = [
            "{\"peerType\":\"user\",\"peerId\":1,\"colors\":[]}",
            "{\"peerType\":\"user\",\"peerId\":1,\"colors\":[\"#1\",\"#2\",\"#3\",\"#4\",\"#5\"]}",
            "{\"peerType\":\"user\",\"peerId\":1,\"colors\":[\"red\"]}",
            "{\"peerType\":\"user\",\"peerId\":0,\"colors\":[\"#ffffff\"]}",
            "{\"peerType\":\"user\",\"peerId\":1,\"colors\":[\"#ffffff\"],\"expiresAt\":-1}",
            "{\"peerType\":\"user\",\"peerId\":1,\"colors\":[\"#ffffff\"]},{\"peerType\":\"user\",\"peerId\":1,\"colors\":[\"#000000\"]}"
        ]
        for names in invalid {
            let json = "{\"revision\":1,\"generatedAt\":1,\"badges\":[],\"assignments\":[],\"names\":[\(names)]}"
            XCTAssertNil(PeerBadgeRegistryVerifier.decode(data: try self.signedEnvelope(payloadJson: json, key: key), keyId: "test", publicKeyData: key.publicKey.rawRepresentation), names)
        }
    }

    func testUnknownEffectFallsBackToStatic() {
        let style = PeerNameStyle(peerType: .user, peerId: 1, colors: ["#ffffff"], effect: "sparkles", expiresAt: nil)
        XCTAssertNil(style.parsedEffect)
    }
}
