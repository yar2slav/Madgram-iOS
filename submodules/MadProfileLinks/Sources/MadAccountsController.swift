import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import MadProfileLinksCore

public func madAccountsController(context: AccountContext) -> ViewController {
    return MadAccountsController(context: context)
}

public func madProfileAccountsListController(context: AccountContext, accounts: [MadLinksAccount]) -> ViewController {
    return MadProfileAccountsListController(context: context, accounts: accounts)
}

func madAccountSubtitle(_ account: MadLinksAccount, strings: MadAccountsStrings, showHidden: Bool) -> String {
    var result = account.title
    if showHidden && !account.visible {
        result += " · " + strings.hidden
    }
    return result
}

final class MadAccountsController: MadLinksTableController {
    private let api: MadLinksAPI
    private var profile: MadLinksProfile?
    private var errorText: String?
    private var isLoading = false
    private var isReordering = false
    private var draftsObserver: NSObjectProtocol?
    private lazy var domainFlow = MadDomainFlow(context: self.context, api: self.api, strings: self.strings, controller: self, linked: { [weak self] in
        self?.reloadProfile()
    })

    override init(context: AccountContext) {
        self.api = MadLinksAPI(context: context)
        super.init(context: context)
        self.title = self.strings.title
        self.updateNavigationButton()
        self.load()
        self.draftsObserver = NotificationCenter.default.addObserver(forName: MadDomainDrafts.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.reloadSections()
        })
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let draftsObserver = self.draftsObserver {
            NotificationCenter.default.removeObserver(draftsObserver)
        }
    }

    private func reloadProfile() {
        Task { @MainActor [weak self] in
            guard let self, let profile = try? await self.api.myAccounts() else {
                return
            }
            self.apply(profile)
        }
    }

    private func updateNavigationButton() {
        if let profile = self.profile, profile.accounts.count > 1 {
            let title = self.isReordering ? self.strings.done : self.strings.reorder
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: title, style: self.isReordering ? .done : .plain, target: self, action: #selector(self.reorderPressed))
        } else {
            self.navigationItem.rightBarButtonItem = nil
        }
    }

    @objc private func reorderPressed() {
        self.isReordering = !self.isReordering
        self.updateNavigationButton()
        if self.isNodeLoaded {
            self.tableView.setEditing(self.isReordering, animated: true)
            self.tableView.reloadData()
        }
    }

    func load() {
        guard !self.isLoading else {
            return
        }
        self.isLoading = true
        self.errorText = nil
        self.reloadSections()
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                let profile = try await self.api.myAccounts()
                self.profile = profile
                self.errorText = nil
            } catch {
                self.errorText = MadLinksUI.errorText(error, strings: self.strings)
            }
            self.isLoading = false
            self.updateNavigationButton()
            self.reloadSections()
        }
    }

    override func buildSections() -> [MadLinksTableSection] {
        guard let profile = self.profile else {
            if let errorText = self.errorText {
                return [
                    MadLinksTableSection(header: nil, footer: nil, rows: [.text(errorText)]),
                    MadLinksTableSection(header: nil, footer: nil, rows: [.action(title: self.strings.retry, destructive: false, centered: true, accessory: .none, action: { [weak self] in
                        self?.load()
                    })])
                ]
            }
            return [MadLinksTableSection(header: nil, footer: nil, rows: [.loading])]
        }
        var sections: [MadLinksTableSection] = []
        sections.append(MadLinksTableSection(header: self.strings.designSection, footer: self.strings.designInfo, rows: [.design(profile.design, update: { [weak self] design in
            self?.setDesign(design)
        })]))
        var accountRows: [MadLinksRow] = []
        for account in profile.accounts {
            accountRows.append(.account(account, subtitle: madAccountSubtitle(account, strings: self.strings, showHidden: true), accessory: .chevron, action: { [weak self] in
                self?.openAccount(id: account.id)
            }))
        }
        if accountRows.isEmpty {
            accountRows.append(.text(self.strings.empty))
        }
        sections.append(MadLinksTableSection(header: self.strings.mySection, footer: nil, rows: accountRows))
        let linkedDomains = Set(profile.accounts.filter { $0.platform == "domain" }.map { $0.handle.lowercased() })
        let drafts = MadDomainDrafts.list(accountId: self.context.account.peerId.toInt64()).filter { !linkedDomains.contains($0.displayDomain.lowercased()) && !linkedDomains.contains($0.domain) }
        if !drafts.isEmpty {
            let draftRows: [MadLinksRow] = drafts.map { claim in
                let account = MadLinksAccount(id: "draft:" + claim.domain, platform: "domain", handle: claim.displayDomain, displayName: claim.displayDomain, url: nil, verified: false, visible: false, position: 0)
                return .account(account, subtitle: claim.displayDomain + " · " + self.strings.domainDraftStatus, accessory: .chevron, action: { [weak self] in
                    self?.domainFlow.showInstructions(claim)
                })
            }
            sections.append(MadLinksTableSection(header: self.strings.draftsSection, footer: nil, rows: draftRows))
        }
        sections.append(MadLinksTableSection(header: nil, footer: self.strings.info, rows: [.action(title: self.strings.add, destructive: false, centered: false, accessory: .chevron, action: { [weak self] in
            self?.openAdd()
        })]))
        return sections
    }

    override func canMove(indexPath: IndexPath) -> Bool {
        guard self.isReordering, let profile = self.profile, indexPath.section == 1 else {
            return false
        }
        return indexPath.row < profile.accounts.count
    }

    override func move(from: IndexPath, to: IndexPath) {
        guard let profile = self.profile, from.row < profile.accounts.count, to.row < profile.accounts.count else {
            return
        }
        var accounts = profile.accounts
        let account = accounts.remove(at: from.row)
        accounts.insert(account, at: to.row)
        var changes: [(String, Int)] = []
        for (index, account) in accounts.enumerated() {
            if account.position != index {
                changes.append((account.id, index))
                accounts[index] = account.withPosition(index)
            }
        }
        self.apply(MadLinksProfile(design: profile.design, accounts: accounts), reload: false)
        guard !changes.isEmpty else {
            return
        }
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                for (id, position) in changes {
                    try await self.api.updateAccount(id: id, position: position)
                }
            } catch {
                self.toast(MadLinksUI.errorText(error, strings: self.strings))
                self.load()
            }
        }
    }

    private func apply(_ profile: MadLinksProfile, reload: Bool = true) {
        self.profile = profile
        self.api.publishOwn(profile)
        self.updateNavigationButton()
        if reload {
            self.reloadSections()
        } else {
            self.sections = self.buildSections()
        }
    }

    private func setDesign(_ design: MadLinksDesign) {
        guard let profile = self.profile, profile.design != design else {
            return
        }
        self.apply(MadLinksProfile(design: design, accounts: profile.accounts), reload: false)
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                try await self.api.setDesign(design)
            } catch {
                self.toast(MadLinksUI.errorText(error, strings: self.strings))
                if let current = self.profile {
                    self.apply(MadLinksProfile(design: profile.design, accounts: current.accounts))
                }
            }
        }
    }

    private func openAccount(id: String) {
        guard let account = self.profile?.accounts.first(where: { $0.id == id }) else {
            return
        }
        let controller = MadAccountDetailController(context: self.context, account: account, updated: { [weak self] updated in
            guard let self, let profile = self.profile else {
                return
            }
            self.apply(MadLinksProfile(design: profile.design, accounts: profile.accounts.map { $0.id == updated.id ? updated : $0 }))
        }, removed: { [weak self] id in
            guard let self, let profile = self.profile else {
                return
            }
            self.apply(MadLinksProfile(design: profile.design, accounts: profile.accounts.filter { $0.id != id }))
        })
        self.push(controller)
    }

    private func openAdd() {
        let controller = MadAddAccountController(context: self.context, accounts: self.profile?.accounts ?? [], openAccount: { [weak self] id in
            self?.openAccount(id: id)
        }, changed: { [weak self] profile in
            self?.apply(profile)
        })
        self.push(controller)
    }
}

final class MadAccountDetailController: MadLinksTableController {
    private let api: MadLinksAPI
    private var account: MadLinksAccount
    private let updated: (MadLinksAccount) -> Void
    private let removed: (String) -> Void
    private var isBusy = false
    private lazy var connector = MadLinksConnector(context: self.context, api: self.api, strings: self.strings, controller: self)

    init(context: AccountContext, account: MadLinksAccount, updated: @escaping (MadLinksAccount) -> Void, removed: @escaping (String) -> Void) {
        self.api = MadLinksAPI(context: context)
        self.account = account
        self.updated = updated
        self.removed = removed
        super.init(context: context)
        self.title = MadLinksPlatformInfo.name(account.platform)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        super.loadDisplayNode()
        self.tableView.tableHeaderView = self.makeHeader()
    }

    private func makeHeader() -> UIView {
        let theme = self.presentationData.theme
        let view = MadAccountHeaderView(frame: CGRect(x: 0.0, y: 0.0, width: max(320.0, self.tableView.bounds.width), height: 168.0))
        MadLinksUI.setIcon(for: self.account, apply: { [weak view] image in
            view?.icon.image = image
        })
        view.title.textColor = theme.list.itemPrimaryTextColor
        view.title.text = self.account.title
        view.platform.textColor = theme.list.itemSecondaryTextColor
        view.platform.text = MadLinksPlatformInfo.name(self.account.platform)
        if self.account.verified {
            let text = NSMutableAttributedString()
            if let image = MadLinksUI.verifiedImage(color: theme.list.itemCheckColors.fillColor, size: 11.0) {
                let attachment = NSTextAttachment(image: image)
                attachment.bounds = CGRect(x: 0.0, y: -2.0, width: image.size.width, height: image.size.height)
                text.append(NSAttributedString(attachment: attachment))
                text.append(NSAttributedString(string: " "))
            }
            text.append(NSAttributedString(string: self.strings.verified, attributes: [.font: UIFont.systemFont(ofSize: 13.0), .foregroundColor: theme.list.itemSecondaryTextColor]))
            view.verified.attributedText = text
        } else {
            view.verified.isHidden = true
        }
        return view
    }

    override func buildSections() -> [MadLinksTableSection] {
        var sections: [MadLinksTableSection] = []
        sections.append(MadLinksTableSection(header: nil, footer: self.strings.showInProfileInfo, rows: [.toggle(title: self.strings.showInProfile, value: self.account.visible, enabled: !self.isBusy, update: { [weak self] value in
            self?.setVisible(value)
        })]))
        if self.account.platform == "domain" {
            let current = self.account.icon
            sections.append(MadLinksTableSection(header: self.strings.iconSection, footer: self.strings.iconFaviconInfo, rows: [
                .choice(title: self.strings.iconGlobe, value: "", checked: current != "favicon", action: { [weak self] in
                    self?.setIcon("default")
                }),
                .choice(title: self.strings.iconFavicon, value: "", checked: current == "favicon", action: { [weak self] in
                    self?.setIcon("favicon")
                })
            ]))
        }
        if self.account.hasLabelChoice {
            let current = self.account.label
            sections.append(MadLinksTableSection(header: self.strings.labelSection, footer: nil, rows: [
                .choice(title: self.strings.labelHandle(self.account.platform), value: self.account.handle, checked: current == .handle, action: { [weak self] in
                    self?.setLabel(.handle)
                }),
                .choice(title: self.strings.labelName, value: self.account.displayName ?? "", checked: current == .name, action: { [weak self] in
                    self?.setLabel(.name)
                })
            ]))
        }
        var actionRows: [MadLinksRow] = []
        if let url = self.account.url {
            actionRows.append(.action(title: self.strings.openProfile, destructive: false, centered: false, accessory: .external, action: { [weak self] in
                self?.openUrl(url)
            }))
        }
        actionRows.append(.action(title: self.strings.refresh, destructive: false, centered: false, accessory: .none, action: { [weak self] in
            self?.refresh()
        }))
        sections.append(MadLinksTableSection(header: nil, footer: nil, rows: actionRows))
        if self.account.visible {
            let url = self.account.url
            sections.append(MadLinksTableSection(header: self.strings.inProfileSection, footer: nil, rows: [.account(self.account, subtitle: self.account.title, accessory: url == nil ? .none : .external, action: url.flatMap { url in
                return { [weak self] in
                    self?.openUrl(url)
                }
            })]))
        }
        sections.append(MadLinksTableSection(header: nil, footer: nil, rows: [.action(title: self.strings.disconnect, destructive: true, centered: true, accessory: .none, action: { [weak self] in
            self?.confirmDisconnect()
        })]))
        return sections
    }

    private func setVisible(_ value: Bool) {
        let previous = self.account
        self.account = previous.withVisible(value)
        self.updated(self.account)
        self.reloadSections()
        let id = previous.id
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                try await self.api.updateAccount(id: id, visible: value)
            } catch {
                self.toast(MadLinksUI.errorText(error, strings: self.strings))
                self.account = previous
                self.updated(previous)
                self.reloadSections()
            }
        }
    }

    private func apply(_ account: MadLinksAccount) {
        self.account = account
        self.updated(account)
        if self.isViewLoaded {
            self.tableView.tableHeaderView = self.makeHeader()
        }
        self.reloadSections()
    }

    private func setIcon(_ icon: String) {
        let previous = self.account
        guard previous.icon != icon, !self.isBusy else {
            return
        }
        self.apply(previous.withIcon(icon))
        let id = previous.id
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                try await self.api.updateAccount(id: id, icon: icon)
            } catch {
                self.toast(MadLinksUI.errorText(error, strings: self.strings))
                self.apply(previous)
            }
        }
    }

    private func setLabel(_ label: MadLinksAccountLabel) {
        let previous = self.account
        guard previous.label != label, !self.isBusy else {
            return
        }
        self.apply(previous.withLabel(label))
        let id = previous.id
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                try await self.api.updateAccount(id: id, label: label)
            } catch {
                self.toast(MadLinksUI.errorText(error, strings: self.strings))
                self.apply(previous)
            }
        }
    }

    private func refresh() {
        guard !self.isBusy, !self.connector.isConnecting else {
            return
        }
        self.isBusy = true
        self.reloadSections()
        let id = self.account.id
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                let fresh = try await self.api.refreshAccount(id: id)
                self.isBusy = false
                self.apply(fresh)
                self.toast(self.strings.refreshed)
            } catch MadLinksError.server(409) {
                self.isBusy = false
                self.reloadSections()
                await self.reconnect()
            } catch {
                self.isBusy = false
                self.reloadSections()
                self.toast(MadLinksUI.errorText(error, strings: self.strings))
            }
        }
    }

    private func reconnect() async {
        let platformId = self.account.platform
        guard let platform = (try? await self.api.platforms())?.first(where: { $0.id == platformId }), platform.available else {
            self.toast(self.strings.unavailable)
            return
        }
        let id = self.account.id
        self.connector.start(platform, linked: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                if let profile = try? await self.api.myAccounts(), let fresh = profile.accounts.first(where: { $0.id == id }) {
                    self.apply(fresh)
                }
                self.toast(self.strings.refreshed)
            }
        })
    }

    private func confirmDisconnect() {
        let name = MadLinksPlatformInfo.name(self.account.platform)
        let alert = textAlertController(context: self.context, title: nil, text: self.strings.disconnectConfirm(name), actions: [
            TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: self.strings.disconnectAction, action: { [weak self] in
                self?.disconnect()
            })
        ])
        self.present(alert, in: .window(.root))
    }

    private func disconnect() {
        guard !self.isBusy else {
            return
        }
        self.isBusy = true
        let id = self.account.id
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                try await self.api.deleteAccount(id: id)
                self.removed(id)
                _ = self.navigationController?.popViewController(animated: true)
            } catch {
                self.isBusy = false
                self.toast(MadLinksUI.errorText(error, strings: self.strings))
            }
        }
    }
}

final class MadProfileAccountsListController: MadLinksTableController {
    private let accounts: [MadLinksAccount]

    init(context: AccountContext, accounts: [MadLinksAccount]) {
        self.accounts = accounts
        super.init(context: context)
        self.title = self.strings.title
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func buildSections() -> [MadLinksTableSection] {
        let rows: [MadLinksRow] = self.accounts.map { account in
            let url = account.url
            return .account(account, subtitle: account.title, accessory: url == nil ? .none : .external, action: url.flatMap { url in
                return { [weak self] in
                    self?.openUrl(url)
                }
            })
        }
        return [MadLinksTableSection(header: nil, footer: nil, rows: rows)]
    }
}

private final class MadAccountHeaderView: UIView {
    let icon = UIImageView()
    let title = UILabel()
    let platform = UILabel()
    let verified = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.icon.contentMode = .scaleAspectFit
        self.title.font = UIFont.systemFont(ofSize: 22.0, weight: .bold)
        self.title.textAlignment = .center
        self.platform.font = UIFont.systemFont(ofSize: 13.0)
        self.platform.textAlignment = .center
        self.verified.textAlignment = .center
        for subview in [self.icon, self.title, self.platform, self.verified] as [UIView] {
            self.addSubview(subview)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        self.icon.frame = CGRect(x: floor((width - 66.0) / 2.0), y: 16.0, width: 66.0, height: 66.0)
        self.title.frame = CGRect(x: 16.0, y: 92.0, width: max(0.0, width - 32.0), height: 28.0)
        self.platform.frame = CGRect(x: 16.0, y: 120.0, width: max(0.0, width - 32.0), height: 18.0)
        self.verified.frame = CGRect(x: 16.0, y: 142.0, width: max(0.0, width - 32.0), height: 18.0)
    }
}
