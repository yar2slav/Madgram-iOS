import Foundation
import AVFoundation

final class MadSilentKeepAlive {
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var observers: [NSObjectProtocol] = []
    private var shouldRun = false

    var isRunning: Bool {
        return self.shouldRun
    }

    init() {
        let center = NotificationCenter.default
        self.observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main, using: { [weak self] notification in
            guard let self, self.shouldRun else {
                return
            }
            if let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, AVAudioSession.InterruptionType(rawValue: raw) == .ended {
                self.restart()
            }
        }))
        self.observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main, using: { [weak self] _ in
            guard let self, self.shouldRun else {
                return
            }
            self.restart()
        }))
        self.observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main, using: { [weak self] _ in
            guard let self, self.shouldRun else {
                return
            }
            self.restart()
        }))
    }

    deinit {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func start() {
        guard !self.shouldRun else {
            return
        }
        self.shouldRun = true
        self.startEngine()
    }

    func stop() {
        guard self.shouldRun else {
            return
        }
        self.shouldRun = false
        self.stopEngine()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func restart() {
        self.stopEngine()
        self.startEngine()
    }

    private func startEngine() {
        guard self.engine == nil else {
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return
        }
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 22050.0, channels: 1), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 22050) else {
            return
        }
        buffer.frameLength = 22050
        if let channel = buffer.floatChannelData?[0] {
            channel.update(repeating: 0.0, count: Int(buffer.frameLength))
        }
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            return
        }
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
        self.engine = engine
        self.player = player
    }

    private func stopEngine() {
        self.player?.stop()
        self.engine?.stop()
        self.player = nil
        self.engine = nil
    }
}
