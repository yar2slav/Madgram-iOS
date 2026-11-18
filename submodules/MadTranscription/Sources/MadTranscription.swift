import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import ConvertOpusToAAC
import LocalAudioTranscription

public func madTranscribeLocally(context: AccountContext, message: EngineMessage, appLocale: String) -> Signal<LocallyTranscribedAudio?, NoError> {
    guard let file = message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile else {
        return .single(nil)
    }
    let fetch = freeMediaFileInteractiveFetched(account: context.account, userLocation: .peer(message.id.peerId), fileReference: .message(message: MessageReference(message._asMessage()), media: file))
    let audioPath: Signal<String?, NoError> = context.engine.resources.data(id: EngineMediaResource.Id(file.resource.id))
    |> filter { $0.isComplete }
    |> take(1)
    |> mapToSignal { data -> Signal<String?, NoError> in
        if file.isInstantVideo || file.isVideo {
            let path = EngineTempBox.shared.tempFile(fileName: "mad-transcription.mp4").path
            let _ = try? FileManager.default.removeItem(atPath: path)
            do {
                try FileManager.default.copyItem(atPath: data.path, toPath: path)
                return .single(path)
            } catch {
                return .single(nil)
            }
        }
        return convertOpusToAAC(sourcePath: data.path, allocateTempFile: {
            return EngineTempBox.shared.tempFile(fileName: "mad-transcription.m4a").path
        })
    }
    return Signal { subscriber in
        let fetchDisposable = fetch.start()
        let disposable = (audioPath
        |> mapToSignal { path -> Signal<LocallyTranscribedAudio?, NoError> in
            guard let path else {
                return .single(nil)
            }
            return transcribeAudio(path: path, appLocale: appLocale)
        }).start(next: { value in
            subscriber.putNext(value)
        }, completed: {
            subscriber.putCompletion()
        })
        return ActionDisposable {
            fetchDisposable.dispose()
            disposable.dispose()
        }
    }
}
