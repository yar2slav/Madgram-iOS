import Foundation

public struct GhostModePreviousReadState: Equatable {
    public let maxIncomingReadId: Int32
    public let maxOutgoingReadId: Int32
    public let maxKnownId: Int32
    public let count: Int32
    public let markedUnread: Bool

    public init(maxIncomingReadId: Int32, maxOutgoingReadId: Int32, maxKnownId: Int32, count: Int32, markedUnread: Bool) {
        self.maxIncomingReadId = maxIncomingReadId
        self.maxOutgoingReadId = maxOutgoingReadId
        self.maxKnownId = maxKnownId
        self.count = count
        self.markedUnread = markedUnread
    }
}

public struct GhostModePreviousThreadReadState: Equatable {
    public let maxIncomingReadId: Int32
    public let maxKnownMessageId: Int32
    public let incomingUnreadCount: Int32
    public let markedUnread: Bool

    public init(maxIncomingReadId: Int32, maxKnownMessageId: Int32, incomingUnreadCount: Int32, markedUnread: Bool) {
        self.maxIncomingReadId = maxIncomingReadId
        self.maxKnownMessageId = maxKnownMessageId
        self.incomingUnreadCount = incomingUnreadCount
        self.markedUnread = markedUnread
    }
}

public struct GhostModeReadStateMarker: Equatable {
    public let peerId: PeerId
    public let threadId: Int64?
    public let namespace: MessageId.Namespace
    public let maxReadIndex: MessageIndex
    public let previousReadState: GhostModePreviousReadState?
    public let previousThreadReadState: GhostModePreviousThreadReadState?
    public let previousStoryReadId: Int32?

    public init(
        peerId: PeerId,
        threadId: Int64?,
        namespace: MessageId.Namespace,
        maxReadIndex: MessageIndex,
        previousReadState: GhostModePreviousReadState? = nil,
        previousThreadReadState: GhostModePreviousThreadReadState? = nil,
        previousStoryReadId: Int32? = nil
    ) {
        self.peerId = peerId
        self.threadId = threadId
        self.namespace = namespace
        self.maxReadIndex = maxReadIndex
        self.previousReadState = previousReadState
        self.previousThreadReadState = previousThreadReadState
        self.previousStoryReadId = previousStoryReadId
    }
}

final class GhostModeReadStateTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }

    private var updatedMarkers: [ValueBoxKey: GhostModeReadStateMarker?] = [:]

    private func key(peerId: PeerId, threadId: Int64?, namespace: MessageId.Namespace) -> ValueBoxKey {
        let key = ValueBoxKey(length: 20)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt64(8, value: threadId ?? Int64.min)
        key.setInt32(16, value: namespace)
        return key
    }

    private func marker(key: ValueBoxKey, value: ReadBuffer) -> GhostModeReadStateMarker {
        let peerId = PeerId(key.getInt64(0))
        let rawThreadId = key.getInt64(8)
        let namespace = key.getInt32(16)
        var timestamp: Int32 = 0
        var id: Int32 = 0
        value.read(&timestamp, offset: 0, length: 4)
        value.read(&id, offset: 0, length: 4)
        var previousReadState: GhostModePreviousReadState?
        var previousThreadReadState: GhostModePreviousThreadReadState?
        var previousStoryReadId: Int32?
        if value.length - value.offset >= 2 {
            var version: Int8 = 0
            var flags: Int8 = 0
            value.read(&version, offset: 0, length: 1)
            value.read(&flags, offset: 0, length: 1)
            if version >= 1 {
                if (flags & (1 << 0)) != 0, value.length - value.offset >= 17 {
                    var maxIncomingReadId: Int32 = 0
                    var maxOutgoingReadId: Int32 = 0
                    var maxKnownId: Int32 = 0
                    var count: Int32 = 0
                    var markedUnread: Int8 = 0
                    value.read(&maxIncomingReadId, offset: 0, length: 4)
                    value.read(&maxOutgoingReadId, offset: 0, length: 4)
                    value.read(&maxKnownId, offset: 0, length: 4)
                    value.read(&count, offset: 0, length: 4)
                    value.read(&markedUnread, offset: 0, length: 1)
                    previousReadState = GhostModePreviousReadState(
                        maxIncomingReadId: maxIncomingReadId,
                        maxOutgoingReadId: maxOutgoingReadId,
                        maxKnownId: maxKnownId,
                        count: count,
                        markedUnread: markedUnread != 0
                    )
                }
                if (flags & (1 << 1)) != 0, value.length - value.offset >= 13 {
                    var maxIncomingReadId: Int32 = 0
                    var maxKnownMessageId: Int32 = 0
                    var incomingUnreadCount: Int32 = 0
                    var markedUnread: Int8 = 0
                    value.read(&maxIncomingReadId, offset: 0, length: 4)
                    value.read(&maxKnownMessageId, offset: 0, length: 4)
                    value.read(&incomingUnreadCount, offset: 0, length: 4)
                    value.read(&markedUnread, offset: 0, length: 1)
                    previousThreadReadState = GhostModePreviousThreadReadState(
                        maxIncomingReadId: maxIncomingReadId,
                        maxKnownMessageId: maxKnownMessageId,
                        incomingUnreadCount: incomingUnreadCount,
                        markedUnread: markedUnread != 0
                    )
                }
                if (flags & (1 << 2)) != 0, value.length - value.offset >= 4 {
                    var maxReadId: Int32 = 0
                    value.read(&maxReadId, offset: 0, length: 4)
                    previousStoryReadId = maxReadId
                }
            }
        }
        return GhostModeReadStateMarker(
            peerId: peerId,
            threadId: rawThreadId == Int64.min ? nil : rawThreadId,
            namespace: namespace,
            maxReadIndex: MessageIndex(
                id: MessageId(peerId: peerId, namespace: namespace, id: id),
                timestamp: timestamp
            ),
            previousReadState: previousReadState,
            previousThreadReadState: previousThreadReadState,
            previousStoryReadId: previousStoryReadId
        )
    }

    func get(peerId: PeerId, threadId: Int64?, namespace: MessageId.Namespace) -> GhostModeReadStateMarker? {
        let key = self.key(peerId: peerId, threadId: threadId, namespace: namespace)
        if let updated = self.updatedMarkers[key] {
            return updated
        }
        guard let value = self.valueBox.get(self.table, key: key) else {
            return nil
        }
        return self.marker(key: key, value: value)
    }

    func set(_ marker: GhostModeReadStateMarker?) {
        guard var marker else {
            return
        }
        let key = self.key(peerId: marker.peerId, threadId: marker.threadId, namespace: marker.namespace)
        if let current = self.get(peerId: marker.peerId, threadId: marker.threadId, namespace: marker.namespace) {
            marker = GhostModeReadStateMarker(
                peerId: marker.peerId,
                threadId: marker.threadId,
                namespace: marker.namespace,
                maxReadIndex: max(current.maxReadIndex, marker.maxReadIndex),
                previousReadState: current.previousReadState ?? marker.previousReadState,
                previousThreadReadState: current.previousThreadReadState ?? marker.previousThreadReadState,
                previousStoryReadId: current.previousStoryReadId ?? marker.previousStoryReadId
            )
            if current == marker {
                return
            }
        }
        self.updatedMarkers[key] = marker
    }

    func remove(peerId: PeerId, threadId: Int64?, namespace: MessageId.Namespace) {
        self.updatedMarkers[self.key(peerId: peerId, threadId: threadId, namespace: namespace)] = nil
    }

    func getAll() -> [GhostModeReadStateMarker] {
        let lowerBound = ValueBoxKey(length: 20)
        let upperBound = ValueBoxKey(length: 20)
        memset(upperBound.memory, 0xff, upperBound.length)
        var result: [ValueBoxKey: GhostModeReadStateMarker] = [:]
        self.valueBox.range(self.table, start: lowerBound, end: upperBound, values: { key, value in
            result[key] = self.marker(key: key, value: value)
            return true
        }, limit: 0)
        for (key, marker) in self.updatedMarkers {
            result[key] = marker
        }
        return Array(result.values)
    }

    func removeAll() -> [GhostModeReadStateMarker] {
        let markers = self.getAll()
        for marker in markers {
            self.updatedMarkers[self.key(peerId: marker.peerId, threadId: marker.threadId, namespace: marker.namespace)] = nil
        }
        return markers
    }

    override func beforeCommit() {
        if self.updatedMarkers.isEmpty {
            return
        }
        for (key, marker) in self.updatedMarkers {
            if let marker {
                let value = WriteBuffer()
                var timestamp = marker.maxReadIndex.timestamp
                var id = marker.maxReadIndex.id.id
                value.write(&timestamp, offset: 0, length: 4)
                value.write(&id, offset: 0, length: 4)
                var version: Int8 = 1
                var flags: Int8 = 0
                if marker.previousReadState != nil {
                    flags |= 1 << 0
                }
                if marker.previousThreadReadState != nil {
                    flags |= 1 << 1
                }
                if marker.previousStoryReadId != nil {
                    flags |= 1 << 2
                }
                value.write(&version, offset: 0, length: 1)
                value.write(&flags, offset: 0, length: 1)
                if let previousReadState = marker.previousReadState {
                    var maxIncomingReadId = previousReadState.maxIncomingReadId
                    var maxOutgoingReadId = previousReadState.maxOutgoingReadId
                    var maxKnownId = previousReadState.maxKnownId
                    var count = previousReadState.count
                    var markedUnread: Int8 = previousReadState.markedUnread ? 1 : 0
                    value.write(&maxIncomingReadId, offset: 0, length: 4)
                    value.write(&maxOutgoingReadId, offset: 0, length: 4)
                    value.write(&maxKnownId, offset: 0, length: 4)
                    value.write(&count, offset: 0, length: 4)
                    value.write(&markedUnread, offset: 0, length: 1)
                }
                if let previousThreadReadState = marker.previousThreadReadState {
                    var maxIncomingReadId = previousThreadReadState.maxIncomingReadId
                    var maxKnownMessageId = previousThreadReadState.maxKnownMessageId
                    var incomingUnreadCount = previousThreadReadState.incomingUnreadCount
                    var markedUnread: Int8 = previousThreadReadState.markedUnread ? 1 : 0
                    value.write(&maxIncomingReadId, offset: 0, length: 4)
                    value.write(&maxKnownMessageId, offset: 0, length: 4)
                    value.write(&incomingUnreadCount, offset: 0, length: 4)
                    value.write(&markedUnread, offset: 0, length: 1)
                }
                if var previousStoryReadId = marker.previousStoryReadId {
                    value.write(&previousStoryReadId, offset: 0, length: 4)
                }
                self.valueBox.set(self.table, key: key, value: value)
            } else {
                self.valueBox.remove(self.table, key: key, secure: false)
            }
        }
        self.updatedMarkers.removeAll()
    }
}
