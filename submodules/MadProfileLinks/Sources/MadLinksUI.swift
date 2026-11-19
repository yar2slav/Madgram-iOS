import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AppBundle
import AccountContext
import TelegramPresentationData
import UndoUI
import MadProfileLinksCore

public enum MadLinksUI {
    private static var fallbackIcons: [String: UIImage] = [:]

    public static func icon(_ platform: String) -> UIImage? {
        if let name = MadLinksPlatformInfo.iconName(platform), let image = UIImage(bundleImageName: name) {
            return image
        }
        if let cached = self.fallbackIcons[platform] {
            return cached
        }
        if platform == "domain" {
            let size = CGSize(width: 60.0, height: 60.0)
            let image = UIGraphicsImageRenderer(size: size).image { _ in
                let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 14.0)
                UIColor(red: 0.2, green: 0.47, blue: 0.96, alpha: 1.0).setFill()
                path.fill()
                if let globe = UIImage(systemName: "globe", withConfiguration: UIImage.SymbolConfiguration(pointSize: 30.0, weight: .medium))?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                    globe.draw(at: CGPoint(x: (size.width - globe.size.width) / 2.0, y: (size.height - globe.size.height) / 2.0))
                }
            }
            self.fallbackIcons[platform] = image
            return image
        }
        let size = CGSize(width: 60.0, height: 60.0)
        let letter = String(MadLinksPlatformInfo.name(platform).prefix(1)).uppercased()
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 14.0)
            UIColor(white: 0.32, alpha: 1.0).setFill()
            path.fill()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28.0, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let textSize = (letter as NSString).size(withAttributes: attributes)
            (letter as NSString).draw(at: CGPoint(x: (size.width - textSize.width) / 2.0, y: (size.height - textSize.height) / 2.0), withAttributes: attributes)
        }
        self.fallbackIcons[platform] = image
        return image
    }

    public static func verifiedImage(color: UIColor, size: CGFloat) -> UIImage? {
        guard let background = UIImage(bundleImageName: "Chat List/PeerVerifiedIconBackground")?.cgImage, let foreground = UIImage(bundleImageName: "Chat List/PeerVerifiedIconForeground")?.cgImage else {
            return nil
        }
        let side = size + 4.0
        return generateImage(CGSize(width: side, height: side), contextGenerator: { size, context in
            let rect = CGRect(origin: .zero, size: size)
            context.clear(rect)
            context.saveGState()
            context.clip(to: rect, mask: background)
            context.setFillColor(color.cgColor)
            context.fill(rect)
            context.restoreGState()
            context.clip(to: rect, mask: foreground)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(rect)
        })
    }

    public static func externalArrowImage(color: UIColor) -> UIImage? {
        return self.rasterizedSymbol("arrow.up.right", pointSize: 12.0, weight: .medium, color: color)
    }

    public static func rasterizedSymbol(_ name: String, pointSize: CGFloat, weight: UIImage.SymbolWeight, color: UIColor) -> UIImage? {
        guard let symbol = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight))?.withTintColor(color, renderingMode: .alwaysOriginal) else {
            return nil
        }
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        return UIGraphicsImageRenderer(size: symbol.size, format: format).image { _ in
            symbol.draw(at: .zero)
        }
    }

    public static func openUrl(context: AccountContext, url: String, navigationController: NavigationController?) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
    }

    static func errorText(_ error: Error, strings: MadAccountsStrings) -> String {
        if let error = error as? MadLinksError, error == .botUnavailable {
            return strings.serviceUnavailable
        }
        return strings.loadFailed
    }

    static func toast(_ controller: ViewController, context: AccountContext, text: String) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
    }
}

enum MadLinksRowAccessory {
    case none
    case chevron
    case external
    case check
}

enum MadLinksRow {
    case account(MadLinksAccount, subtitle: String, accessory: MadLinksRowAccessory, action: (() -> Void)?)
    case action(title: String, destructive: Bool, centered: Bool, accessory: MadLinksRowAccessory, action: () -> Void)
    case toggle(title: String, value: Bool, enabled: Bool, update: (Bool) -> Void)
    case choice(title: String, value: String, checked: Bool, action: () -> Void)
    case design(MadLinksDesign, update: (MadLinksDesign) -> Void)
    case text(String)
    case loading

    var height: CGFloat {
        switch self {
        case .account:
            return 58.0
        case .design:
            return 52.0
        default:
            return 46.0
        }
    }
}

struct MadLinksTableSection {
    var header: String?
    var footer: String?
    var rows: [MadLinksRow]
}

private final class MadLinksControllerNode: ASDisplayNode {
    override init() {
        super.init()
        self.setViewBlock({
            return UIView()
        })
    }
}

final class MadLinksCell: UITableViewCell {
    let iconView = UIImageView()
    let titleLabel = UILabel()
    let verifiedView = UIImageView()
    let subtitleLabel = UILabel()
    let accessoryImageView = UIImageView()
    let switchView = UISwitch()
    let segmented = UISegmentedControl(items: ["", ""])
    let activity = UIActivityIndicatorView(style: .medium)
    var switchHandler: ((Bool) -> Void)?
    var designHandler: ((MadLinksDesign) -> Void)?
    private var kind = 0
    private var centered = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.iconView.contentMode = .scaleAspectFit
        self.titleLabel.lineBreakMode = .byTruncatingTail
        self.subtitleLabel.lineBreakMode = .byTruncatingTail
        self.subtitleLabel.font = UIFont.systemFont(ofSize: 13.0)
        self.verifiedView.contentMode = .center
        self.accessoryImageView.contentMode = .center
        self.switchView.addTarget(self, action: #selector(self.switchChanged), for: .valueChanged)
        self.segmented.addTarget(self, action: #selector(self.segmentChanged), for: .valueChanged)
        for view in [self.iconView, self.titleLabel, self.verifiedView, self.subtitleLabel, self.accessoryImageView, self.switchView, self.segmented, self.activity] as [UIView] {
            self.contentView.addSubview(view)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func switchChanged() {
        self.switchHandler?(self.switchView.isOn)
    }

    @objc private func segmentChanged() {
        self.designHandler?(self.segmented.selectedSegmentIndex == 1 ? .list : .row)
    }

    private var iconAccountId: String?

    func configure(row: MadLinksRow, theme: PresentationTheme, strings: MadAccountsStrings) {
        self.backgroundColor = theme.list.itemBlocksBackgroundColor
        let selected = UIView()
        selected.backgroundColor = theme.list.itemHighlightedBackgroundColor
        self.selectedBackgroundView = selected
        self.switchHandler = nil
        self.designHandler = nil
        for view in [self.iconView, self.verifiedView, self.subtitleLabel, self.accessoryImageView, self.switchView, self.segmented] as [UIView] {
            view.isHidden = true
        }
        self.titleLabel.isHidden = false
        self.activity.stopAnimating()
        self.centered = false
        self.selectionStyle = .default
        self.titleLabel.textAlignment = .natural
        self.subtitleLabel.textAlignment = .natural
        self.subtitleLabel.font = UIFont.systemFont(ofSize: 13.0)

        switch row {
        case let .account(account, subtitle, accessory, action):
            self.kind = 0
            self.iconView.isHidden = false
            self.iconAccountId = account.id
            MadLinksUI.setIcon(for: account, apply: { [weak self] image in
                if self?.iconAccountId == account.id {
                    self?.iconView.image = image
                }
            })
            self.titleLabel.font = UIFont.systemFont(ofSize: 17.0)
            self.titleLabel.textColor = theme.list.itemPrimaryTextColor
            self.titleLabel.text = MadLinksPlatformInfo.name(account.platform)
            self.verifiedView.isHidden = !account.verified
            self.verifiedView.image = MadLinksUI.verifiedImage(color: theme.list.itemCheckColors.fillColor, size: 14.0)
            self.subtitleLabel.isHidden = false
            self.subtitleLabel.text = subtitle
            self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
            self.applyAccessory(accessory, theme: theme)
            self.selectionStyle = action == nil ? .none : .default
        case let .action(title, destructive, centered, accessory, _):
            self.kind = 1
            self.centered = centered
            self.titleLabel.font = UIFont.systemFont(ofSize: 17.0)
            self.titleLabel.textColor = destructive ? theme.list.itemDestructiveColor : theme.list.itemAccentColor
            self.titleLabel.text = title
            self.titleLabel.textAlignment = centered ? .center : .natural
            self.applyAccessory(accessory, theme: theme)
        case let .choice(title, value, checked, _):
            self.kind = 5
            self.titleLabel.font = UIFont.systemFont(ofSize: 17.0)
            self.titleLabel.textColor = theme.list.itemPrimaryTextColor
            self.titleLabel.text = title
            self.subtitleLabel.isHidden = false
            self.subtitleLabel.text = value
            self.subtitleLabel.textAlignment = .right
            self.subtitleLabel.font = UIFont.systemFont(ofSize: 17.0)
            self.subtitleLabel.textColor = theme.list.itemSecondaryTextColor
            self.applyAccessory(checked ? .check : .none, theme: theme)
            if !checked {
                self.accessoryImageView.isHidden = false
                self.accessoryImageView.image = nil
            }
        case let .toggle(title, value, enabled, update):
            self.kind = 2
            self.selectionStyle = .none
            self.titleLabel.font = UIFont.systemFont(ofSize: 17.0)
            self.titleLabel.textColor = theme.list.itemPrimaryTextColor
            self.titleLabel.text = title
            self.switchView.isHidden = false
            self.switchView.onTintColor = theme.list.itemSwitchColors.positiveColor
            self.switchView.isOn = value
            self.switchView.isEnabled = enabled
            self.switchHandler = update
        case let .design(design, update):
            self.kind = 3
            self.selectionStyle = .none
            self.titleLabel.isHidden = true
            self.segmented.isHidden = false
            self.segmented.setTitle(strings.designRow, forSegmentAt: 0)
            self.segmented.setTitle(strings.designList, forSegmentAt: 1)
            self.segmented.selectedSegmentIndex = design == .list ? 1 : 0
            self.designHandler = update
        case let .text(text):
            self.kind = 1
            self.centered = true
            self.selectionStyle = .none
            self.titleLabel.font = UIFont.systemFont(ofSize: 15.0)
            self.titleLabel.textColor = theme.list.itemSecondaryTextColor
            self.titleLabel.text = text
            self.titleLabel.textAlignment = .center
        case .loading:
            self.kind = 4
            self.selectionStyle = .none
            self.titleLabel.isHidden = true
            self.activity.color = theme.list.itemSecondaryTextColor
            self.activity.startAnimating()
        }
        self.setNeedsLayout()
    }

    private func applyAccessory(_ accessory: MadLinksRowAccessory, theme: PresentationTheme) {
        switch accessory {
        case .none:
            self.accessoryImageView.isHidden = true
        case .chevron:
            self.accessoryImageView.isHidden = false
            self.accessoryImageView.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13.0, weight: .semibold))?.withTintColor(theme.list.disclosureArrowColor, renderingMode: .alwaysOriginal)
        case .external:
            self.accessoryImageView.isHidden = false
            self.accessoryImageView.image = MadLinksUI.externalArrowImage(color: theme.list.itemSecondaryTextColor)
        case .check:
            self.accessoryImageView.isHidden = false
            self.accessoryImageView.image = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15.0, weight: .semibold))?.withTintColor(theme.list.itemAccentColor, renderingMode: .alwaysOriginal)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = self.contentView.bounds
        let inset: CGFloat = 16.0
        var rightEdge = bounds.width - inset
        if !self.accessoryImageView.isHidden {
            self.accessoryImageView.frame = CGRect(x: bounds.width - inset - 16.0, y: 0.0, width: 16.0, height: bounds.height)
            rightEdge -= 24.0
        }
        switch self.kind {
        case 0:
            let iconSize: CGFloat = 30.0
            self.iconView.frame = CGRect(x: inset, y: floor((bounds.height - iconSize) / 2.0), width: iconSize, height: iconSize)
            let textX = inset + iconSize + 12.0
            let titleSize = self.titleLabel.sizeThatFits(CGSize(width: max(1.0, rightEdge - textX - 20.0), height: 30.0))
            let titleWidth = min(titleSize.width, max(1.0, rightEdge - textX - 20.0))
            let subtitleHeight: CGFloat = 16.0
            let top = floor((bounds.height - titleSize.height - subtitleHeight - 1.0) / 2.0)
            self.titleLabel.frame = CGRect(x: textX, y: top, width: titleWidth, height: titleSize.height)
            self.verifiedView.frame = CGRect(x: textX + titleWidth + 4.0, y: top, width: 16.0, height: titleSize.height)
            self.subtitleLabel.frame = CGRect(x: textX, y: top + titleSize.height + 1.0, width: max(1.0, rightEdge - textX), height: subtitleHeight)
        case 2:
            let switchSize = self.switchView.intrinsicContentSize
            self.switchView.frame = CGRect(x: bounds.width - inset - switchSize.width, y: floor((bounds.height - switchSize.height) / 2.0), width: switchSize.width, height: switchSize.height)
            self.titleLabel.frame = CGRect(x: inset, y: 0.0, width: max(1.0, self.switchView.frame.minX - inset - 8.0), height: bounds.height)
        case 3:
            self.segmented.frame = CGRect(x: inset, y: floor((bounds.height - 32.0) / 2.0), width: bounds.width - inset * 2.0, height: 32.0)
        case 4:
            self.activity.center = CGPoint(x: bounds.midX, y: bounds.midY)
        case 5:
            let titleSize = self.titleLabel.sizeThatFits(CGSize(width: max(1.0, rightEdge - inset), height: bounds.height))
            let titleWidth = min(titleSize.width, (rightEdge - inset) * 0.6)
            self.titleLabel.frame = CGRect(x: inset, y: 0.0, width: titleWidth, height: bounds.height)
            let valueX = inset + titleWidth + 8.0
            self.subtitleLabel.frame = CGRect(x: valueX, y: 0.0, width: max(1.0, rightEdge - valueX), height: bounds.height)
        default:
            if self.centered {
                self.titleLabel.frame = CGRect(x: inset, y: 0.0, width: bounds.width - inset * 2.0, height: bounds.height)
            } else {
                self.titleLabel.frame = CGRect(x: inset, y: 0.0, width: max(1.0, rightEdge - inset), height: bounds.height)
            }
        }
    }
}

class MadLinksTableController: ViewController, UITableViewDataSource, UITableViewDelegate {
    let context: AccountContext
    var presentationData: PresentationData
    let strings: MadAccountsStrings
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    var sections: [MadLinksTableSection] = []
    private var validLayout: ContainerViewLayout?

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.strings = self.presentationData.strings.localFeatures.more.accounts
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        self.displayNode = MadLinksControllerNode()
        self.displayNodeDidLoad()
        self.displayNode.view.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.tableView.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.tableView.separatorColor = self.presentationData.theme.list.itemBlocksSeparatorColor
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.register(MadLinksCell.self, forCellReuseIdentifier: "cell")
        self.tableView.sectionHeaderTopPadding = 0.0
        self.tableView.indicatorStyle = self.presentationData.theme.overallDarkAppearance ? .white : .black
        self.displayNode.view.addSubview(self.tableView)
        self.tableView.overrideUserInterfaceStyle = self.presentationData.theme.overallDarkAppearance ? .dark : .light
        self.reloadSections()
    }

    func buildSections() -> [MadLinksTableSection] {
        return []
    }

    func reloadSections() {
        self.sections = self.buildSections()
        if self.isNodeLoaded {
            self.tableView.reloadData()
        }
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.validLayout = layout
        let navigationHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        let frame = CGRect(x: layout.safeInsets.left, y: 0.0, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: layout.size.height)
        transition.updateFrame(view: self.tableView, frame: frame)
        if let header = self.tableView.tableHeaderView, abs(header.frame.width - frame.width) > 0.5 {
            header.frame = CGRect(x: 0.0, y: 0.0, width: frame.width, height: header.frame.height)
            self.tableView.tableHeaderView = header
        }
        let insets = UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0)
        if self.tableView.contentInset != insets {
            let wasAtTop = self.tableView.contentOffset.y <= -self.tableView.contentInset.top + 1.0
            self.tableView.contentInset = insets
            self.tableView.scrollIndicatorInsets = insets
            if wasAtTop {
                self.tableView.contentOffset = CGPoint(x: 0.0, y: -insets.top)
            }
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.sections[indexPath.section].rows[indexPath.row].height
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! MadLinksCell
        cell.configure(row: self.sections[indexPath.section].rows[indexPath.row], theme: self.presentationData.theme, strings: self.strings)
        cell.showsReorderControl = self.canMove(indexPath: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let text = self.sections[section].header else {
            return nil
        }
        return self.makeLabelView(text.uppercased(), font: UIFont.systemFont(ofSize: 13.0), top: 22.0, bottom: 7.0)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard let text = self.sections[section].footer else {
            return nil
        }
        return self.makeLabelView(text, font: UIFont.systemFont(ofSize: 13.0), top: 7.0, bottom: 4.0)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let text = self.sections[section].header else {
            return section == 0 ? 20.0 : 12.0
        }
        return self.labelHeight(text.uppercased(), font: UIFont.systemFont(ofSize: 13.0)) + 29.0
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard let text = self.sections[section].footer else {
            return 12.0
        }
        return self.labelHeight(text, font: UIFont.systemFont(ofSize: 13.0)) + 11.0
    }

    private func labelWidth() -> CGFloat {
        return max(100.0, self.tableView.bounds.width - 2.0 * (self.tableView.layoutMargins.left + 16.0))
    }

    private func labelHeight(_ text: String, font: UIFont) -> CGFloat {
        let rect = (text as NSString).boundingRect(with: CGSize(width: self.labelWidth(), height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], attributes: [.font: font], context: nil)
        return ceil(rect.height)
    }

    private func makeLabelView(_ text: String, font: UIFont, top: CGFloat, bottom: CGFloat) -> UIView {
        let view = UIView()
        let label = UILabel()
        label.numberOfLines = 0
        label.font = font
        label.textColor = self.presentationData.theme.list.freeTextColor
        label.text = text
        let width = self.labelWidth()
        let height = self.labelHeight(text, font: font)
        label.frame = CGRect(x: 16.0, y: top, width: width, height: height)
        view.addSubview(label)
        return view
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch self.sections[indexPath.section].rows[indexPath.row] {
        case let .account(_, _, _, action):
            action?()
        case let .action(_, _, _, _, action):
            action()
        case let .choice(_, _, _, action):
            action()
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch self.sections[indexPath.section].rows[indexPath.row] {
        case let .account(_, _, _, action):
            return action != nil
        case .action, .choice:
            return true
        default:
            return false
        }
    }

    func canMove(indexPath: IndexPath) -> Bool {
        return false
    }

    func move(from: IndexPath, to: IndexPath) {
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return self.canMove(indexPath: indexPath)
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if proposedDestinationIndexPath.section != sourceIndexPath.section {
            let count = self.sections[sourceIndexPath.section].rows.count
            return IndexPath(row: proposedDestinationIndexPath.section < sourceIndexPath.section ? 0 : count - 1, section: sourceIndexPath.section)
        }
        if !self.canMove(indexPath: proposedDestinationIndexPath) {
            return sourceIndexPath
        }
        return proposedDestinationIndexPath
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let row = self.sections[sourceIndexPath.section].rows.remove(at: sourceIndexPath.row)
        self.sections[destinationIndexPath.section].rows.insert(row, at: destinationIndexPath.row)
        self.move(from: sourceIndexPath, to: destinationIndexPath)
    }

    func toast(_ text: String) {
        MadLinksUI.toast(self, context: self.context, text: text)
    }

    func openUrl(_ url: String) {
        MadLinksUI.openUrl(context: self.context, url: url, navigationController: self.navigationController as? NavigationController)
    }
}
