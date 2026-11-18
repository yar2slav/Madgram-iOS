import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import MadProfileLinks
import MadProfileLinksCore

final class PeerInfoScreenMadAccountsRowItem: PeerInfoScreenItem {
    let id: AnyHashable
    let accounts: [MadLinksAccount]
    let action: (MadLinksAccount) -> Void

    init(id: AnyHashable, accounts: [MadLinksAccount], action: @escaping (MadLinksAccount) -> Void) {
        self.id = id
        self.accounts = accounts
        self.action = action
    }

    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenMadAccountsRowItemNode()
    }
}

private final class MadAccountChipView: UIControl {
    let iconView = UIImageView()
    let label = UILabel()
    let verifiedView = UIImageView()
    private var iconAccountId: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.iconView.contentMode = .scaleAspectFit
        self.iconView.isUserInteractionEnabled = false
        self.label.isUserInteractionEnabled = false
        self.verifiedView.isUserInteractionEnabled = false
        self.label.font = UIFont.systemFont(ofSize: 15.0, weight: .medium)
        self.addSubview(self.iconView)
        self.addSubview(self.label)
        self.addSubview(self.verifiedView)
        self.isAccessibilityElement = true
        self.accessibilityTraits = .link
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            self.alpha = self.isHighlighted ? 0.55 : 1.0
        }
    }

    func update(account: MadLinksAccount, color: UIColor, verifiedColor: UIColor, height: CGFloat) -> CGFloat {
        self.iconAccountId = account.id
        MadLinksUI.setIcon(for: account, apply: { [weak self] image in
            if self?.iconAccountId == account.id {
                self?.iconView.image = image
            }
        })
        self.label.text = account.title
        self.label.textColor = color
        self.accessibilityLabel = MadLinksPlatformInfo.name(account.platform) + ", " + account.title
        let labelSize = self.label.sizeThatFits(CGSize(width: 180.0, height: 22.0))
        let labelWidth = min(180.0, ceil(labelSize.width))
        let top = floor((height - 26.0) / 2.0)
        self.iconView.frame = CGRect(x: 0.0, y: top, width: 26.0, height: 26.0)
        self.label.frame = CGRect(x: 34.0, y: top, width: labelWidth, height: 26.0)
        var width = 34.0 + labelWidth
        if account.verified, let image = MadLinksUI.verifiedImage(color: verifiedColor, size: 12.0) {
            self.verifiedView.isHidden = false
            self.verifiedView.image = image
            self.verifiedView.frame = CGRect(x: width + 4.0, y: floor((height - image.size.height) / 2.0), width: image.size.width, height: image.size.height)
            width += 4.0 + image.size.width
        } else {
            self.verifiedView.isHidden = true
        }
        return width
    }
}

private final class PeerInfoScreenMadAccountsRowItemNode: PeerInfoScreenItemNode, UIScrollViewDelegate {
    private let maskNode: ASImageNode
    private var scrollView: UIScrollView?
    private var chips: [MadAccountChipView] = []
    private var separators: [UIView] = []
    private let leftButton: HighlightableButtonNode
    private let rightButton: HighlightableButtonNode
    private var item: PeerInfoScreenMadAccountsRowItem?
    private var theme: PresentationTheme?

    override init() {
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        self.leftButton = HighlightableButtonNode()
        self.rightButton = HighlightableButtonNode()

        super.init()

        self.addSubnode(self.leftButton)
        self.addSubnode(self.rightButton)
        self.addSubnode(self.maskNode)
        self.leftButton.addTarget(self, action: #selector(self.leftPressed), forControlEvents: .touchUpInside)
        self.rightButton.addTarget(self, action: #selector(self.rightPressed), forControlEvents: .touchUpInside)
    }

    @objc private func leftPressed() {
        self.scrollByPage(-1.0)
    }

    @objc private func rightPressed() {
        self.scrollByPage(1.0)
    }

    private func scrollByPage(_ direction: CGFloat) {
        guard let scrollView = self.scrollView else {
            return
        }
        let maxOffset = max(0.0, scrollView.contentSize.width - scrollView.bounds.width)
        let target = min(maxOffset, max(0.0, scrollView.contentOffset.x + direction * scrollView.bounds.width * 0.8))
        scrollView.setContentOffset(CGPoint(x: target, y: 0.0), animated: true)
    }

    @objc private func chipPressed(_ sender: MadAccountChipView) {
        guard let item = self.item, let index = self.chips.firstIndex(of: sender), index < item.accounts.count else {
            return
        }
        item.action(item.accounts[index])
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateArrows()
    }

    private func updateArrows() {
        guard let scrollView = self.scrollView, let theme = self.theme else {
            return
        }
        let maxOffset = max(0.0, scrollView.contentSize.width - scrollView.bounds.width)
        let scrollable = maxOffset > 1.0
        self.leftButton.isHidden = !scrollable
        self.rightButton.isHidden = !scrollable
        let canLeft = scrollView.contentOffset.x > 1.0
        let canRight = scrollView.contentOffset.x < maxOffset - 1.0
        self.leftButton.setImage(self.arrowImage("chevron.left", color: canLeft ? theme.list.itemAccentColor : theme.list.itemDisabledTextColor), for: .normal)
        self.rightButton.setImage(self.arrowImage("chevron.right", color: canRight ? theme.list.itemAccentColor : theme.list.itemDisabledTextColor), for: .normal)
        self.leftButton.isUserInteractionEnabled = canLeft
        self.rightButton.isUserInteractionEnabled = canRight
    }

    private func arrowImage(_ name: String, color: UIColor) -> UIImage? {
        return MadLinksUI.rasterizedSymbol(name, pointSize: 14.0, weight: .semibold, color: color)
    }

    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenMadAccountsRowItem else {
            return 10.0
        }
        self.item = item
        self.theme = presentationData.theme
        let height: CGFloat = 58.0

        let scrollView: UIScrollView
        if let current = self.scrollView {
            scrollView = current
        } else {
            scrollView = UIScrollView()
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.alwaysBounceHorizontal = true
            scrollView.scrollsToTop = false
            scrollView.delegate = self
            self.view.insertSubview(scrollView, at: 0)
            self.scrollView = scrollView
        }

        while self.chips.count < item.accounts.count {
            let chip = MadAccountChipView(frame: .zero)
            chip.addTarget(self, action: #selector(self.chipPressed(_:)), for: .touchUpInside)
            scrollView.addSubview(chip)
            self.chips.append(chip)
        }
        while self.chips.count > item.accounts.count {
            self.chips.removeLast().removeFromSuperview()
        }
        let separatorCount = max(0, item.accounts.count - 1)
        while self.separators.count < separatorCount {
            let separator = UIView()
            scrollView.addSubview(separator)
            self.separators.append(separator)
        }
        while self.separators.count > separatorCount {
            self.separators.removeLast().removeFromSuperview()
        }

        let arrowWidth: CGFloat = 32.0
        let scrollFrame = CGRect(x: safeInsets.left + arrowWidth, y: 0.0, width: max(1.0, width - safeInsets.left - safeInsets.right - arrowWidth * 2.0), height: height)
        var x: CGFloat = 4.0
        for (index, account) in item.accounts.enumerated() {
            let chip = self.chips[index]
            let chipWidth = chip.update(account: account, color: presentationData.theme.list.itemPrimaryTextColor, verifiedColor: presentationData.theme.list.itemCheckColors.fillColor, height: height)
            chip.frame = CGRect(x: x, y: 0.0, width: chipWidth, height: height)
            x += chipWidth
            if index < separatorCount {
                let separator = self.separators[index]
                separator.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
                separator.frame = CGRect(x: x + 12.0, y: floor((height - 20.0) / 2.0), width: UIScreenPixel * 2.0, height: 20.0)
                x += 24.0
            }
        }
        x += 4.0
        if x < scrollFrame.width {
            scrollView.frame = CGRect(x: safeInsets.left + 16.0, y: 0.0, width: width - safeInsets.left - safeInsets.right - 32.0, height: height)
        } else {
            scrollView.frame = scrollFrame
        }
        scrollView.contentSize = CGSize(width: x, height: height)
        if scrollView.contentOffset.x > max(0.0, x - scrollView.bounds.width) {
            scrollView.contentOffset = CGPoint(x: max(0.0, x - scrollView.bounds.width), y: 0.0)
        }

        self.leftButton.frame = CGRect(x: safeInsets.left, y: 0.0, width: arrowWidth, height: height)
        self.rightButton.frame = CGRect(x: width - safeInsets.right - arrowWidth, y: 0.0, width: arrowWidth, height: height)
        self.updateArrows()

        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners, glass: true) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))

        return height
    }
}

final class PeerInfoScreenMadAccountItem: PeerInfoScreenItem {
    enum Content {
        case account(MadLinksAccount)
        case more(String)
    }

    let id: AnyHashable
    let content: Content
    let action: () -> Void

    init(id: AnyHashable, content: Content, action: @escaping () -> Void) {
        self.id = id
        self.content = content
        self.action = action
    }

    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenMadAccountItemNode()
    }
}

private final class PeerInfoScreenMadAccountItemNode: PeerInfoScreenItemNode {
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let maskNode: ASImageNode
    private let iconNode: ASImageNode
    private var iconAccountId: String?
    private let titleNode: ImmediateTextNode
    private let verifiedNode: ASImageNode
    private let subtitleNode: ImmediateTextNode
    private let arrowNode: ASImageNode
    private let bottomSeparatorNode: ASDisplayNode
    private let activateArea: AccessibilityAreaNode

    private var item: PeerInfoScreenMadAccountItem?

    override init() {
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: {
            bringToFrontForHighlightImpl?()
        })

        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false

        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.isUserInteractionEnabled = false

        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.maximumNumberOfLines = 1

        self.verifiedNode = ASImageNode()
        self.verifiedNode.displaysAsynchronously = false
        self.verifiedNode.isUserInteractionEnabled = false

        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.maximumNumberOfLines = 1

        self.arrowNode = ASImageNode()
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.isUserInteractionEnabled = false

        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true

        self.activateArea = AccessibilityAreaNode()

        super.init()

        bringToFrontForHighlightImpl = { [weak self] in
            self?.bringToFrontForHighlight?()
        }

        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.selectionNode)
        self.addSubnode(self.maskNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.verifiedNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.activateArea)
    }

    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenMadAccountItem else {
            return 10.0
        }

        self.item = item
        self.selectionNode.pressed = item.action

        let theme = presentationData.theme
        let sideInset: CGFloat = 16.0 + safeInsets.left
        let iconSize: CGFloat = 30.0
        let height: CGFloat
        let textLeftInset: CGFloat

        switch item.content {
        case let .account(account):
            height = 58.0
            textLeftInset = sideInset + iconSize + 12.0
            self.iconNode.isHidden = false
            self.iconAccountId = account.id
            MadLinksUI.setIcon(for: account, apply: { [weak self] image in
                if self?.iconAccountId == account.id {
                    self?.iconNode.image = image
                }
            })
            self.titleNode.attributedText = NSAttributedString(string: MadLinksPlatformInfo.name(account.platform), font: Font.medium(presentationData.listsFontSize.itemListBaseFontSize), textColor: theme.list.itemPrimaryTextColor)
            self.subtitleNode.attributedText = NSAttributedString(string: account.title, font: Font.regular(13.0), textColor: theme.list.itemSecondaryTextColor)
            self.subtitleNode.isHidden = false
            self.verifiedNode.isHidden = !account.verified
            self.verifiedNode.image = MadLinksUI.verifiedImage(color: theme.list.itemCheckColors.fillColor, size: 14.0)
            self.arrowNode.image = account.url == nil ? nil : MadLinksUI.externalArrowImage(color: theme.list.itemSecondaryTextColor)
            self.activateArea.accessibilityLabel = MadLinksPlatformInfo.name(account.platform)
            self.activateArea.accessibilityValue = account.title
        case let .more(text):
            height = 44.0
            textLeftInset = sideInset
            self.iconNode.isHidden = true
            self.verifiedNode.isHidden = true
            self.subtitleNode.isHidden = true
            self.titleNode.attributedText = NSAttributedString(string: text, font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize), textColor: theme.list.itemAccentColor)
            self.arrowNode.image = PresentationResourcesItemList.disclosureArrowImage(theme)
            self.activateArea.accessibilityLabel = text
            self.activateArea.accessibilityValue = nil
        }

        let arrowSize = self.arrowNode.image?.size ?? CGSize()
        let rightInset: CGFloat = 16.0 + safeInsets.right + arrowSize.width + 12.0
        let verifiedWidth: CGFloat = self.verifiedNode.isHidden ? 0.0 : 24.0
        let textConstrainedWidth = max(1.0, width - textLeftInset - rightInset)
        let titleSize = self.titleNode.updateLayout(CGSize(width: max(1.0, textConstrainedWidth - verifiedWidth), height: .greatestFiniteMagnitude))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: textConstrainedWidth, height: .greatestFiniteMagnitude))

        transition.updateFrame(node: self.iconNode, frame: CGRect(x: sideInset, y: floorToScreenPixels((height - iconSize) / 2.0), width: iconSize, height: iconSize))

        let textHeight = self.subtitleNode.isHidden ? titleSize.height : titleSize.height + subtitleSize.height + 1.0
        let textTop = floorToScreenPixels((height - textHeight) / 2.0)
        let titleFrame = CGRect(origin: CGPoint(x: textLeftInset, y: textTop), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        if let verifiedImage = self.verifiedNode.image, !self.verifiedNode.isHidden {
            transition.updateFrame(node: self.verifiedNode, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 5.0, y: titleFrame.midY - verifiedImage.size.height / 2.0), size: verifiedImage.size))
        }
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: textLeftInset, y: textTop + titleSize.height + 1.0), size: subtitleSize))

        if self.arrowNode.image != nil {
            let arrowX: CGFloat
            if case .more = item.content {
                arrowX = width - 7.0 - arrowSize.width - safeInsets.right
            } else {
                arrowX = width - 18.0 - arrowSize.width - safeInsets.right
            }
            transition.updateFrame(node: self.arrowNode, frame: CGRect(origin: CGPoint(x: arrowX, y: floorToScreenPixels((height - arrowSize.height) / 2.0)), size: arrowSize))
        }

        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil

        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(theme, top: hasTopCorners, bottom: hasBottomCorners, glass: true) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        self.bottomSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor

        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))

        let separatorX: CGFloat = sideInset + iconSize + 12.0
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: separatorX, y: height - UIScreenPixel), size: CGSize(width: width - separatorX - PeerInfoClassicMetrics.separatorRightInset - safeInsets.right, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)

        self.activateArea.applyPeerInfoRowAction(item.action)
        self.activateArea.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))

        return height
    }
}
