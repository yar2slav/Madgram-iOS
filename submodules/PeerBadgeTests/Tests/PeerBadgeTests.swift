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
}
