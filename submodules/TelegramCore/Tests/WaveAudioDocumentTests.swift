import XCTest
@testable import TelegramCore

final class WaveAudioDocumentTests: XCTestCase {
    private func file(mimeType: String, attributes: [TelegramMediaFileAttribute]) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: 1), partialReference: nil, resource: LocalFileMediaResource(fileId: 1), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: 100, attributes: attributes, alternativeRepresentations: [])
    }

    func testWaveMimeTypesAreRecognized() {
        for mimeType in ["audio/wav", "audio/x-wav", "audio/wave", "audio/vnd.wave", "AUDIO/WAV"] {
            XCTAssertTrue(isWaveAudioDocument(mimeType: mimeType, fileName: nil), mimeType)
        }
        XCTAssertFalse(isWaveAudioDocument(mimeType: "audio/mpeg", fileName: "track.mp3"))
    }

    func testWaveFileNameIsRecognizedWhateverTheMimeType() {
        XCTAssertTrue(isWaveAudioDocument(mimeType: "application/octet-stream", fileName: "Take 3.WAV"))
        XCTAssertFalse(isWaveAudioDocument(mimeType: "application/octet-stream", fileName: "wav.txt"))
    }

    func testPlainWaveDocumentIsMusic() {
        let document = self.file(mimeType: "audio/x-wav", attributes: [.FileName(fileName: "beat.wav")])
        XCTAssertTrue(document.isWaveAudio)
        XCTAssertTrue(document.isMusic)
    }

    func testWaveWithVoiceAttributeStaysVoice() {
        let document = self.file(mimeType: "audio/x-wav", attributes: [.Audio(isVoice: true, duration: 3, title: nil, performer: nil, waveform: nil)])
        XCTAssertFalse(document.isWaveAudio)
        XCTAssertFalse(document.isMusic)
        XCTAssertTrue(document.isVoice)
    }

    func testOtherDocumentsAreNotMusic() {
        let document = self.file(mimeType: "application/zip", attributes: [.FileName(fileName: "beat.zip")])
        XCTAssertFalse(document.isMusic)
    }
}
