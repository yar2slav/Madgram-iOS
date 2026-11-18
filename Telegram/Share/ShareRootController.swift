import UIKit
import PasscodeCore
import TelegramUI
import BuildConfig
import ShareExtensionContext
import SwiftSignalKit
import TelegramCore

@objc(ShareRootController)
class ShareRootController: UIViewController {
    private var impl: ShareRootControllerImpl?
    private var checkedTelegramLink = false
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        
        if self.impl == nil {
            let appBundleIdentifier = Bundle.main.bundleIdentifier!
            guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
                return
            }
            
            let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
            
            let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
            
            let languagesCategory = "ios"
            
            let appGroupName = "group.\(baseAppBundleId)"
            try! PasscodeEnvironment.shared.configure(PasscodeConfiguration(appGroupIdentifier: appGroupName, processRole: .appExtension))
            let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
            
            guard let appGroupUrl = maybeAppGroupUrl else {
                self.madHandoffToApp()
                return
            }
            
            let rootPath = appGroupUrl.path + "/telegram-data"
            
            let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
            let encryptionParameters: (Data, Data) = (deviceSpecificEncryptionParameters.key, deviceSpecificEncryptionParameters.salt)
            
            let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
            
            self.impl = ShareRootControllerImpl(initializationData: ShareRootControllerInitializationData(appBundleId: baseAppBundleId, appBuildType: buildConfig.isAppStoreBuild ? .public : .internal, appGroupPath: appGroupUrl.path, apiId: buildConfig.apiId, apiHash: buildConfig.apiHash, languagesCategory: languagesCategory, encryptionParameters: encryptionParameters, appVersion: appVersion, bundleData: buildConfig.bundleData(withAppToken: nil, tokenType: nil, tokenEnvironment: nil, signatureDict: nil), useBetaFeatures: !buildConfig.isAppStoreBuild, makeTempContext: { accountManager, appLockContext, applicationBindings, InitialPresentationDataAndSettings, networkArguments in
                return makeTempContext(
                    sharedContainerPath: appGroupUrl.path,
                    rootPath: rootPath,
                    appGroupPath: appGroupUrl.path,
                    accountManager: accountManager,
                    appLockContext: appLockContext,
                    encryptionParameters: EngineValueBoxEncryptionParameters(
                        forceEncryptionIfNoSet: false,
                        key: EngineValueBoxEncryptionParameters.Key(data: encryptionParameters.0)!,
                        salt: EngineValueBoxEncryptionParameters.Salt(data: encryptionParameters.1)!
                    ),
                    applicationBindings: applicationBindings,
                    initialPresentationDataAndSettings: InitialPresentationDataAndSettings,
                    networkArguments: networkArguments,
                    buildConfig: buildConfig
                )
            }), getExtensionContext: { [weak self] in
                return self?.extensionContext
            })
            
            self.impl?.openUrl = { [weak self] url in
                guard let self, let url = URL(string: url) else {
                    return
                }
                let _ = self.openURL(ShareRootController.madgramUrl(url))
            }
        }
        
        self.impl?.loadView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.impl?.viewWillAppear()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !self.checkedTelegramLink {
            self.checkedTelegramLink = true
            self.offerOpeningTelegramLink()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.impl?.viewWillDisappear()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.impl?.viewWillDisappear()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.impl?.viewDidLayoutSubviews(view: self.view, traitCollection: self.traitCollection)
    }
    
    private static func madgramUrl(_ url: URL) -> URL {
        if url.scheme?.lowercased() == "mad" {
            return url
        }
        var components = URLComponents()
        components.scheme = "mad"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        return components.url ?? url
    }
    
    private static func isTelegramLink(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "tg" {
            return true
        }
        guard scheme == "https" || scheme == "http", let host = url.host?.lowercased() else {
            return false
        }
        return ["t.me", "www.t.me", "telegram.me", "www.telegram.me", "telegram.dog"].contains(host) || host.hasSuffix(".t.me")
    }
    
    private static func telegramLink(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), isTelegramLink(url) {
            return url
        }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let matches = detector.matches(in: trimmed, options: [], range: NSRange(location: 0, length: (trimmed as NSString).length))
        if matches.count == 1, let url = matches[0].url, isTelegramLink(url), matches[0].range.length >= (trimmed as NSString).length - 1 {
            return url
        }
        return nil
    }
    
    private static func localized(_ ru: String, _ uk: String, _ en: String) -> String {
        let language = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if language.hasPrefix("ru") {
            return ru
        } else if language.hasPrefix("uk") {
            return uk
        }
        return en
    }
    
    private func offerOpeningTelegramLink() {
        guard let items = self.extensionContext?.inputItems as? [NSExtensionItem] else {
            return
        }
        let providers = items.flatMap { $0.attachments ?? [] }
        guard providers.count == 1, let provider = providers.first else {
            return
        }
        let handle: (URL?) -> Void = { [weak self] url in
            guard let url, ShareRootController.isTelegramLink(url) else {
                return
            }
            DispatchQueue.main.async {
                self?.presentTelegramLinkPrompt(url)
            }
        }
        if provider.hasItemConformingToTypeIdentifier("public.url") {
            provider.loadItem(forTypeIdentifier: "public.url", options: nil, completionHandler: { item, _ in
                if let url = item as? URL {
                    handle(url)
                } else if let string = item as? String {
                    handle(ShareRootController.telegramLink(in: string))
                }
            })
        } else if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
            provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil, completionHandler: { item, _ in
                if let string = item as? String {
                    handle(ShareRootController.telegramLink(in: string))
                } else if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                    handle(ShareRootController.telegramLink(in: string))
                }
            })
        }
    }
    
    private func presentTelegramLinkPrompt(_ url: URL) {
        let alert = UIAlertController(title: url.absoluteString, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: ShareRootController.localized("Открыть в mad", "Відкрити в mad", "Open in mad"), style: .default, handler: { [weak self] _ in
            guard let self else {
                return
            }
            let _ = self.openURL(ShareRootController.madgramUrl(url))
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }))
        alert.addAction(UIAlertAction(title: ShareRootController.localized("Отправить в чат", "Надіслати в чат", "Send to a Chat"), style: .cancel, handler: nil))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1.0, height: 1.0)
            popover.permittedArrowDirections = []
        }
        var presenter: UIViewController = self
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(alert, animated: true)
    }
    
    private func madHandoffToApp() {
        self.checkedTelegramLink = true
        guard let items = self.extensionContext?.inputItems as? [NSExtensionItem] else {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        let providers = items.flatMap { $0.attachments ?? [] }
        let group = DispatchGroup()
        let lock = NSLock()
        var collected: [(Int, [String: Any])] = []
        func add(_ index: Int, _ item: [String: Any]) {
            lock.lock()
            collected.append((index, item))
            lock.unlock()
        }
        for (index, provider) in providers.enumerated() {
            group.enter()
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadItem(forTypeIdentifier: "public.image", options: nil, completionHandler: { item, _ in
                    var data: Data?
                    if let url = item as? URL {
                        data = try? Data(contentsOf: url)
                    } else if let image = item as? UIImage {
                        data = image.jpegData(compressionQuality: 0.9)
                    } else if let value = item as? Data {
                        data = value
                    }
                    if let data, let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) {
                        add(index, ["public.jpeg": jpeg])
                    }
                    group.leave()
                })
            } else if provider.hasItemConformingToTypeIdentifier("public.file-url") || provider.hasItemConformingToTypeIdentifier("public.data") && !provider.hasItemConformingToTypeIdentifier("public.url") && !provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                let type = provider.hasItemConformingToTypeIdentifier("public.file-url") ? "public.file-url" : "public.data"
                provider.loadItem(forTypeIdentifier: type, options: nil, completionHandler: { item, _ in
                    if let url = item as? URL, let data = try? Data(contentsOf: url) {
                        let info = ["name": url.lastPathComponent, "mime": "application/octet-stream"]
                        if let infoData = try? JSONSerialization.data(withJSONObject: info) {
                            add(index, ["org.madgram.share-file": infoData, "public.data": data])
                        }
                    } else if let data = item as? Data {
                        let info = ["name": "file", "mime": "application/octet-stream"]
                        if let infoData = try? JSONSerialization.data(withJSONObject: info) {
                            add(index, ["org.madgram.share-file": infoData, "public.data": data])
                        }
                    }
                    group.leave()
                })
            } else if provider.hasItemConformingToTypeIdentifier("public.url") {
                provider.loadItem(forTypeIdentifier: "public.url", options: nil, completionHandler: { item, _ in
                    if let url = item as? URL {
                        add(index, ["public.url": url])
                    } else if let string = item as? String {
                        add(index, ["public.utf8-plain-text": string])
                    }
                    group.leave()
                })
            } else if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil, completionHandler: { item, _ in
                    if let string = item as? String {
                        add(index, ["public.utf8-plain-text": string])
                    } else if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                        add(index, ["public.utf8-plain-text": string])
                    }
                    group.leave()
                })
            } else {
                group.leave()
            }
        }
        group.notify(queue: .main, execute: { [weak self] in
            guard let self else {
                return
            }
            let sorted = collected.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
            if !sorted.isEmpty {
                UIPasteboard.general.setItems([["org.madgram.share-handoff": Data([1])]] + sorted, options: [.localOnly: true, .expirationDate: Date(timeIntervalSinceNow: 300)])
                let _ = self.openURL(URL(string: "mad://share")!)
            }
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        })
    }
    
    @objc func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                if #available(iOS 18.0, *) {
                    application.open(url, options: [:], completionHandler: nil)
                    return true
                } else {
                    return application.perform(#selector(openURL(_:)), with: url) != nil
                }
            }
            responder = responder?.next
        }
        return false
    }
}
