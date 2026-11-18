import Foundation
import Postbox
import SwiftSignalKit

public struct DeletedMessageArchiveExclusions: OptionSet, Codable, Hashable {
    public var rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let bots = DeletedMessageArchiveExclusions(rawValue: 1 << 0)
    public static let savedMessages = DeletedMessageArchiveExclusions(rawValue: 1 << 1)
    public static let channels = DeletedMessageArchiveExclusions(rawValue: 1 << 2)
    public static let groups = DeletedMessageArchiveExclusions(rawValue: 1 << 3)
    public static let privateChats = DeletedMessageArchiveExclusions(rawValue: 1 << 4)

    public static let defaultValue: DeletedMessageArchiveExclusions = [.savedMessages]
}

/// Per-account controls for the on-device deleted-message archive.
public struct DeletedMessageArchiveSettings: Codable, Equatable {
    public static let defaultDeletedMessageMarker = "🧹"
    public static let deletedMessageMarkerLimit = 32
    public static let allowedMediaLimitGigabytes: [Int32] = [1, 5, 10, 20, 50]
    /// Disappearing media is capped separately so that a handful of large one-off videos cannot
    /// crowd out the ordinary archive.
    public static let allowedDisappearingMediaLimitGigabytes: [Int32] = [1, 2, 5, 10]
    public static let allowedDeletedMessageOpacities: [Double] = [1.0, 0.85, 0.7, 0.55, 0.4]
    public static let defaultDeletedMessageOpacity: Double = 0.7
    public static let defaultSettings = DeletedMessageArchiveSettings(
        saveDeletedMessages: true,
        saveEditedVersions: true,
        saveMessagesFromArchivedChats: true,
        deletedMessageMarker: DeletedMessageArchiveSettings.defaultDeletedMessageMarker,
        keepAcrossLaunches: false,
        mediaLimitGigabytes: 5,
        disappearingMediaLimitGigabytes: 1,
        sessionId: 0
    )

    public var saveDeletedMessages: Bool
    public var saveEditedVersions: Bool
    public var saveMessagesFromArchivedChats: Bool
    public var deletedMessageMarker: String
    public var keepAcrossLaunches: Bool
    public var mediaLimitGigabytes: Int32
    public var disappearingMediaLimitGigabytes: Int32
    public var sessionId: Int64
    public var deletedMessageOpacity: Double
    public var exclusions: DeletedMessageArchiveExclusions

    public var isEnabled: Bool {
        get {
            return self.saveDeletedMessages || self.saveEditedVersions
        }
        set {
            self.saveDeletedMessages = newValue
            self.saveEditedVersions = newValue
        }
    }

    public var effectiveDeletedMessageMarker: String {
        return DeletedMessageArchiveSettings.normalizedDeletedMessageMarker(self.deletedMessageMarker)
    }

    public static func normalizedDeletedMessageMarker(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return DeletedMessageArchiveSettings.defaultDeletedMessageMarker
        }
        return String(trimmed.prefix(DeletedMessageArchiveSettings.deletedMessageMarkerLimit))
    }

    public init(
        saveDeletedMessages: Bool,
        saveEditedVersions: Bool,
        saveMessagesFromArchivedChats: Bool,
        deletedMessageMarker: String,
        keepAcrossLaunches: Bool,
        mediaLimitGigabytes: Int32,
        disappearingMediaLimitGigabytes: Int32,
        sessionId: Int64,
        deletedMessageOpacity: Double = DeletedMessageArchiveSettings.defaultDeletedMessageOpacity,
        exclusions: DeletedMessageArchiveExclusions = .defaultValue
    ) {
        self.saveDeletedMessages = saveDeletedMessages
        self.saveEditedVersions = saveEditedVersions
        self.saveMessagesFromArchivedChats = saveMessagesFromArchivedChats
        self.deletedMessageMarker = String(deletedMessageMarker.prefix(DeletedMessageArchiveSettings.deletedMessageMarkerLimit))
        self.keepAcrossLaunches = keepAcrossLaunches
        self.mediaLimitGigabytes = DeletedMessageArchiveSettings.allowedMediaLimitGigabytes.contains(mediaLimitGigabytes) ? mediaLimitGigabytes : 5
        self.disappearingMediaLimitGigabytes = DeletedMessageArchiveSettings.allowedDisappearingMediaLimitGigabytes.contains(disappearingMediaLimitGigabytes) ? disappearingMediaLimitGigabytes : 1
        self.sessionId = sessionId
        self.deletedMessageOpacity = min(1.0, max(0.2, deletedMessageOpacity))
        self.exclusions = exclusions
    }

    // Decoded explicitly so that archives stored before the disappearing-media limit existed keep
    // their configuration instead of resetting to defaults.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyIsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.init(
            saveDeletedMessages: try container.decodeIfPresent(Bool.self, forKey: .saveDeletedMessages) ?? legacyIsEnabled,
            saveEditedVersions: try container.decodeIfPresent(Bool.self, forKey: .saveEditedVersions) ?? legacyIsEnabled,
            saveMessagesFromArchivedChats: try container.decodeIfPresent(Bool.self, forKey: .saveMessagesFromArchivedChats) ?? true,
            deletedMessageMarker: try container.decodeIfPresent(String.self, forKey: .deletedMessageMarker) ?? DeletedMessageArchiveSettings.defaultDeletedMessageMarker,
            keepAcrossLaunches: try container.decode(Bool.self, forKey: .keepAcrossLaunches),
            mediaLimitGigabytes: try container.decode(Int32.self, forKey: .mediaLimitGigabytes),
            disappearingMediaLimitGigabytes: try container.decodeIfPresent(Int32.self, forKey: .disappearingMediaLimitGigabytes) ?? 1,
            sessionId: try container.decode(Int64.self, forKey: .sessionId),
            deletedMessageOpacity: try container.decodeIfPresent(Double.self, forKey: .deletedMessageOpacity) ?? DeletedMessageArchiveSettings.defaultDeletedMessageOpacity,
            exclusions: DeletedMessageArchiveExclusions(rawValue: try container.decodeIfPresent(Int32.self, forKey: .exclusions) ?? DeletedMessageArchiveExclusions.defaultValue.rawValue)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.isEnabled, forKey: .isEnabled)
        try container.encode(self.saveDeletedMessages, forKey: .saveDeletedMessages)
        try container.encode(self.saveEditedVersions, forKey: .saveEditedVersions)
        try container.encode(self.saveMessagesFromArchivedChats, forKey: .saveMessagesFromArchivedChats)
        try container.encode(self.deletedMessageMarker, forKey: .deletedMessageMarker)
        try container.encode(self.keepAcrossLaunches, forKey: .keepAcrossLaunches)
        try container.encode(self.mediaLimitGigabytes, forKey: .mediaLimitGigabytes)
        try container.encode(self.disappearingMediaLimitGigabytes, forKey: .disappearingMediaLimitGigabytes)
        try container.encode(self.sessionId, forKey: .sessionId)
        try container.encode(self.deletedMessageOpacity, forKey: .deletedMessageOpacity)
        try container.encode(self.exclusions.rawValue, forKey: .exclusions)
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case saveDeletedMessages
        case saveEditedVersions
        case saveMessagesFromArchivedChats
        case deletedMessageMarker
        case keepAcrossLaunches
        case mediaLimitGigabytes
        case disappearingMediaLimitGigabytes
        case sessionId
        case deletedMessageOpacity
        case exclusions
    }
}

struct DeletedMessageArchiveIndexEntry: Codable, Hashable {
    let peerId: Int64
    let namespace: Int32
    let id: Int32

    init(_ id: MessageId) {
        self.peerId = id.peerId.toInt64()
        self.namespace = id.namespace
        self.id = id.id
    }

    var messageId: MessageId {
        return MessageId(peerId: PeerId(self.peerId), namespace: self.namespace, id: self.id)
    }
}

struct DeletedMessageArchiveIndex: Codable, Equatable {
    var messageIds: [DeletedMessageArchiveIndexEntry]
    var liveMessageIds: [DeletedMessageArchiveIndexEntry]

    static let empty = DeletedMessageArchiveIndex(messageIds: [], liveMessageIds: [])

    private enum CodingKeys: String, CodingKey {
        case messageIds
        case liveMessageIds
    }

    init(messageIds: [DeletedMessageArchiveIndexEntry], liveMessageIds: [DeletedMessageArchiveIndexEntry]) {
        self.messageIds = messageIds
        self.liveMessageIds = liveMessageIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.messageIds = try container.decodeIfPresent([DeletedMessageArchiveIndexEntry].self, forKey: .messageIds) ?? []
        self.liveMessageIds = try container.decodeIfPresent([DeletedMessageArchiveIndexEntry].self, forKey: .liveMessageIds) ?? []
    }
}

func deletedMessageArchiveSettings(transaction: Transaction) -> DeletedMessageArchiveSettings {
    return transaction.getPreferencesEntry(key: PreferencesKeys.deletedMessageArchiveSettings)?.get(DeletedMessageArchiveSettings.self) ?? .defaultSettings
}

func updateDeletedMessageArchiveIndex(transaction: Transaction, _ f: (DeletedMessageArchiveIndex) -> DeletedMessageArchiveIndex) {
    transaction.updatePreferencesEntry(key: PreferencesKeys.deletedMessageArchiveIndex, { current in
        return PreferencesEntry(f(current?.get(DeletedMessageArchiveIndex.self) ?? .empty))
    })
}

public func updateDeletedMessageArchiveSettingsInteractively(
    postbox: Postbox,
    _ f: @escaping (DeletedMessageArchiveSettings) -> DeletedMessageArchiveSettings
) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: PreferencesKeys.deletedMessageArchiveSettings, { current in
            return PreferencesEntry(f(current?.get(DeletedMessageArchiveSettings.self) ?? .defaultSettings))
        })
    }
    |> ignoreValues
}
