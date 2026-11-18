import Foundation
import UIKit
import AuthenticationServices
import Display
import AccountContext
import TelegramPresentationData
import MadProfileLinksCore

final class MadLinksConnector: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let context: AccountContext
    private let api: MadLinksAPI
    private let strings: MadAccountsStrings
    private weak var controller: ViewController?
    private var authSession: ASWebAuthenticationSession?
    private(set) var isConnecting = false

    init(context: AccountContext, api: MadLinksAPI, strings: MadAccountsStrings, controller: ViewController) {
        self.context = context
        self.api = api
        self.strings = strings
        self.controller = controller
        super.init()
    }

    deinit {
        self.authSession?.cancel()
    }

    func start(_ platform: MadLinksPlatform, linked: @escaping () -> Void) {
        guard !self.isConnecting else {
            return
        }
        if platform.needsClientId {
            if let saved = MadLinksClientIds.get(platform.id) {
                self.connect(platform, clientId: saved, linked: linked)
            } else {
                self.askClientId(platform, linked: linked)
            }
            return
        }
        self.connect(platform, clientId: nil, linked: linked)
    }

    private func toast(_ text: String) {
        guard let controller = self.controller else {
            return
        }
        MadLinksUI.toast(controller, context: self.context, text: text)
    }

    private func askClientId(_ platform: MadLinksPlatform, error: Bool = false, linked: @escaping () -> Void) {
        let redirect = MadLinksConfig.baseUrl.appendingPathComponent("api/v1/connect/\(platform.id)/callback").absoluteString
        let message = (error ? self.strings.clientIdInvalid + "\n\n" : "") + self.strings.clientIdText(redirect)
        let alert = UIAlertController(title: self.strings.clientIdTitle(platform.name), message: message, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Client ID"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.text = MadLinksClientIds.get(platform.id)
        }
        alert.addAction(UIAlertAction(title: self.strings.clientIdCopyRedirect, style: .default, handler: { [weak self] _ in
            UIPasteboard.general.string = redirect
            self?.askClientId(platform, linked: linked)
        }))
        alert.addAction(UIAlertAction(title: self.strings.clientIdCancel, style: .cancel))
        alert.addAction(UIAlertAction(title: self.strings.clientIdContinue, style: .default, handler: { [weak self, weak alert] _ in
            guard let self else {
                return
            }
            let value = (alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard MadLinksParsing.isValidClientId(value) else {
                self.askClientId(platform, error: true, linked: linked)
                return
            }
            MadLinksClientIds.set(value, for: platform.id)
            self.connect(platform, clientId: value, linked: linked)
        }))
        self.controller?.view.window?.rootViewController?.present(alert, animated: true)
    }

    private func connect(_ platform: MadLinksPlatform, clientId: String?, linked: @escaping () -> Void) {
        guard !self.isConnecting else {
            return
        }
        self.isConnecting = true
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                let url = try await self.api.connectUrl(platform: platform.id, clientId: clientId)
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: MadLinksConfig.callbackScheme, completionHandler: { [weak self] callbackUrl, error in
                    DispatchQueue.main.async {
                        self?.handleCallback(platform: platform, url: callbackUrl, error: error, linked: linked)
                    }
                })
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                self.authSession = session
                if !session.start() {
                    self.isConnecting = false
                    self.authSession = nil
                    self.toast(self.strings.linkFailed)
                }
            } catch {
                self.isConnecting = false
                self.toast(MadLinksUI.errorText(error, strings: self.strings))
            }
        }
    }

    private func handleCallback(platform: MadLinksPlatform, url: URL?, error: Error?, linked: @escaping () -> Void) {
        self.isConnecting = false
        self.authSession = nil
        if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
            return
        }
        guard let url else {
            self.toast(self.strings.linkFailed)
            return
        }
        switch MadLinksParsing.connectResult(url) {
        case .linked:
            linked()
        case .failed, .unknown:
            if platform.needsClientId {
                MadLinksClientIds.set(nil, for: platform.id)
            }
            self.toast(self.strings.linkFailed)
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.controller?.view.window ?? ASPresentationAnchor()
    }
}

enum MadLinksClientIds {
    private static func key(_ platform: String) -> String {
        return "madgram.links.clientId.\(platform)"
    }

    static func get(_ platform: String) -> String? {
        guard let value = UserDefaults.standard.string(forKey: key(platform)), MadLinksParsing.isValidClientId(value) else {
            return nil
        }
        return value
    }

    static func set(_ value: String?, for platform: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key(platform))
        } else {
            UserDefaults.standard.removeObject(forKey: key(platform))
        }
    }
}
