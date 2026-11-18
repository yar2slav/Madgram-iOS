import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AccountContext
import TelegramPresentationData
import MadProfileLinksCore

private final class MadAddAccountNode: ASDisplayNode {
    override init() {
        super.init()
        self.setViewBlock({
            return UIView()
        })
    }
}

private final class MadPlatformTile: UIControl {
    let iconView = UIImageView()
    let nameLabel = UILabel()
    let statusLabel = UILabel()
    var platformId = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.layer.cornerRadius = 14.0
        self.layer.cornerCurve = .continuous
        self.iconView.contentMode = .scaleAspectFit
        self.iconView.isUserInteractionEnabled = false
        self.nameLabel.font = UIFont.systemFont(ofSize: 15.0, weight: .medium)
        self.nameLabel.textAlignment = .center
        self.nameLabel.isUserInteractionEnabled = false
        self.statusLabel.font = UIFont.systemFont(ofSize: 12.0)
        self.statusLabel.textAlignment = .center
        self.statusLabel.isUserInteractionEnabled = false
        self.addSubview(self.iconView)
        self.addSubview(self.nameLabel)
        self.addSubview(self.statusLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15, animations: {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            })
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = self.bounds.width
        self.iconView.frame = CGRect(x: (width - 34.0) / 2.0, y: 16.0, width: 34.0, height: 34.0)
        self.nameLabel.frame = CGRect(x: 4.0, y: 58.0, width: width - 8.0, height: 20.0)
        self.statusLabel.frame = CGRect(x: 4.0, y: 79.0, width: width - 8.0, height: 16.0)
    }
}

final class MadAddAccountController: ViewController {
    private enum Filter: Int, CaseIterable {
        case all
        case social
        case games
        case music
        case work

        var category: MadLinksCategory? {
            switch self {
            case .all:
                return nil
            case .social:
                return .social
            case .games:
                return .games
            case .music:
                return .music
            case .work:
                return .work
            }
        }
    }

    private let context: AccountContext
    private let api: MadLinksAPI
    private let presentationData: PresentationData
    private let strings: MadAccountsStrings
    private var accounts: [MadLinksAccount]
    private let openAccount: (String) -> Void
    private let changed: (MadLinksProfile) -> Void

    private var platforms: [MadLinksPlatform]?
    private var filter: Filter = .all
    private lazy var connector = MadLinksConnector(context: self.context, api: self.api, strings: self.strings, controller: self)
    private lazy var domainFlow = MadDomainFlow(context: self.context, api: self.api, strings: self.strings, controller: self, linked: { [weak self] in
        guard let self else {
            return
        }
        Task { @MainActor [weak self] in
            guard let self, let profile = try? await self.api.myAccounts() else {
                return
            }
            self.accounts = profile.accounts
            self.changed(profile)
            self.rebuildTiles()
        }
    })

    private let scrollView = UIScrollView()
    private let headlineLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let filtersView = UIScrollView()
    private var filterButtons: [UIButton] = []
    private var tiles: [MadPlatformTile] = []
    private let footerLabel = UILabel()
    private let activity = UIActivityIndicatorView(style: .medium)
    private var validLayout: ContainerViewLayout?

    init(context: AccountContext, accounts: [MadLinksAccount], openAccount: @escaping (String) -> Void, changed: @escaping (MadLinksProfile) -> Void) {
        self.context = context
        self.api = MadLinksAPI(context: context)
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.strings = self.presentationData.strings.localFeatures.more.accounts
        self.accounts = accounts
        self.openAccount = openAccount
        self.changed = changed
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = self.strings.addTitle
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.loadPlatforms()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        self.displayNode = MadAddAccountNode()
        self.displayNodeDidLoad()
        let theme = self.presentationData.theme
        let view = self.displayNode.view
        view.backgroundColor = theme.list.blocksBackgroundColor
        self.scrollView.contentInsetAdjustmentBehavior = .never
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.indicatorStyle = theme.overallDarkAppearance ? .white : .black
        view.addSubview(self.scrollView)

        self.headlineLabel.font = UIFont.systemFont(ofSize: 30.0, weight: .bold)
        self.headlineLabel.textColor = theme.list.itemPrimaryTextColor
        self.headlineLabel.text = self.strings.addHeadline
        self.scrollView.addSubview(self.headlineLabel)

        self.subtitleLabel.font = UIFont.systemFont(ofSize: 15.0)
        self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.subtitleLabel.numberOfLines = 0
        self.subtitleLabel.text = self.strings.addSubtitle
        self.scrollView.addSubview(self.subtitleLabel)

        self.filtersView.showsHorizontalScrollIndicator = false
        self.filtersView.alwaysBounceHorizontal = true
        self.scrollView.addSubview(self.filtersView)
        let titles = [self.strings.filterAll, self.strings.filterSocial, self.strings.filterGames, self.strings.filterMusic, self.strings.filterWork]
        for (index, title) in titles.enumerated() {
            let button = UIButton(type: .custom)
            button.tag = index
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
            button.layer.cornerRadius = 17.0
            button.layer.cornerCurve = .continuous
            button.addTarget(self, action: #selector(self.filterPressed(_:)), for: .touchUpInside)
            self.filtersView.addSubview(button)
            self.filterButtons.append(button)
        }

        self.footerLabel.font = UIFont.systemFont(ofSize: 13.0)
        self.footerLabel.textColor = theme.list.freeTextColor
        self.footerLabel.numberOfLines = 0
        self.footerLabel.text = self.strings.addFooter
        self.scrollView.addSubview(self.footerLabel)

        self.activity.color = theme.list.itemSecondaryTextColor
        self.scrollView.addSubview(self.activity)

        self.updateFilterButtons()
        self.rebuildTiles()
    }

    private func loadPlatforms() {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                self.platforms = try await self.api.platforms()
            } catch {
                self.platforms = MadLinksPlatformInfo.fallbackCatalog
                MadLinksUI.toast(self, context: self.context, text: MadLinksUI.errorText(error, strings: self.strings))
            }
            self.rebuildTiles()
        }
    }

    @objc private func filterPressed(_ sender: UIButton) {
        guard let filter = Filter(rawValue: sender.tag), filter != self.filter else {
            return
        }
        self.filter = filter
        self.updateFilterButtons()
        self.rebuildTiles()
    }

    private func updateFilterButtons() {
        let theme = self.presentationData.theme
        for button in self.filterButtons {
            let selected = button.tag == self.filter.rawValue
            button.backgroundColor = selected ? theme.list.itemAccentColor.withAlphaComponent(0.18) : theme.list.itemBlocksBackgroundColor
            button.setTitleColor(selected ? theme.list.itemAccentColor : theme.list.itemSecondaryTextColor, for: .normal)
        }
    }

    private func visiblePlatforms() -> [MadLinksPlatform] {
        guard let platforms = self.platforms else {
            return []
        }
        guard let category = self.filter.category else {
            return platforms
        }
        return platforms.filter { $0.category == category }
    }

    private func rebuildTiles() {
        guard self.isNodeLoaded else {
            return
        }
        for tile in self.tiles {
            tile.removeFromSuperview()
        }
        self.tiles.removeAll()
        let theme = self.presentationData.theme
        for platform in self.visiblePlatforms() {
            let tile = MadPlatformTile(frame: .zero)
            tile.platformId = platform.id
            tile.backgroundColor = theme.list.itemBlocksBackgroundColor
            tile.iconView.image = MadLinksUI.icon(platform.id)
            tile.nameLabel.text = platform.id == "domain" ? MadLinksPlatformInfo.name(platform.id) : platform.name
            tile.nameLabel.textColor = theme.list.itemPrimaryTextColor
            tile.statusLabel.textColor = theme.list.itemSecondaryTextColor
            if self.accounts.contains(where: { $0.platform == platform.id }) {
                tile.statusLabel.text = self.strings.statusAdded
                tile.statusLabel.textColor = theme.list.itemAccentColor
            } else if platform.id == "domain" {
                tile.statusLabel.text = "DNS"
            } else if platform.available {
                tile.statusLabel.text = self.strings.statusLogin
            } else {
                tile.statusLabel.text = self.strings.statusSoon
                tile.iconView.alpha = 0.4
                tile.nameLabel.alpha = 0.5
                tile.statusLabel.alpha = 0.5
            }
            tile.accessibilityLabel = platform.name
            tile.accessibilityValue = tile.statusLabel.text
            tile.isAccessibilityElement = true
            tile.accessibilityTraits = .button
            tile.addTarget(self, action: #selector(self.tilePressed(_:)), for: .touchUpInside)
            self.scrollView.addSubview(tile)
            self.tiles.append(tile)
        }
        if self.platforms == nil {
            self.activity.startAnimating()
        } else {
            self.activity.stopAnimating()
        }
        if let layout = self.validLayout {
            self.layoutContent(layout)
        }
    }

    @objc private func tilePressed(_ sender: MadPlatformTile) {
        guard let platform = self.platforms?.first(where: { $0.id == sender.platformId }) else {
            return
        }
        if platform.id == "domain" {
            self.domainFlow.askDomain()
            return
        }
        if let account = self.accounts.first(where: { $0.platform == platform.id }) {
            self.openAccount(account.id)
            return
        }
        guard platform.available else {
            MadLinksUI.toast(self, context: self.context, text: self.strings.unavailable)
            return
        }
        self.connector.start(platform, linked: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                if let profile = try? await self.api.myAccounts() {
                    self.accounts = profile.accounts
                    self.changed(profile)
                    self.rebuildTiles()
                }
                MadLinksUI.toast(self, context: self.context, text: self.strings.linked(platform.name))
            }
        })
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.validLayout = layout
        self.layoutContent(layout)
    }

    private func layoutContent(_ layout: ContainerViewLayout) {
        guard self.isNodeLoaded else {
            return
        }
        let navigationHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        self.scrollView.frame = CGRect(origin: .zero, size: layout.size)
        self.scrollView.contentInset = UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0)
        self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset

        let sideInset = 16.0 + max(layout.safeInsets.left, layout.safeInsets.right)
        let width = layout.size.width - sideInset * 2.0
        var y: CGFloat = 16.0

        let headlineSize = self.headlineLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        self.headlineLabel.frame = CGRect(x: sideInset, y: y, width: width, height: headlineSize.height)
        y += headlineSize.height + 6.0
        let subtitleSize = self.subtitleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        self.subtitleLabel.frame = CGRect(x: sideInset, y: y, width: width, height: subtitleSize.height)
        y += subtitleSize.height + 22.0

        var filterX: CGFloat = sideInset
        for button in self.filterButtons {
            let size = button.titleLabel?.sizeThatFits(CGSize(width: 200.0, height: 34.0)) ?? CGSize()
            let buttonWidth = ceil(size.width) + 24.0
            button.frame = CGRect(x: filterX, y: 0.0, width: buttonWidth, height: 34.0)
            filterX += buttonWidth + 6.0
        }
        self.filtersView.frame = CGRect(x: 0.0, y: y, width: layout.size.width, height: 34.0)
        self.filtersView.contentSize = CGSize(width: filterX - 6.0 + sideInset, height: 34.0)
        y += 34.0 + 20.0

        let columns: CGFloat = width > 600.0 ? 5.0 : 3.0
        let spacing: CGFloat = 10.0
        let tileWidth = floor((width - spacing * (columns - 1.0)) / columns)
        let tileHeight: CGFloat = 104.0
        for (index, tile) in self.tiles.enumerated() {
            let column = CGFloat(index % Int(columns))
            let row = CGFloat(index / Int(columns))
            tile.frame = CGRect(x: sideInset + column * (tileWidth + spacing), y: y + row * (tileHeight + spacing), width: tileWidth, height: tileHeight)
        }
        if self.tiles.isEmpty {
            self.activity.center = CGPoint(x: layout.size.width / 2.0, y: y + 40.0)
            y += 80.0
        } else {
            let rows = ceil(CGFloat(self.tiles.count) / columns)
            y += rows * tileHeight + max(0.0, rows - 1.0) * spacing
        }
        y += 18.0
        let footerSize = self.footerLabel.sizeThatFits(CGSize(width: width - 16.0, height: .greatestFiniteMagnitude))
        self.footerLabel.frame = CGRect(x: sideInset + 8.0, y: y, width: width - 16.0, height: footerSize.height)
        y += footerSize.height + 24.0
        self.scrollView.contentSize = CGSize(width: layout.size.width, height: y)
    }
}
