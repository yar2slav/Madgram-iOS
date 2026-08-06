import Foundation
import CryptoKit
import Postbox
import SwiftSignalKit
import TelegramCore

public enum PeerBadgePeerType: String, Codable, CaseIterable {
    case user
    case legacyGroup
    case channel
}

public struct PeerBadgeTarget: Codable, Hashable {
    public let peerType: PeerBadgePeerType
    public let peerId: Int64

    public init(peerType: PeerBadgePeerType, peerId: Int64) {
        self.peerType = peerType
        self.peerId = peerId
    }

    public init?(peerId: PeerId) {
        let peerType: PeerBadgePeerType
        switch peerId.namespace {
        case Namespaces.Peer.CloudUser:
            peerType = .user
        case Namespaces.Peer.CloudGroup:
            peerType = .legacyGroup
        case Namespaces.Peer.CloudChannel:
            peerType = .channel
        default:
            return nil
        }
        self.init(peerType: peerType, peerId: peerId.id._internalGetInt64Value())
    }
}

public enum PeerBadgeMedia: Equatable {
    case image(image64: String, image128: String, contentHash: String, image64Hash: String, image128Hash: String)
    case customEmoji(documentId: Int64)
}

extension PeerBadgeMedia: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case image64
        case image128
        case contentHash
        case image64Hash
        case image128Hash
        case documentId
    }

    private enum Kind: String, Codable {
        case image
        case customEmoji
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .image:
            self = .image(
                image64: try container.decode(String.self, forKey: .image64),
                image128: try container.decode(String.self, forKey: .image128),
                contentHash: try container.decode(String.self, forKey: .contentHash),
                image64Hash: try container.decode(String.self, forKey: .image64Hash),
                image128Hash: try container.decode(String.self, forKey: .image128Hash)
            )
        case .customEmoji:
            self = .customEmoji(documentId: try container.decode(Int64.self, forKey: .documentId))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .image(image64, image128, contentHash, image64Hash, image128Hash):
            try container.encode(Kind.image, forKey: .kind)
            try container.encode(image64, forKey: .image64)
            try container.encode(image128, forKey: .image128)
            try container.encode(contentHash, forKey: .contentHash)
            try container.encode(image64Hash, forKey: .image64Hash)
            try container.encode(image128Hash, forKey: .image128Hash)
        case let .customEmoji(documentId):
            try container.encode(Kind.customEmoji, forKey: .kind)
            try container.encode(documentId, forKey: .documentId)
        }
    }
}

public struct PeerBadge: Codable, Equatable {
    public let id: String
    public let title: String
    public let description: String
    public let linkUrl: String?
    public let media: PeerBadgeMedia
    public let updatedAt: Int64

    public init(id: String, title: String, description: String, linkUrl: String?, media: PeerBadgeMedia, updatedAt: Int64) {
        self.id = id
        self.title = title
        self.description = description
        self.linkUrl = linkUrl
        self.media = media
        self.updatedAt = updatedAt
    }
}

public struct PeerBadgeAssignment: Codable, Equatable {
    public let peerType: PeerBadgePeerType
    public let peerId: Int64
    public let badgeId: String
    public let expiresAt: Int64?

    public init(peerType: PeerBadgePeerType, peerId: Int64, badgeId: String, expiresAt: Int64?) {
        self.peerType = peerType
        self.peerId = peerId
        self.badgeId = badgeId
        self.expiresAt = expiresAt
    }
}

public struct PeerBadgeRegistry: Codable, Equatable {
    public let revision: Int64
    public let generatedAt: Int64
    public let badges: [PeerBadge]
    public let assignments: [PeerBadgeAssignment]

    public init(revision: Int64, generatedAt: Int64, badges: [PeerBadge], assignments: [PeerBadgeAssignment]) {
        self.revision = revision
        self.generatedAt = generatedAt
        self.badges = badges
        self.assignments = assignments
    }
}

private struct PeerBadgeRegistryEnvelope: Codable {
    let schemaVersion: Int
    let keyId: String
    let payload: String
    let signature: String
}

public enum PeerBadgeRegistryVerifier {
    public static func decode(data: Data, keyId: String, publicKeyData: Data) -> PeerBadgeRegistry? {
        guard
            let envelope = try? JSONDecoder().decode(PeerBadgeRegistryEnvelope.self, from: data),
            envelope.schemaVersion == 1,
            envelope.keyId == keyId,
            let payload = Data(base64Encoded: envelope.payload),
            let signature = Data(base64Encoded: envelope.signature),
            let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData),
            publicKey.isValidSignature(signature, for: payload),
            let registry = try? JSONDecoder().decode(PeerBadgeRegistry.self, from: payload)
        else {
            return nil
        }
        guard registry.badges.allSatisfy({ $0.media.isValid }) else {
            return nil
        }
        return registry
    }
}

private extension PeerBadgeMedia {
    var isValid: Bool {
        switch self {
        case let .image(image64, image128, contentHash, image64Hash, image128Hash):
            return PeerBadgeImageValidator.isValidHash(contentHash)
                && PeerBadgeImageValidator.isValidHash(image64Hash)
                && PeerBadgeImageValidator.isValidHash(image128Hash)
                && PeerBadgeImageValidator.isAllowedAssetURL(image64)
                && PeerBadgeImageValidator.isAllowedAssetURL(image128)
        case .customEmoji:
            return true
        }
    }
}

public enum PeerBadgeImageValidator {
    public static func isValidHash(_ value: String) -> Bool {
        return value.count == 64 && value.utf8.allSatisfy { byte in
            (byte >= 48 && byte <= 57) || (byte >= 97 && byte <= 102)
        }
    }

    public static func isAllowedAssetURL(_ value: String) -> Bool {
        guard let url = URL(string: value) else {
            return false
        }
        return url.scheme == "https"
            && url.host?.lowercased() == "b.mad.tg"
            && url.user == nil
            && url.password == nil
            && (url.port == nil || url.port == 443)
            && url.path.hasPrefix("/assets/")
    }

    public static func validate(data: Data, expectedHash: String, expectedSize: Int) -> Bool {
        guard isValidHash(expectedHash) else {
            return false
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == expectedHash, let dimensions = webPDimensions(data: data) else {
            return false
        }
        return dimensions.width == expectedSize && dimensions.height == expectedSize
    }

    private static func webPDimensions(data: Data) -> (width: Int, height: Int)? {
        let bytes = [UInt8](data)
        guard bytes.count >= 20,
              String(bytes: bytes[0 ..< 4], encoding: .ascii) == "RIFF",
              String(bytes: bytes[8 ..< 12], encoding: .ascii) == "WEBP"
        else {
            return nil
        }
        var offset = 12
        while offset + 8 <= bytes.count {
            let kind = String(bytes: bytes[offset ..< offset + 4], encoding: .ascii)
            let length = Int(bytes[offset + 4])
                | (Int(bytes[offset + 5]) << 8)
                | (Int(bytes[offset + 6]) << 16)
                | (Int(bytes[offset + 7]) << 24)
            let payload = offset + 8
            guard length >= 0, payload + length <= bytes.count else {
                return nil
            }
            if kind == "VP8X", length >= 10 {
                let width = 1 + Int(bytes[payload + 4]) + (Int(bytes[payload + 5]) << 8) + (Int(bytes[payload + 6]) << 16)
                let height = 1 + Int(bytes[payload + 7]) + (Int(bytes[payload + 8]) << 8) + (Int(bytes[payload + 9]) << 16)
                return (width, height)
            } else if kind == "VP8 ", length >= 10,
                      bytes[payload + 3] == 0x9d, bytes[payload + 4] == 0x01, bytes[payload + 5] == 0x2a {
                let width = (Int(bytes[payload + 6]) | (Int(bytes[payload + 7]) << 8)) & 0x3fff
                let height = (Int(bytes[payload + 8]) | (Int(bytes[payload + 9]) << 8)) & 0x3fff
                return (width, height)
            } else if kind == "VP8L", length >= 5, bytes[payload] == 0x2f {
                let bits = UInt32(bytes[payload + 1])
                    | (UInt32(bytes[payload + 2]) << 8)
                    | (UInt32(bytes[payload + 3]) << 16)
                    | (UInt32(bytes[payload + 4]) << 24)
                return (Int(bits & 0x3fff) + 1, Int((bits >> 14) & 0x3fff) + 1)
            }
            offset = payload + length + (length & 1)
        }
        return nil
    }
}

public final class PeerBadgeRegistryStore {
    public static let shared = PeerBadgeRegistryStore()
    public static let didChangeNotification = Notification.Name("PeerBadgeRegistryStore.didChange")

    private static let registryUrl = URL(string: "https://b.mad.tg/api/v1/registry")!
    private static let signingKeyId = "mad-badges-1"
    private static let signingPublicKey = Data(base64Encoded: "fu30bgNFntwaeXWD3dyTuMgWKM12eGKgqwRbgl/Soy0=")!
    private static let refreshInterval: TimeInterval = 60.0
    private static let imageCacheLimit: Int64 = 25 * 1024 * 1024

    private let queue = Queue(name: "PeerBadgeRegistryStore")
    private let lock = NSLock()
    private let session: URLSession
    private let cacheDirectory: URL
    private let registryCacheUrl: URL
    private let metadataCacheUrl: URL
    private let imageCacheDirectory: URL

    private var registry: PeerBadgeRegistry?
    private var badgeById: [String: PeerBadge] = [:]
    private var assignmentByTarget: [PeerBadgeTarget: PeerBadgeAssignment] = [:]
    private var etag: String?
    private var isStarted = false
    private var refreshTimer: SwiftSignalKit.Timer?
    private var foregroundObserver: NSObjectProtocol?

    private init() {
        let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.cacheDirectory = cacheRoot.appendingPathComponent("MADPeerBadges", isDirectory: true)
        self.registryCacheUrl = self.cacheDirectory.appendingPathComponent("registry-envelope.json")
        self.metadataCacheUrl = self.cacheDirectory.appendingPathComponent("metadata.json")
        self.imageCacheDirectory = self.cacheDirectory.appendingPathComponent("images", isDirectory: true)

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15.0
        configuration.timeoutIntervalForResource = 30.0
        self.session = URLSession(configuration: configuration)

        try? FileManager.default.createDirectory(at: self.imageCacheDirectory, withIntermediateDirectories: true)
        self.loadCachedRegistry()
    }

    deinit {
        self.refreshTimer?.invalidate()
        if let foregroundObserver = self.foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    public func start() {
        self.lock.lock()
        if self.isStarted {
            self.lock.unlock()
            return
        }
        self.isStarted = true
        self.lock.unlock()

        self.refresh()
        let timer = SwiftSignalKit.Timer(
            timeout: Self.refreshInterval,
            repeat: true,
            completion: { [weak self] in
                self?.refresh()
            },
            queue: self.queue
        )
        self.refreshTimer = timer
        timer.start()

        self.foregroundObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("UIApplicationWillEnterForegroundNotification"),
            object: nil,
            queue: nil,
            using: { [weak self] _ in
                self?.refresh()
            }
        )
    }

    public func refresh() {
        var request = URLRequest(url: Self.registryUrl)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        self.lock.lock()
        if let etag = self.etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        self.lock.unlock()

        self.session.dataTask(with: request, completionHandler: { [weak self] data, response, _ in
            guard let self, let response = response as? HTTPURLResponse else {
                return
            }
            if response.statusCode == 304 {
                return
            }
            guard response.statusCode == 200, let data, data.count <= 2 * 1024 * 1024 else {
                return
            }
            guard let registry = Self.decodeAndVerify(data: data) else {
                return
            }
            let etag = response.value(forHTTPHeaderField: "ETag")
            self.apply(registry: registry, envelopeData: data, etag: etag)
        }).resume()
    }

    public var currentRegistry: PeerBadgeRegistry? {
        self.lock.lock()
        let value = self.registry
        self.lock.unlock()
        return value
    }

    public func badge(peerId: PeerId, now: Int64 = Int64(Date().timeIntervalSince1970)) -> PeerBadge? {
        guard let target = PeerBadgeTarget(peerId: peerId) else {
            return nil
        }
        self.lock.lock()
        let assignment = self.assignmentByTarget[target]
        let badge = assignment.flatMap { self.badgeById[$0.badgeId] }
        self.lock.unlock()
        if let expiresAt = assignment?.expiresAt, expiresAt <= now {
            return nil
        }
        return badge
    }

    public func cachedImageData(for badge: PeerBadge, preferredSize: Int = 64) -> Data? {
        guard case let .image(_, _, _, image64Hash, image128Hash) = badge.media else {
            return nil
        }
        let size = preferredSize >= 128 ? 128 : 64
        let expectedHash = size == 128 ? image128Hash : image64Hash
        let url = self.imageCacheDirectory.appendingPathComponent("\(expectedHash)-\(size).webp")
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        guard PeerBadgeImageValidator.validate(data: data, expectedHash: expectedHash, expectedSize: size) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }

    public func loadImageData(for badge: PeerBadge, preferredSize: Int = 64, completion: @escaping (Data?) -> Void) {
        if let data = self.cachedImageData(for: badge, preferredSize: preferredSize) {
            completion(data)
            return
        }
        guard case let .image(image64, image128, _, image64Hash, image128Hash) = badge.media else {
            completion(nil)
            return
        }
        let size = preferredSize >= 128 ? 128 : 64
        let urlString = size == 128 ? image128 : image64
        let expectedHash = size == 128 ? image128Hash : image64Hash
        guard
            let url = URL(string: urlString),
            PeerBadgeImageValidator.isAllowedAssetURL(urlString)
        else {
            completion(nil)
            return
        }
        self.session.dataTask(with: url, completionHandler: { [weak self] data, response, _ in
            guard
                let self,
                let response = response as? HTTPURLResponse,
                response.statusCode == 200,
                let finalUrl = response.url,
                PeerBadgeImageValidator.isAllowedAssetURL(finalUrl.absoluteString),
                response.mimeType?.lowercased() == "image/webp",
                let data,
                !data.isEmpty,
                data.count <= 2 * 1024 * 1024,
                PeerBadgeImageValidator.validate(data: data, expectedHash: expectedHash, expectedSize: size)
            else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            let destination = self.imageCacheDirectory.appendingPathComponent("\(expectedHash)-\(size).webp")
            try? data.write(to: destination, options: .atomic)
            self.trimImageCache()
            DispatchQueue.main.async {
                completion(data)
            }
        }).resume()
    }

    private static func decodeAndVerify(data: Data) -> PeerBadgeRegistry? {
        return PeerBadgeRegistryVerifier.decode(
            data: data,
            keyId: Self.signingKeyId,
            publicKeyData: Self.signingPublicKey
        )
    }

    private func loadCachedRegistry() {
        guard
            let data = try? Data(contentsOf: self.registryCacheUrl),
            let registry = Self.decodeAndVerify(data: data)
        else {
            return
        }
        var cachedEtag: String?
        if
            let metadata = try? Data(contentsOf: self.metadataCacheUrl),
            let value = try? JSONDecoder().decode([String: String].self, from: metadata)
        {
            cachedEtag = value["etag"]
        }
        self.apply(registry: registry, envelopeData: nil, etag: cachedEtag, notify: false)
    }

    private func apply(registry: PeerBadgeRegistry, envelopeData: Data?, etag: String?, notify: Bool = true) {
        var badgeById: [String: PeerBadge] = [:]
        for badge in registry.badges {
            badgeById[badge.id] = badge
        }
        var assignmentByTarget: [PeerBadgeTarget: PeerBadgeAssignment] = [:]
        for assignment in registry.assignments where badgeById[assignment.badgeId] != nil {
            assignmentByTarget[PeerBadgeTarget(peerType: assignment.peerType, peerId: assignment.peerId)] = assignment
        }

        self.lock.lock()
        let changed = self.registry != registry
        self.registry = registry
        self.badgeById = badgeById
        self.assignmentByTarget = assignmentByTarget
        self.etag = etag
        self.lock.unlock()

        if let envelopeData {
            try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
            try? envelopeData.write(to: self.registryCacheUrl, options: .atomic)
            if let etag, let metadata = try? JSONEncoder().encode(["etag": etag]) {
                try? metadata.write(to: self.metadataCacheUrl, options: .atomic)
            }
        }
        if changed && notify {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
            }
        }
    }

    private func trimImageCache() {
        self.queue.async {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: self.imageCacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                return
            }
            var entries: [(url: URL, size: Int64, date: Date)] = []
            var totalSize: Int64 = 0
            for url in files {
                guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else {
                    continue
                }
                let size = Int64(values.fileSize ?? 0)
                totalSize += size
                entries.append((url, size, values.contentModificationDate ?? .distantPast))
            }
            for entry in entries.sorted(by: { $0.date < $1.date }) where totalSize > Self.imageCacheLimit {
                try? FileManager.default.removeItem(at: entry.url)
                totalSize -= entry.size
            }
        }
    }
}
