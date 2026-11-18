import UIKit
import SwiftSignalKit
import LocalAuthentication
import TelegramPresentationData
import TelegramUIPreferences

public enum MadLock {
    private static var skipUntilRestart = false
    private static let skipUntilKey = "madgram.spendSkipUntil"

    public static var hasPassword: Bool {
        return MadLockCredentialStore.load() != nil
    }

    public static var kind: MadLockKind? {
        return MadLockCredentialStore.load()?.kind
    }

    public static var biometricsEnabled: Bool {
        return MadLockCredentialStore.load()?.biometrics ?? false
    }

    public static var biometricsAvailable: Bool {
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    public static func setBiometricsEnabled(_ value: Bool) {
        guard var credential = MadLockCredentialStore.load() else {
            return
        }
        credential.biometrics = value
        MadLockCredentialStore.store(credential)
    }

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first(where: { $0.rootViewController != nil })
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    private static func present(_ controller: UIViewController) {
        guard let top = topViewController() else {
            return
        }
        top.present(controller, animated: true)
    }

    public static func presentSetup(strings: PresentationStrings, completion: @escaping (Bool) -> Void) {
        let more = strings.localFeatures.more
        let start = {
            present(MadLockPromptController(mode: .create, strings: more, completion: { success, _ in
                completion(success)
            }))
        }
        if hasPassword {
            requireUnlock(strings: strings, completion: { success in
                if success {
                    start()
                } else {
                    completion(false)
                }
            })
        } else {
            start()
        }
    }

    public static func removePassword(strings: PresentationStrings, completion: @escaping (Bool) -> Void) {
        requireUnlock(strings: strings, completion: { success in
            if success {
                MadLockCredentialStore.store(nil)
                MadStores.lockedChats.update { _ in [] }
                InterfaceTuningSettingsStore.shared.update { current in
                    var current = current
                    current.spendLockEnabled = false
                    return current
                }
            }
            completion(success)
        })
    }

    public static func requireUnlock(strings: PresentationStrings, completion: @escaping (Bool) -> Void) {
        guard hasPassword else {
            completion(true)
            return
        }
        present(MadLockPromptController(mode: .verify(showSkip: false), strings: strings.localFeatures.more, completion: { success, _ in
            completion(success)
        }))
    }

    private static var isSkipping: Bool {
        if skipUntilRestart {
            return true
        }
        let until = UserDefaults.standard.double(forKey: skipUntilKey)
        return until > Date().timeIntervalSince1970
    }

    public static func needsSpendAuthorization(_ kind: MadSubToggle) -> Bool {
        let settings = InterfaceTuningSettingsStore.shared.cached
        return hasPassword && settings.on(settings.spendLockEnabled, kind) && !isSkipping
    }

    public static func requireSpend(_ kind: MadSubToggle, strings: PresentationStrings, completion: @escaping () -> Void) {
        guard needsSpendAuthorization(kind) else {
            completion()
            return
        }
        DispatchQueue.main.async {
            present(MadLockPromptController(mode: .verify(showSkip: true), strings: strings.localFeatures.more, completion: { success, skip in
                guard success else {
                    return
                }
                if let skip {
                    if skip < 0 {
                        skipUntilRestart = true
                    } else {
                        UserDefaults.standard.set(Date().timeIntervalSince1970 + skip, forKey: skipUntilKey)
                    }
                }
                completion()
            }))
        }
    }

    private static var bypassOnce: (kind: MadSubToggle, timestamp: CFAbsoluteTime)?

    public static func gate(_ kind: MadSubToggle, strings: PresentationStrings, retry: @escaping () -> Void) -> Bool {
        if let bypass = bypassOnce {
            bypassOnce = nil
            if bypass.kind == kind && CFAbsoluteTimeGetCurrent() - bypass.timestamp < 5.0 {
                return false
            }
        }
        guard needsSpendAuthorization(kind) else {
            return false
        }
        requireSpend(kind, strings: strings, completion: {
            bypassOnce = (kind, CFAbsoluteTimeGetCurrent())
            retry()
            bypassOnce = nil
        })
        return true
    }

    public static func unlockChat(peerId: Int64, strings: PresentationStrings, completion: @escaping (Bool) -> Void) {
        guard MadChatLockSession.shared.isLocked(peerId: peerId) else {
            completion(true)
            return
        }
        requireUnlock(strings: strings, completion: { success in
            if success {
                MadChatLockSession.shared.markUnlocked(peerId: peerId)
            }
            completion(success)
        })
    }
}

public final class MadChatLockOverlay {
    private weak var hostView: UIView?
    private let peerId: Int64
    private let isPreview: Bool
    private let strings: PresentationStrings
    private let onCancel: () -> Void
    private var coverView: UIView?
    private var observer: NSObjectProtocol?
    private var isPrompting = false

    public init(hostView: UIView, peerId: Int64, isPreview: Bool, strings: PresentationStrings, onCancel: @escaping () -> Void) {
        self.hostView = hostView
        self.peerId = peerId
        self.isPreview = isPreview
        self.strings = strings
        self.onCancel = onCancel
        self.observer = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.check(prompt: true)
        })
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func check(prompt: Bool) {
        guard let hostView = self.hostView else {
            return
        }
        if MadChatLockSession.shared.isLocked(peerId: self.peerId) {
            if self.coverView == nil {
                let cover = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
                cover.frame = hostView.bounds
                cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                let icon = UIImageView(image: UIImage(systemName: "lock.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 44.0)))
                icon.tintColor = .secondaryLabel
                icon.translatesAutoresizingMaskIntoConstraints = false
                cover.contentView.addSubview(icon)
                NSLayoutConstraint.activate([
                    icon.centerXAnchor.constraint(equalTo: cover.contentView.centerXAnchor),
                    icon.centerYAnchor.constraint(equalTo: cover.contentView.centerYAnchor)
                ])
                hostView.addSubview(cover)
                self.coverView = cover
            }
            hostView.bringSubviewToFront(self.coverView!)
            if prompt && !self.isPreview && !self.isPrompting && UIApplication.shared.applicationState == .active {
                self.isPrompting = true
                MadLock.unlockChat(peerId: self.peerId, strings: self.strings, completion: { [weak self] success in
                    guard let self else {
                        return
                    }
                    self.isPrompting = false
                    if success {
                        self.check(prompt: false)
                    } else {
                        self.onCancel()
                    }
                })
            }
        } else if let coverView = self.coverView {
            self.coverView = nil
            UIView.animate(withDuration: 0.2, animations: {
                coverView.alpha = 0.0
            }, completion: { _ in
                coverView.removeFromSuperview()
            })
        }
    }
}

public func madSpendGate(_ kind: MadSubToggle, strings: PresentationStrings) -> Signal<Void, NoError> {
    return Signal { subscriber in
        Queue.mainQueue().async {
            MadLock.requireSpend(kind, strings: strings, completion: {
                subscriber.putNext(Void())
                subscriber.putCompletion()
            })
        }
        return EmptyDisposable
    }
}
