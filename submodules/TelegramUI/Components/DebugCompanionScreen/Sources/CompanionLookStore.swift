import Foundation
import UIKit
import CompanionRenderer

public struct CompanionLook: Codable, Equatable {
    public struct Component: Codable, Equatable {
        public var kind: Int
        public var socket: String
        public var fileName: String?
    }

    public var presetId: String?
    public var presetFiles: [String: String]
    public var components: [Component]

    public static let `default` = CompanionLook(presetId: nil, presetFiles: [:], components: [])
}

public final class CompanionLookStore {
    public static let shared = CompanionLookStore()
    public static let didChangeNotification = Notification.Name("MadgramCompanionLookDidChange")

    private let key = "madgram.companion.look.v1"
    public private(set) var current: CompanionLook

    public let directory: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.directory = base.appendingPathComponent("madgram-companion", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        if let data = UserDefaults.standard.data(forKey: self.key), let look = try? JSONDecoder().decode(CompanionLook.self, from: data) {
            self.current = look
        } else {
            self.current = .default
        }
    }

    private func store(_ look: CompanionLook) {
        guard look != self.current else {
            return
        }
        self.current = look
        if let data = try? JSONEncoder().encode(look) {
            UserDefaults.standard.set(data, forKey: self.key)
        }
        self.removeUnusedFiles()
        NotificationCenter.default.post(name: CompanionLookStore.didChangeNotification, object: nil)
    }

    private func keep(_ url: URL, name: String) -> String? {
        let target = self.directory.appendingPathComponent(name)
        if url.standardizedFileURL == target.standardizedFileURL {
            return name
        }
        try? FileManager.default.removeItem(at: target)
        do {
            try FileManager.default.copyItem(at: url, to: target)
            return name
        } catch {
            return nil
        }
    }

    private func removeUnusedFiles() {
        var used = Set(self.current.presetFiles.values)
        for component in self.current.components {
            if let fileName = component.fileName {
                used.insert(fileName)
            }
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: self.directory.path) else {
            return
        }
        for name in contents where !used.contains(name) {
            try? FileManager.default.removeItem(at: self.directory.appendingPathComponent(name))
        }
    }

    public func reset() {
        self.store(.default)
    }

    public func setPreset(_ presetId: String, files: [String: URL]) {
        var stored: [String: String] = [:]
        for (name, url) in files {
            if let fileName = self.keep(url, name: name) {
                stored[name] = fileName
            }
        }
        self.store(CompanionLook(presetId: presetId == "classic" ? nil : presetId, presetFiles: presetId == "classic" ? [:] : stored, components: []))
    }

    public func setComponent(kind: CompanionComponentKind, socket: String, url: URL?, name: String?) {
        var look = self.current
        var fileName: String?
        if let url, let name {
            fileName = self.keep(url, name: name)
            if fileName == nil {
                return
            }
        }
        look.components.removeAll(where: { $0.kind == kind.rawValue && $0.socket == socket })
        look.components.append(CompanionLook.Component(kind: kind.rawValue, socket: socket, fileName: fileName))
        self.store(look)
    }

    public func apply(to renderer: CompanionRenderer) {
        let look = self.current
        if let presetId = look.presetId {
            var files: [String: URL] = [:]
            for (name, fileName) in look.presetFiles {
                let url = self.directory.appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: url.path) {
                    files[name] = url
                }
            }
            try? renderer.applyPreset(presetId, files: files)
        }
        for component in look.components {
            guard let kind = CompanionComponentKind(rawValue: component.kind) else {
                continue
            }
            var url: URL?
            if let fileName = component.fileName {
                let candidate = self.directory.appendingPathComponent(fileName)
                guard FileManager.default.fileExists(atPath: candidate.path) else {
                    continue
                }
                url = candidate
            }
            try? renderer.setComponentAt(url, kind: kind, socket: component.socket)
        }
    }
}

public final class CompanionChatPlacementStore {
    public static let shared = CompanionChatPlacementStore()

    public struct Placement: Codable, Equatable {
        public var x: CGFloat
        public var bottom: CGFloat
        public var size: CGFloat

        public init(x: CGFloat, bottom: CGFloat, size: CGFloat) {
            self.x = x
            self.bottom = bottom
            self.size = size
        }
    }

    private let key = "madgram.companion.placement.v1"
    public static let defaultPlacement = Placement(x: 4.0, bottom: 0.0, size: 96.0)
    public static let minSize: CGFloat = 56.0
    public static let maxSize: CGFloat = 240.0

    public var current: Placement {
        didSet {
            if let data = try? JSONEncoder().encode(self.current) {
                UserDefaults.standard.set(data, forKey: self.key)
            }
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: self.key), let value = try? JSONDecoder().decode(Placement.self, from: data) {
            self.current = value
        } else {
            self.current = CompanionChatPlacementStore.defaultPlacement
        }
    }
}
