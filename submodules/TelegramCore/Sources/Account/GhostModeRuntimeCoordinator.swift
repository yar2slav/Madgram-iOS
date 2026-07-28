import Foundation
import Postbox
import SwiftSignalKit

final class GhostModeRuntimeCoordinator {
    private let queue = Queue()
    private let currentSettings = Atomic<GhostModeSettings>(value: .defaultSettings)
    private let temporaryOnlineValue = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let settingsDisposable = MetaDisposable()
    private var offlineTimer: SwiftSignalKit.Timer?

    let settings: Signal<GhostModeSettings, NoError>

    var temporaryOnline: Signal<Bool, NoError> {
        return self.temporaryOnlineValue.get()
    }

    init(postbox: Postbox) {
        let settings = postbox.preferencesView(keys: [PreferencesKeys.ghostModeSettings])
        |> map { view -> GhostModeSettings in
            return view.values[PreferencesKeys.ghostModeSettings]?.get(GhostModeSettings.self) ?? .defaultSettings
        }
        |> distinctUntilChanged
        self.settings = settings
        self.settingsDisposable.set((settings
        |> deliverOn(self.queue)).start(next: { [weak self] settings in
            guard let self else {
                return
            }
            let _ = self.currentSettings.swap(settings)
            if !settings.hidesOnlineStatus {
                self.offlineTimer?.invalidate()
                self.offlineTimer = nil
                self.temporaryOnlineValue.set(false)
            }
        }))
    }

    deinit {
        self.settingsDisposable.dispose()
        self.offlineTimer?.invalidate()
    }

    func revealPresence() {
        self.queue.async { [weak self] in
            guard let self else {
                return
            }
            let settings = self.currentSettings.with { $0 }
            guard settings.hidesOnlineStatus else {
                return
            }
            self.temporaryOnlineValue.set(true)
            self.offlineTimer?.invalidate()
            self.offlineTimer = nil
            if settings.goOfflineAutomatically {
                let timer = SwiftSignalKit.Timer(timeout: 2.0, repeat: false, completion: { [weak self] in
                    self?.temporaryOnlineValue.set(false)
                }, queue: self.queue)
                self.offlineTimer = timer
                timer.start()
            }
        }
    }
}
