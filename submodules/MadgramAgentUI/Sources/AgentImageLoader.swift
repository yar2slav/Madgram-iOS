import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import MadgramAgent

enum AgentImageLoader {
    static func encode(_ image: UIImage, maxSide: CGFloat = 1280.0) -> AgentImage? {
        let size = image.size
        guard size.width > 0.0, size.height > 0.0 else {
            return nil
        }
        let scale = min(1.0, maxSide / max(size.width, size.height))
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let data = rendered.jpegData(compressionQuality: 0.75) else {
            return nil
        }
        return AgentImage(mediaType: "image/jpeg", base64: data.base64EncodedString())
    }

    static func hasPhoto(_ message: EngineMessage) -> Bool {
        return message.media.contains(where: { $0 is TelegramMediaImage })
    }

    @MainActor
    static func load(context: AccountContext, message: EngineMessage) async -> AgentImage? {
        guard let image = message.media.first(where: { $0 is TelegramMediaImage }) as? TelegramMediaImage else {
            return nil
        }
        let representations = image.representations.sorted(by: { $0.dimensions.width * $0.dimensions.height < $1.dimensions.width * $1.dimensions.height })
        guard let representation = representations.last(where: { max($0.dimensions.width, $0.dimensions.height) <= 1600 }) ?? representations.last else {
            return nil
        }
        let reference = ImageMediaReference.message(message: MessageReference(message._asMessage()), media: image).resourceReference(representation.resource)
        let fetch = context.engine.resources.fetch(reference: reference, userLocation: .peer(message.id.peerId), userContentType: .image).start()
        defer {
            fetch.dispose()
        }
        let path: String? = await withCheckedContinuation { continuation in
            let resumed = Atomic<Bool>(value: false)
            let disposable = MetaDisposable()
            disposable.set((context.engine.resources.data(id: EngineMediaResource.Id(representation.resource.id))
            |> filter { $0.isComplete }
            |> take(1)
            |> timeout(25.0, queue: Queue.mainQueue(), alternate: .complete())).start(next: { data in
                if !resumed.swap(true) {
                    continuation.resume(returning: data.path)
                }
            }, completed: {
                if !resumed.swap(true) {
                    continuation.resume(returning: nil)
                }
            }))
        }
        guard let path, let uiImage = UIImage(contentsOfFile: path) else {
            return nil
        }
        return AgentImageLoader.encode(uiImage)
    }
}
