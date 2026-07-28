import Foundation
import Postbox

public final class ArchivedMessageAttribute: MessageAttribute {
    public let originalMessageId: MessageId
    public let versionIds: [MessageId]
    public let deletedAt: Int32?
    public let sessionId: Int64

    public var associatedMessageIds: [MessageId] {
        return self.versionIds
    }

    public init(
        originalMessageId: MessageId,
        versionIds: [MessageId],
        deletedAt: Int32?,
        sessionId: Int64
    ) {
        self.originalMessageId = originalMessageId
        self.versionIds = versionIds
        self.deletedAt = deletedAt
        self.sessionId = sessionId
    }

    public required init(decoder: PostboxDecoder) {
        self.originalMessageId = decoder.decodeObjectForKey("o", decoder: { MessageId(decoder: $0) }) as! MessageId
        if let data = decoder.decodeDataForKey("v") {
            self.versionIds = MessageId.decodeArrayFromData(data)
        } else {
            self.versionIds = []
        }
        self.deletedAt = decoder.decodeOptionalInt32ForKey("d")
        self.sessionId = decoder.decodeInt64ForKey("s", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.originalMessageId, forKey: "o")
        encoder.encodeData(MessageId.encodeArrayToData(self.versionIds), forKey: "v")
        if let deletedAt = self.deletedAt {
            encoder.encodeInt32(deletedAt, forKey: "d")
        } else {
            encoder.encodeNil(forKey: "d")
        }
        encoder.encodeInt64(self.sessionId, forKey: "s")
    }
}

public final class ArchivedMessageVersionAttribute: MessageAttribute {
    public let capturedAt: Int32

    public init(capturedAt: Int32) {
        self.capturedAt = capturedAt
    }

    public required init(decoder: PostboxDecoder) {
        self.capturedAt = decoder.decodeInt32ForKey("t", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.capturedAt, forKey: "t")
    }
}

public extension Message {
    var archivedMessageAttribute: ArchivedMessageAttribute? {
        return self.attributes.first(where: { $0 is ArchivedMessageAttribute }) as? ArchivedMessageAttribute
    }

    var archivedVersionCapturedAt: Int32? {
        return (self.attributes.first(where: { $0 is ArchivedMessageVersionAttribute }) as? ArchivedMessageVersionAttribute)?.capturedAt
    }

    var isArchivedDeletedMessage: Bool {
        return self.id.namespace == Namespaces.Message.Archived && self.archivedMessageAttribute?.deletedAt != nil
    }
}
