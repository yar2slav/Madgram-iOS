import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import Display

enum MadShareHandoff {
    static let markerType = "org.madgram.share-handoff"
    static let fileType = "org.madgram.share-file"

    private struct FileInfo: Decodable {
        let name: String
        let mime: String
    }

    private enum Item {
        case text(String)
        case image(Data, CGSize)
        case file(Data, String, String)
    }

    private static func readItems() -> [Item]? {
        let pasteboard = UIPasteboard.general
        guard pasteboard.contains(pasteboardTypes: [markerType]) else {
            return nil
        }
        var result: [Item] = []
        for item in pasteboard.items {
            if item[markerType] != nil {
                continue
            }
            if let infoData = item[fileType] as? Data, let info = try? JSONDecoder().decode(FileInfo.self, from: infoData), let data = item["public.data"] as? Data {
                result.append(.file(data, info.name, info.mime))
            } else if let data = (item["public.jpeg"] as? Data) ?? (item["public.png"] as? Data), let image = UIImage(data: data) {
                result.append(.image(data, CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)))
            } else if let image = item["public.jpeg"] as? UIImage ?? item["public.png"] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
                result.append(.image(data, CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)))
            } else if let url = item["public.url"] as? URL {
                result.append(.text(url.absoluteString))
            } else if let text = item["public.utf8-plain-text"] as? String {
                result.append(.text(text))
            }
        }
        pasteboard.items = []
        return result
    }

    static func present(context: AccountContext, parent: ViewController?) {
        guard let parent, let items = readItems(), !items.isEmpty else {
            return
        }
        let subject: ShareControllerSubject = .fromExternal(items.count, { peerIds, threadIds, _, caption, _, _ in
            var messages: [EnqueueMessage] = []
            var texts = items.compactMap { item -> String? in
                if case let .text(text) = item {
                    return text
                }
                return nil
            }
            if !caption.isEmpty {
                texts.insert(caption, at: 0)
            }
            if !texts.isEmpty {
                messages.append(.message(text: texts.joined(separator: "\n"), attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
            }
            for item in items {
                switch item {
                case .text:
                    break
                case let .image(data, size):
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data, synchronous: true)
                    let image = TelegramMediaImage(imageId: EngineMedia.Id(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: [TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: Int32(size.width), height: Int32(size.height)), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                    messages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: image), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                case let .file(data, name, mime):
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data, synchronous: true)
                    let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: mime, size: Int64(data.count), attributes: [.FileName(fileName: name)], alternativeRepresentations: [])
                    messages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
                }
            }
            var signals: [Signal<[EngineMessage.Id?], NoError>] = []
            for peerId in peerIds {
                let threadId = threadIds[peerId]
                signals.append(enqueueMessages(account: context.account, peerId: peerId, messages: messages.map { $0.withUpdatedThreadId(threadId) }))
            }
            return combineLatest(signals)
            |> castError(ShareControllerError.self)
            |> map { _ -> ShareControllerExternalStatus in
                return .done
            }
        })
        let controller = context.sharedContext.makeShareController(context: context, params: ShareControllerParams(subject: subject, fromForeignApp: true, externalShare: false))
        parent.present(controller, in: .window(.root))
    }
}
