import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData
import MadProfileLinksCore

enum MadDomainDrafts {
    static let didChangeNotification = Notification.Name("MadDomainDraftsDidChange")

    private static func key(_ accountId: Int64) -> String {
        return "madgram.links.domainDrafts.\(accountId)"
    }

    static func list(accountId: Int64) -> [MadLinksDomainClaim] {
        guard let items = UserDefaults.standard.array(forKey: self.key(accountId)) as? [[String: String]] else {
            return []
        }
        return items.compactMap { item in
            guard let domain = item["domain"], let recordName = item["recordName"], let recordValue = item["recordValue"] else {
                return nil
            }
            return MadLinksDomainClaim(domain: domain, displayDomain: item["displayDomain"] ?? domain, recordName: recordName, recordValue: recordValue)
        }
    }

    private static func save(_ claims: [MadLinksDomainClaim], accountId: Int64) {
        UserDefaults.standard.set(claims.map { ["domain": $0.domain, "displayDomain": $0.displayDomain, "recordName": $0.recordName, "recordValue": $0.recordValue] }, forKey: self.key(accountId))
        NotificationCenter.default.post(name: self.didChangeNotification, object: nil)
    }

    static func add(_ claim: MadLinksDomainClaim, accountId: Int64) {
        var claims = self.list(accountId: accountId).filter { $0.domain != claim.domain }
        claims.append(claim)
        self.save(claims, accountId: accountId)
    }

    static func remove(domain: String, accountId: Int64) {
        let claims = self.list(accountId: accountId)
        let filtered = claims.filter { $0.domain != domain }
        if filtered.count != claims.count {
            self.save(filtered, accountId: accountId)
        }
    }
}

final class MadDomainFlow {
    private let context: AccountContext
    private let api: MadLinksAPI
    private let strings: MadAccountsStrings
    private weak var controller: ViewController?
    private let linked: () -> Void

    init(context: AccountContext, api: MadLinksAPI, strings: MadAccountsStrings, controller: ViewController, linked: @escaping () -> Void) {
        self.context = context
        self.api = api
        self.strings = strings
        self.controller = controller
        self.linked = linked
    }

    private var accountId: Int64 {
        return self.context.account.peerId.toInt64()
    }

    private func present(_ alert: UIAlertController) {
        self.controller?.view.window?.rootViewController?.present(alert, animated: true)
    }

    private func toast(_ text: String) {
        guard let controller = self.controller else {
            return
        }
        MadLinksUI.toast(controller, context: self.context, text: text)
    }

    func askDomain(error: Bool = false, text: String? = nil) {
        let alert = UIAlertController(title: self.strings.domainTitle, message: error ? self.strings.domainInvalid : self.strings.domainText, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "example.com"
            field.text = text
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: self.strings.clientIdCancel, style: .cancel))
        alert.addAction(UIAlertAction(title: self.strings.clientIdContinue, style: .default, handler: { [weak self, weak alert] _ in
            guard let self else {
                return
            }
            let value = (alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.contains("."), value.count >= 4 else {
                self.askDomain(error: true, text: value)
                return
            }
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                do {
                    let claim = try await self.api.claimDomain(value)
                    MadDomainDrafts.add(claim, accountId: self.accountId)
                    self.showInstructions(claim)
                } catch MadLinksError.server(400) {
                    self.askDomain(error: true, text: value)
                } catch {
                    self.toast(MadLinksUI.errorText(error, strings: self.strings))
                }
            }
        }))
        self.present(alert)
    }

    func showInstructions(_ claim: MadLinksDomainClaim) {
        let alert = UIAlertController(title: self.strings.domainVerifyTitle, message: self.strings.domainVerifyText(claim.recordName, claim.recordValue), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: self.strings.domainCopy, style: .default, handler: { [weak self] _ in
            UIPasteboard.general.string = claim.recordValue
            self?.showInstructions(claim)
        }))
        alert.addAction(UIAlertAction(title: self.strings.domainCheck, style: .default, handler: { [weak self] _ in
            self?.verify(claim)
        }))
        alert.addAction(UIAlertAction(title: self.strings.domainDraftDelete, style: .destructive, handler: { [weak self] _ in
            guard let self else {
                return
            }
            MadDomainDrafts.remove(domain: claim.domain, accountId: self.accountId)
        }))
        alert.addAction(UIAlertAction(title: self.strings.domainLater, style: .cancel))
        self.present(alert)
    }

    func verify(_ claim: MadLinksDomainClaim) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                _ = try await self.api.verifyDomain(claim.domain)
                MadDomainDrafts.remove(domain: claim.domain, accountId: self.accountId)
                self.linked()
                self.toast(self.strings.linked(claim.displayDomain))
            } catch MadLinksError.server(422) {
                self.toast(self.strings.domainNotFound)
                self.showInstructions(claim)
            } catch {
                self.toast(MadLinksUI.errorText(error, strings: self.strings))
            }
        }
    }
}
