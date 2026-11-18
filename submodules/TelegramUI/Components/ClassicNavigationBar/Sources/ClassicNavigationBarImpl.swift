import Foundation
import UIKit
import AsyncDisplayKit
import Display

/// Madgram: the flat navigation bar of Telegram before Liquid Glass, used for every screen while
/// `ClassicDesign.isEnabled` (`defaultNavigationBarImpl` in the app delegate).
///
/// It is `NavigationBarImpl`'s `.legacy` style as it stood before upstream replaced it with `NavigationBarNode`
/// (16b065d8d0): a blurred background with a hairline separator, a back arrow with the previous screen's title (or the
/// unread badge), text buttons in the accent colour, and a centred title, 44pt tall below the status bar. It takes no
/// part in the glass bar morph (`takeView()` returns nil), so a push or pop slides it with its screen, as the flat bar
/// always did, and it has no iPhone Duo side column: its buttons stay in the row.
public final class ClassicNavigationBarImpl: ASDisplayNode, NavigationBar {
    public static var defaultSecondaryContentHeight: CGFloat {
        return 38.0
    }

    public static let titleFont = Font.with(size: 17.0, design: .regular, weight: .semibold, traits: [.monospacedNumbers])

    /// The flat bar's row: 44pt, where the glass bar centres its 44pt capsules in a 60pt band.
    private static let nominalHeight: CGFloat = 44.0

    /// The bar's row height for the height `ViewController` lays a glass bar out with (60, or 68 for a glass modal,
    /// whose extra 8pt `ViewController` adds above the row too).
    private static func rowHeight(defaultHeight: CGFloat) -> CGFloat {
        if defaultHeight >= 60.0 {
            return defaultHeight - 16.0
        }
        return min(defaultHeight, ClassicNavigationBarImpl.nominalHeight)
    }

    private var presentationData: NavigationBarPresentationData
    private var colors: ClassicNavigationBarColors

    private var validLayout: (size: CGSize, defaultHeight: CGFloat, additionalTopHeight: CGFloat, additionalContentHeight: CGFloat, additionalBackgroundHeight: CGFloat, leftInset: CGFloat, rightInset: CGFloat, appearsHidden: Bool)?
    private var requestedLayout: Bool = false
    public var requestContainerLayout: ((ContainedViewLayoutTransition) -> Void)?

    public var backPressed: () -> () = { }

    public var userInfo: Any?

    /// iPhone Duo: see `NavigationBar.trailingButtonsInset`.
    public var trailingButtonsInset: CGFloat = 0.0
    /// iPhone Duo: the classic bar keeps every button in its row and lays out no side column.
    public var sideColumnPlacement: NavigationBarSideColumnPlacement?
    public var sideColumnExtentUpdated: ((ContainedViewLayoutTransition) -> Void)?
    public var transitionContentFrameUpdated: ((CGRect) -> Void)?

    public var backButtonContextAction: ((UIView, ContextGesture) -> Void)? {
        didSet {
            self.backButtonNodeImpl.isGestureEnabled = self.backButtonContextAction != nil
        }
    }

    private let stripeNode: ASDisplayNode
    private let clippingNode: SparseNode
    private let buttonsContainerNode: ASDisplayNode

    public private(set) var contentNode: NavigationBarContentNode?
    public private(set) var secondaryContentNode: ASDisplayNode?

    private var itemTitleListenerKey: Int?
    private var itemTitleViewListenerKey: Int?
    private var itemLeftButtonListenerKey: Int?
    private var itemRightButtonListenerKey: Int?
    private var itemRightButtonsListenerKey: Int?
    private var itemBadgeListenerKey: Int?

    private var _item: UINavigationItem?
    public var item: UINavigationItem? {
        get {
            return self._item
        } set(value) {
            if let previousValue = self._item {
                if let itemTitleListenerKey = self.itemTitleListenerKey {
                    previousValue.removeSetTitleListener(itemTitleListenerKey)
                    self.itemTitleListenerKey = nil
                }
                if let itemTitleViewListenerKey = self.itemTitleViewListenerKey {
                    previousValue.removeSetTitleViewListener(itemTitleViewListenerKey)
                    self.itemTitleViewListenerKey = nil
                }
                if let itemLeftButtonListenerKey = self.itemLeftButtonListenerKey {
                    previousValue.removeSetLeftBarButtonItemListener(itemLeftButtonListenerKey)
                    self.itemLeftButtonListenerKey = nil
                }
                if let itemRightButtonListenerKey = self.itemRightButtonListenerKey {
                    previousValue.removeSetRightBarButtonItemListener(itemRightButtonListenerKey)
                    self.itemRightButtonListenerKey = nil
                }
                if let itemRightButtonsListenerKey = self.itemRightButtonsListenerKey {
                    previousValue.removeSetMultipleRightBarButtonItemsListener(itemRightButtonsListenerKey)
                    self.itemRightButtonsListenerKey = nil
                }
                if let itemBadgeListenerKey = self.itemBadgeListenerKey {
                    previousValue.removeSetBadgeListener(itemBadgeListenerKey)
                    self.itemBadgeListenerKey = nil
                }
            }
            self._item = value

            self.leftButtonNodeImpl.view.removeFromSuperview()
            self.rightButtonNodeImpl.view.removeFromSuperview()

            if let item = value {
                self.title = item.title
                self.itemTitleListenerKey = item.addSetTitleListener { [weak self] text, animated in
                    guard let self else {
                        return
                    }
                    let animateIn = animated && (self.title?.isEmpty ?? true)
                    self.title = text
                    if animateIn {
                        self.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                }

                self.setTitleView(item.titleView)
                self.itemTitleViewListenerKey = item.addSetTitleViewListener { [weak self] itemTitleView in
                    self?.setTitleView(itemTitleView)
                }

                self.itemLeftButtonListenerKey = item.addSetLeftBarButtonItemListener { [weak self] _, _, animated in
                    guard let self else {
                        return
                    }
                    self.updateLeftButton(animated: animated)
                    self.invalidateCalculatedLayout()
                    self.requestLayout()
                }

                self.itemRightButtonListenerKey = item.addSetRightBarButtonItemListener { [weak self] _, _, animated in
                    guard let self else {
                        return
                    }
                    self.updateRightButton(animated: animated)
                    self.invalidateCalculatedLayout()
                    self.requestLayout()
                }

                self.itemRightButtonsListenerKey = item.addSetMultipleRightBarButtonItemsListener { [weak self] _, animated in
                    guard let self else {
                        return
                    }
                    self.updateRightButton(animated: animated)
                    self.invalidateCalculatedLayout()
                    self.requestLayout()
                }

                self.itemBadgeListenerKey = item.addSetBadgeListener { [weak self] text in
                    self?.updateBadgeText(text: text)
                }
                self.updateBadgeText(text: item.badge)

                self.updateLeftButton(animated: false)
                self.updateRightButton(animated: false)
            } else {
                self.title = nil
                self.setTitleView(nil)
                self.updateBadgeText(text: nil)
                self.updateLeftButton(animated: false)
                self.updateRightButton(animated: false)
            }
            self.invalidateCalculatedLayout()
            self.requestLayout()
        }
    }

    private var title: String? {
        didSet {
            if let title = self.title {
                self.titleNode.attributedText = NSAttributedString(string: title, font: ClassicNavigationBarImpl.titleFont, textColor: self.colors.primaryTextColor)
                self.titleNode.accessibilityLabel = title
                if self.titleNode.supernode == nil {
                    self.buttonsContainerNode.addSubnode(self.titleNode)
                }
            } else {
                self.titleNode.removeFromSupernode()
            }

            self.invalidateCalculatedLayout()
            self.requestLayout()
        }
    }

    public private(set) var titleView: UIView?

    private func setTitleView(_ titleView: UIView?) {
        if self.titleView === titleView {
            return
        }
        if let previous = self.titleView {
            if let previous = previous as? NavigationBarTitleView {
                previous.requestUpdate = nil
            }
            if previous.superview === self.buttonsContainerNode.view {
                previous.removeFromSuperview()
            }
        }
        self.titleView = titleView
        if let titleView {
            self.buttonsContainerNode.view.insertSubview(titleView, at: 0)
            if let titleView = titleView as? NavigationBarTitleView {
                titleView.requestUpdate = { [weak self, weak titleView] transition in
                    guard let self, let titleView, self.titleView === titleView else {
                        return
                    }
                    if let requestContainerLayout = self.requestContainerLayout {
                        requestContainerLayout(transition)
                    } else {
                        self.requestLayout()
                    }
                }
            }
        }
        self.invalidateCalculatedLayout()
        self.requestLayout()
    }

    private let titleNode: ImmediateTextNode

    private var previousItemListenerKey: Int?
    private var previousItemBackListenerKey: Int?

    override public var accessibilityElements: [Any]? {
        get {
            var accessibilityElements: [Any] = []
            if self.backButtonNodeImpl.view.superview != nil {
                addAccessibilityChildren(of: self.backButtonNodeImpl, container: self, to: &accessibilityElements)
            }
            if self.leftButtonNodeImpl.view.superview != nil {
                addAccessibilityChildren(of: self.leftButtonNodeImpl, container: self, to: &accessibilityElements)
            }
            if self.titleNode.view.superview != nil {
                addAccessibilityChildren(of: self.titleNode, container: self, to: &accessibilityElements)
                accessibilityElements.append(self.titleNode)
            }
            if let titleView = self.titleView, titleView.superview != nil {
                titleView.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(titleView.bounds, in: titleView)
                accessibilityElements.append(titleView)
            }
            if self.rightButtonNodeImpl.view.superview != nil {
                addAccessibilityChildren(of: self.rightButtonNodeImpl, container: self, to: &accessibilityElements)
            }
            if let contentNode = self.contentNode {
                addAccessibilityChildren(of: contentNode, container: self, to: &accessibilityElements)
            }
            if let secondaryContentNode = self.secondaryContentNode {
                addAccessibilityChildren(of: secondaryContentNode, container: self, to: &accessibilityElements)
            }
            return accessibilityElements
        } set(value) {
        }
    }

    public var enableAutomaticBackButton: Bool = true

    public var hidesBackButton: Bool = false {
        didSet {
            if self.hidesBackButton != oldValue {
                self.updateLeftButton(animated: false)
                self.invalidateCalculatedLayout()
                self.requestLayout()
            }
        }
    }

    private var _previousItem: NavigationPreviousAction?
    public var previousItem: NavigationPreviousAction? {
        get {
            if !self.enableAutomaticBackButton {
                return nil
            }
            return self._previousItem
        } set(value) {
            if !self.enableAutomaticBackButton {
                self._previousItem = nil
                return
            }
            if self._previousItem != value {
                if let previousValue = self._previousItem, case let .item(itemValue) = previousValue {
                    if let previousItemListenerKey = self.previousItemListenerKey {
                        itemValue.removeSetTitleListener(previousItemListenerKey)
                        self.previousItemListenerKey = nil
                    }
                    if let previousItemBackListenerKey = self.previousItemBackListenerKey {
                        itemValue.removeSetBackBarButtonItemListener(previousItemBackListenerKey)
                        self.previousItemBackListenerKey = nil
                    }
                }
                self._previousItem = value

                if let previousItem = value {
                    switch previousItem {
                    case let .item(itemValue):
                        self.previousItemListenerKey = itemValue.addSetTitleListener { [weak self] _, _ in
                            self?.previousItemTitleUpdated()
                        }
                        self.previousItemBackListenerKey = itemValue.addSetBackBarButtonItemListener { [weak self] _, _, _ in
                            self?.previousItemTitleUpdated()
                        }
                    case .close:
                        break
                    }
                }
                self.updateLeftButton(animated: false)

                self.invalidateCalculatedLayout()
                self.requestLayout()
            }
        }
    }

    private func previousItemTitleUpdated() {
        if let item = self.item, item.leftBarButtonItem == nil, let previousItem = self.previousItem, case .item = previousItem, self.backButtonNodeImpl.view.superview != nil {
            self.backButtonNodeImpl.updateManualText(self.backButtonTitle() ?? self.presentationData.strings.back, isBack: true)
            self.invalidateCalculatedLayout()
            self.requestLayout()
        }
    }

    /// The back button's text: the left item drawn as a back button, else the previous screen's back item or title.
    private func backButtonTitle() -> String? {
        if let leftBarButtonItem = self.item?.leftBarButtonItem, leftBarButtonItem.backButtonAppearance {
            return leftBarButtonItem.title ?? self.presentationData.strings.back
        } else if let previousItem = self.previousItem {
            switch previousItem {
            case let .item(itemValue):
                if let backBarButtonItem = itemValue.backBarButtonItem {
                    return backBarButtonItem.title ?? self.presentationData.strings.back
                } else {
                    return itemValue.title ?? self.presentationData.strings.back
                }
            case .close:
                return nil
            }
        }
        return nil
    }

    /// The item's badge, kept to be shown again when the theme stops hiding it.
    private var badgeText: String?

    private func updateBadgeText(text: String?) {
        self.badgeText = text
        // A theme that hides the badge (`hideBadge`) shows the back title instead.
        let actualText = self.colors.badgeBackgroundColor.alpha == 0.0 ? "" : (text ?? "")
        if self.badgeNode.text != actualText {
            self.badgeNode.text = actualText
            self.badgeNode.isHidden = actualText.isEmpty
            // The badge takes the back title's place.
            self.backButtonNodeImpl.manualAlpha = self.badgeNode.isHidden ? 1.0 : 0.0

            self.invalidateCalculatedLayout()
            self.requestLayout()
        }
    }

    private func fadeOutSnapshot(of node: ASDisplayNode) {
        guard node.view.superview != nil, let snapshotView = node.view.snapshotContentTree() else {
            return
        }
        snapshotView.frame = node.frame
        node.view.superview?.insertSubview(snapshotView, aboveSubview: node.view)
        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
            snapshotView?.removeFromSuperview()
        })
    }

    private func updateLeftButton(animated: Bool) {
        if let item = self.item {
            if self.hidesBackButton && item.leftBarButtonItem == nil {
                self.leftButtonNodeImpl.view.removeFromSuperview()
                self.backButtonNodeImpl.view.removeFromSuperview()
                self.backButtonArrow.view.removeFromSuperview()
                self.badgeNode.view.removeFromSuperview()
                return
            }
            var needsLeftButton = false
            if let leftBarButtonItem = item.leftBarButtonItem, !leftBarButtonItem.backButtonAppearance {
                needsLeftButton = true
            } else if let previousItem = self.previousItem, case .close = previousItem {
                needsLeftButton = true
            }

            if needsLeftButton {
                if animated {
                    self.fadeOutSnapshot(of: self.backButtonNodeImpl)
                    self.fadeOutSnapshot(of: self.backButtonArrow)
                    self.fadeOutSnapshot(of: self.badgeNode)
                }

                self.backButtonNodeImpl.view.removeFromSuperview()
                self.backButtonArrow.view.removeFromSuperview()
                self.badgeNode.view.removeFromSuperview()

                if let leftBarButtonItem = item.leftBarButtonItem {
                    self.leftButtonNodeImpl.updateItems([], animated: animated)
                    self.leftButtonNodeImpl.updateItems([leftBarButtonItem], animated: animated)
                } else {
                    // The first screen of a modal stack: the flat bar's "Close".
                    self.leftButtonNodeImpl.updateItems([], animated: animated)
                    self.leftButtonNodeImpl.updateItems([UIBarButtonItem(title: "___close", style: .plain, target: nil, action: nil)], animated: animated)
                }

                if self.leftButtonNodeImpl.supernode == nil {
                    self.buttonsContainerNode.view.addSubview(self.leftButtonNodeImpl.view)
                }

                if animated {
                    self.leftButtonNodeImpl.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
            } else {
                if animated {
                    self.fadeOutSnapshot(of: self.leftButtonNodeImpl)
                }
                self.leftButtonNodeImpl.view.removeFromSuperview()

                if let backTitle = self.backButtonTitle() {
                    self.backButtonNodeImpl.updateManualText(backTitle, isBack: true)
                    if self.backButtonNodeImpl.supernode == nil {
                        self.buttonsContainerNode.view.addSubview(self.backButtonNodeImpl.view)
                        self.buttonsContainerNode.view.addSubview(self.backButtonArrow.view)
                        self.buttonsContainerNode.view.addSubview(self.badgeNode.view)
                    }

                    if animated {
                        self.backButtonNodeImpl.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        self.backButtonArrow.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        self.badgeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                } else {
                    self.backButtonNodeImpl.view.removeFromSuperview()
                    self.backButtonArrow.view.removeFromSuperview()
                    self.badgeNode.view.removeFromSuperview()
                }
            }
        } else {
            self.leftButtonNodeImpl.view.removeFromSuperview()
            self.backButtonNodeImpl.view.removeFromSuperview()
            self.backButtonArrow.view.removeFromSuperview()
            self.badgeNode.view.removeFromSuperview()
        }
    }

    private func updateRightButton(animated: Bool) {
        if let item = self.item {
            var items: [UIBarButtonItem] = []
            if let rightBarButtonItems = item.rightBarButtonItems, !rightBarButtonItems.isEmpty {
                items = rightBarButtonItems
            } else if let rightBarButtonItem = item.rightBarButtonItem {
                items = [rightBarButtonItem]
            }

            self.rightButtonNodeUpdated = true

            if !items.isEmpty {
                if self.rightButtonNodeImpl.isEmpty {
                    self.rightButtonNodeImpl.updateItems(items, animated: false)
                } else {
                    self.rightButtonNodeImpl.updateItems([], animated: animated)
                    self.rightButtonNodeImpl.updateItems(items, animated: animated)
                }
                if self.rightButtonNodeImpl.view.superview == nil {
                    self.buttonsContainerNode.view.addSubview(self.rightButtonNodeImpl.view)
                }
            } else {
                if animated {
                    self.fadeOutSnapshot(of: self.rightButtonNodeImpl)
                }
                self.rightButtonNodeImpl.view.removeFromSuperview()
                self.rightButtonNodeImpl.updateItems([], animated: false)
            }
        } else {
            if animated {
                self.fadeOutSnapshot(of: self.rightButtonNodeImpl)
            }
            self.rightButtonNodeImpl.view.removeFromSuperview()
            self.rightButtonNodeImpl.updateItems([], animated: false)
        }
    }

    private let backgroundNode: NavigationBackgroundNode
    private let backButtonNodeImpl: ClassicNavigationButtonNode
    private let badgeNode: ClassicNavigationBarBadgeNode
    private let backButtonArrow: ASImageNode
    private let leftButtonNodeImpl: ClassicNavigationButtonNode
    private let rightButtonNodeImpl: ClassicNavigationButtonNode
    private var rightButtonNodeUpdated: Bool = false
    public let additionalContentNode: SparseNode

    public var secondaryContentHeight: CGFloat

    public let customOverBackgroundContentView: UIView

    /// `setHidden` (the controller, from `displayNavigationBar`) and `setRowHiddenByScreen` (the screen) both hide the
    /// buttons and titles; a replacement content node takes their place too.
    private var isRowHiddenByController = false
    private var isRowHiddenByScreen = false

    private var backgroundAlpha: CGFloat = 1.0

    public init(presentationData: NavigationBarPresentationData) {
        self.presentationData = presentationData
        self.colors = ClassicNavigationBarColors(theme: presentationData.theme, palette: ClassicNavigationBarPaletteSource.shared.palette(matching: presentationData.theme))

        self.stripeNode = ASDisplayNode()

        self.titleNode = ImmediateTextNode()
        self.titleNode.isAccessibilityElement = true
        self.titleNode.accessibilityTraits = .header

        self.backButtonNodeImpl = ClassicNavigationButtonNode()
        self.backButtonNodeImpl.hitTestSlop = UIEdgeInsets(top: 0.0, left: -20.0, bottom: 0.0, right: 0.0)

        self.badgeNode = ClassicNavigationBarBadgeNode(fillColor: self.colors.badgeBackgroundColor, strokeColor: self.colors.badgeBackgroundColor, textColor: self.colors.badgeTextColor)
        self.badgeNode.isUserInteractionEnabled = false
        self.badgeNode.isHidden = true
        self.backButtonArrow = ASImageNode()
        self.backButtonArrow.displayWithoutProcessing = true
        self.backButtonArrow.displaysAsynchronously = false
        self.backButtonArrow.isUserInteractionEnabled = false
        self.leftButtonNodeImpl = ClassicNavigationButtonNode()
        self.rightButtonNodeImpl = ClassicNavigationButtonNode()
        self.rightButtonNodeImpl.hitTestSlop = UIEdgeInsets(top: -4.0, left: -4.0, bottom: -4.0, right: -10.0)

        self.clippingNode = SparseNode()
        self.clippingNode.clipsToBounds = true

        self.buttonsContainerNode = SparseNode()

        self.backgroundNode = NavigationBackgroundNode(color: self.colors.backgroundColor ?? .clear, enableBlur: self.colors.enableBlur)
        self.additionalContentNode = SparseNode()

        self.secondaryContentHeight = ClassicNavigationBarImpl.defaultSecondaryContentHeight

        self.customOverBackgroundContentView = SparseContainerView()

        super.init()

        self.addSubnode(self.backgroundNode)
        self.view.addSubview(self.customOverBackgroundContentView)
        self.addSubnode(self.buttonsContainerNode)
        self.addSubnode(self.clippingNode)
        self.addSubnode(self.additionalContentNode)

        self.stripeNode.isLayerBacked = true
        self.stripeNode.displaysAsynchronously = false
        self.addSubnode(self.stripeNode)

        self.backgroundColor = nil
        self.isOpaque = false

        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationType = .end
        self.titleNode.isOpaque = false

        self.applyColors()

        self.backButtonNodeImpl.highlightChanged = { [weak self] index, highlighted in
            if let strongSelf = self, index == 0 {
                strongSelf.backButtonArrow.alpha = (highlighted ? 0.4 : 1.0)
                strongSelf.badgeNode.alpha = (highlighted ? 0.4 : 1.0)
            }
        }
        self.backButtonNodeImpl.pressed = { [weak self] index in
            if let strongSelf = self, index == 0 {
                if let leftBarButtonItem = strongSelf.item?.leftBarButtonItem, leftBarButtonItem.backButtonAppearance {
                    leftBarButtonItem.performActionOnTarget()
                } else {
                    strongSelf.backPressed()
                }
            }
        }
        self.backButtonNodeImpl.activated = { [weak self] gesture, _ in
            guard let self, let backButtonContextAction = self.backButtonContextAction else {
                gesture.cancel()
                return
            }
            backButtonContextAction(self.backButtonNodeImpl.view, gesture)
        }

        self.leftButtonNodeImpl.pressed = { [weak self] index in
            if let item = self?.item {
                if index == 0 {
                    if let leftBarButtonItem = item.leftBarButtonItem {
                        leftBarButtonItem.performActionOnTarget()
                    } else if let previousItem = self?.previousItem, case .close = previousItem {
                        self?.backPressed()
                    }
                }
            }
        }
        self.leftButtonNodeImpl.requestUpdate = { [weak self] in
            self?.requestLayout()
        }

        self.rightButtonNodeImpl.pressed = { [weak self] index in
            if let item = self?.item {
                if let rightBarButtonItems = item.rightBarButtonItems, !rightBarButtonItems.isEmpty {
                    if index < rightBarButtonItems.count {
                        rightBarButtonItems[index].performActionOnTarget()
                    }
                } else if let rightBarButtonItem = item.rightBarButtonItem {
                    rightBarButtonItem.performActionOnTarget()
                }
            }
        }
        self.rightButtonNodeImpl.requestUpdate = { [weak self] in
            self?.requestLayout()
        }

        ClassicNavigationBarPaletteSource.shared.register(self)
    }

    // MARK: - Colours

    private func applyColors(transition: ContainedViewLayoutTransition = .immediate) {
        let colors = self.colors

        if let backgroundColor = colors.backgroundColor {
            self.backgroundNode.isHidden = false
            self.backgroundNode.updateColor(color: backgroundColor, enableBlur: colors.enableBlur, transition: transition)
        } else {
            self.backgroundNode.isHidden = true
            self.backgroundNode.updateColor(color: .clear, enableBlur: false, transition: .immediate)
        }
        self.stripeNode.backgroundColor = colors.separatorColor

        for buttonNode in [self.backButtonNodeImpl, self.leftButtonNodeImpl, self.rightButtonNodeImpl] {
            buttonNode.color = colors.buttonColor
            buttonNode.disabledColor = colors.disabledButtonColor
            buttonNode.closeTitle = self.presentationData.strings.close
        }
        self.backButtonArrow.image = navigationBarBackArrowImage(color: colors.buttonColor)
        if let title = self.title {
            self.titleNode.attributedText = NSAttributedString(string: title, font: ClassicNavigationBarImpl.titleFont, textColor: colors.primaryTextColor)
            self.titleNode.accessibilityLabel = title
        }
        self.badgeNode.updateTheme(fillColor: colors.badgeBackgroundColor, strokeColor: colors.badgeBackgroundColor, textColor: colors.badgeTextColor)
    }

    private func updateColors(transition: ContainedViewLayoutTransition) {
        let colors = ClassicNavigationBarColors(theme: self.presentationData.theme, palette: ClassicNavigationBarPaletteSource.shared.palette(matching: self.presentationData.theme))
        if colors != self.colors {
            self.colors = colors
            self.applyColors(transition: transition)
            self.updateBadgeText(text: self.badgeText)
            self.requestLayout()
        }
    }

    /// The app switched themes: a bar that heard of the change first resolved its colours without the new palette.
    func paletteSourceUpdated() {
        self.updateColors(transition: .immediate)
    }

    public func updatePresentationData(_ presentationData: NavigationBarPresentationData, transition: ContainedViewLayoutTransition) {
        if presentationData.theme !== self.presentationData.theme || presentationData.strings !== self.presentationData.strings {
            let stringsUpdated = presentationData.strings !== self.presentationData.strings
            self.presentationData = presentationData

            self.updateColors(transition: transition)
            if stringsUpdated {
                for buttonNode in [self.backButtonNodeImpl, self.leftButtonNodeImpl, self.rightButtonNodeImpl] {
                    buttonNode.closeTitle = presentationData.strings.close
                }
                // "Close" and the "Back" fallback are drawn from the strings.
                self.updateRightButton(animated: false)
            }

            self.updateLeftButton(animated: false)
            self.requestLayout()
        }
    }

    // MARK: - Backdrop

    public var isBackdropVisible: Bool {
        return self.backgroundAlpha == 1.0
    }

    public func setBackdropAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        let alpha = max(0.0, min(1.0, alpha))
        self.backgroundAlpha = alpha
        transition.updateAlpha(node: self.backgroundNode, alpha: alpha, delay: 0.15)
        transition.updateAlpha(node: self.stripeNode, alpha: alpha, delay: 0.15)
    }

    public func updateEdgeEffectExtension(value: CGFloat, transition: ContainedViewLayoutTransition) {
        // The flat bar has no edge effect to extend.
    }

    // MARK: - Layout

    private func requestLayout() {
        self.requestedLayout = true
        self.setNeedsLayout()
    }

    override public func layout() {
        super.layout()

        if let validLayout = self.validLayout, self.requestedLayout {
            self.requestedLayout = false
            self.updateLayout(size: validLayout.size, defaultHeight: validLayout.defaultHeight, additionalTopHeight: validLayout.additionalTopHeight, additionalContentHeight: validLayout.additionalContentHeight, additionalBackgroundHeight: validLayout.additionalBackgroundHeight, leftInset: validLayout.leftInset, rightInset: validLayout.rightInset, appearsHidden: validLayout.appearsHidden, transition: .immediate)
        }
    }

    public func updateLayout(size: CGSize, defaultHeight: CGFloat, additionalTopHeight: CGFloat, additionalContentHeight: CGFloat, additionalBackgroundHeight: CGFloat, leftInset: CGFloat, rightInset: CGFloat, appearsHidden: Bool, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, defaultHeight, additionalTopHeight, additionalContentHeight, additionalBackgroundHeight, leftInset, rightInset, appearsHidden)

        // `ViewController` no longer says whether the screen is in landscape (it passed `size.width > size.height` of its
        // layout); the window's bounds are that layout's size.
        var isLandscape = false
        if let window = self.view.window {
            isLandscape = window.bounds.width > window.bounds.height
        }
        let contentVerticalOrigin = additionalTopHeight
        // Content nodes (search fields, a pane's own navigation content) are laid out against the glass bar's row
        // origin (`NavigationBarNode`: 2pt below the status bar) and place their contents from their own top edge.
        let contentNodeVerticalOrigin = additionalTopHeight + 2.0
        let nominalHeight = ClassicNavigationBarImpl.nominalHeight

        let backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + additionalBackgroundHeight))
        if self.backgroundNode.frame != backgroundFrame {
            transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
            self.backgroundNode.update(size: backgroundFrame.size, transition: transition)
        }
        transition.updateFrame(view: self.customOverBackgroundContentView, frame: backgroundFrame)

        let apparentAdditionalHeight: CGFloat = self.secondaryContentNode != nil ? self.secondaryContentHeight : 0.0

        let leftButtonInset: CGFloat = leftInset + 16.0
        // Its own side's inset (iPhone Duo's side strip makes them differ; with equal insets this is `leftButtonInset`).
        let rightButtonInset: CGFloat = rightInset + self.trailingButtonsInset + 16.0
        let backButtonInset: CGFloat = leftInset + 27.0

        transition.updateFrame(node: self.clippingNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.additionalContentNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + additionalBackgroundHeight)))
        transition.updateFrame(node: self.buttonsContainerNode, frame: CGRect(origin: CGPoint(), size: size))
        if let contentNode = self.contentNode {
            var contentNodeFrame: CGRect
            switch contentNode.mode {
            case .replacement:
                // Not the flat bar's old full-height frame from y = 0: today's replacement nodes (the chat's and the
                // group's search) draw their field at a fixed offset from their top, which would put it under the
                // status bar.
                contentNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: contentNodeVerticalOrigin), size: CGSize(width: size.width, height: contentNode.nominalHeight))
                transition.updateFrame(node: contentNode, frame: contentNodeFrame)
                // It takes the bar's row, so its trailing end keeps clear of a status island beside the bar (iPhone Duo).
                let _ = contentNode.updateLayout(size: contentNodeFrame.size, leftInset: leftInset, rightInset: rightInset + self.trailingButtonsInset, transition: transition)
            case .expansion:
                let expansionHeight = contentNode.height

                let additionalExpansionHeight: CGFloat = self.secondaryContentNode != nil && appearsHidden ? self.secondaryContentHeight : 0.0
                contentNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - (appearsHidden ? 0.0 : additionalContentHeight) - expansionHeight - apparentAdditionalHeight - additionalExpansionHeight), size: CGSize(width: size.width, height: expansionHeight))
                if appearsHidden {
                    contentNodeFrame.origin.y = size.height - contentNode.height + contentNodeVerticalOrigin
                    if self.secondaryContentNode != nil {
                        contentNodeFrame.origin.y += self.secondaryContentHeight
                    }
                }

                transition.updateFrame(node: contentNode, frame: contentNodeFrame)
                let _ = contentNode.updateLayout(size: contentNodeFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
            }
        }

        transition.updateFrame(node: self.stripeNode, frame: CGRect(x: 0.0, y: size.height + additionalBackgroundHeight, width: size.width, height: UIScreenPixel))

        var leftTitleInset: CGFloat = leftInset + 1.0
        var rightTitleInset: CGFloat = rightInset + 1.0
        if self.backButtonNodeImpl.view.superview != nil {
            var backButtonSize = self.backButtonNodeImpl.updateLayout(constrainedSize: CGSize(width: size.width, height: nominalHeight), isLandscape: isLandscape)
            // A long previous title would crowd the title out: the flat bar's screens name their back button "Back"
            // (`backBarButtonItem`), and the rest fall back to it.
            let maxBackButtonWidth = max(80.0, floor(size.width * 0.3))
            if backButtonSize.width > maxBackButtonWidth, let item = self.item, item.leftBarButtonItem == nil {
                self.backButtonNodeImpl.updateManualText(self.presentationData.strings.back, isBack: true)
                backButtonSize = self.backButtonNodeImpl.updateLayout(constrainedSize: CGSize(width: size.width, height: nominalHeight), isLandscape: isLandscape)
            }
            leftTitleInset = backButtonSize.width + backButtonInset + 1.0
            if !self.badgeNode.isHidden {
                // The badge takes the back title's place (`updateBadgeText`).
                let badgeWidth = self.badgeNode.measure(CGSize(width: 200.0, height: 100.0)).width
                leftTitleInset = leftInset + 8.0 + 16.0 + badgeWidth + 4.0
            }

            let topHitTestSlop = (nominalHeight - backButtonSize.height) * 0.5
            self.backButtonNodeImpl.updateHitTestSlop(UIEdgeInsets(top: -topHitTestSlop, left: -27.0, bottom: -topHitTestSlop, right: -8.0))

            transition.updateFrame(node: self.backButtonNodeImpl, frame: CGRect(origin: CGPoint(x: backButtonInset, y: contentVerticalOrigin + floor((nominalHeight - backButtonSize.height) / 2.0)), size: backButtonSize))

            let backButtonArrowSize = CGSize(width: 13.0, height: 22.0)
            transition.updateFrame(node: self.backButtonArrow, frame: CGRect(origin: CGPoint(x: leftInset + 8.0, y: contentVerticalOrigin + floor((nominalHeight - backButtonArrowSize.height) / 2.0)), size: backButtonArrowSize))
        } else if self.leftButtonNodeImpl.view.superview != nil {
            let leftButtonSize = self.leftButtonNodeImpl.updateLayout(constrainedSize: CGSize(width: size.width, height: nominalHeight), isLandscape: isLandscape)
            leftTitleInset = leftButtonSize.width + leftButtonInset + 1.0

            var transition = transition
            if self.leftButtonNodeImpl.frame.width.isZero {
                transition = .immediate
            }

            transition.updateFrame(node: self.leftButtonNodeImpl, frame: CGRect(origin: CGPoint(x: leftButtonInset, y: contentVerticalOrigin + floor((nominalHeight - leftButtonSize.height) / 2.0)), size: leftButtonSize))
        }

        let badgeSize = self.badgeNode.measure(CGSize(width: 200.0, height: 100.0))
        let backButtonArrowFrame = self.backButtonArrow.frame
        transition.updateFrame(node: self.badgeNode, frame: CGRect(origin: backButtonArrowFrame.origin.offsetBy(dx: 16.0, dy: 2.0), size: badgeSize))

        if self.rightButtonNodeImpl.view.superview != nil {
            let rightButtonSize = self.rightButtonNodeImpl.updateLayout(constrainedSize: CGSize(width: size.width, height: nominalHeight), isLandscape: isLandscape, isLeftAligned: false)
            rightTitleInset = rightButtonSize.width + rightButtonInset + 1.0

            var transition = transition
            if self.rightButtonNodeImpl.frame.width.isZero || self.rightButtonNodeUpdated {
                transition = .immediate
            }

            transition.updateFrame(node: self.rightButtonNodeImpl, frame: CGRect(origin: CGPoint(x: size.width - rightButtonInset - rightButtonSize.width, y: contentVerticalOrigin + floor((nominalHeight - rightButtonSize.height) / 2.0)), size: rightButtonSize))
        }
        self.rightButtonNodeUpdated = false

        // Titles are centred in the band between the side insets, clear of the buttons (iPhone Duo's strip makes the
        // insets differ; with equal insets this is full-width centring).
        (leftTitleInset, rightTitleInset) = navigationBarTitleInsets(leftInset: leftInset, rightInset: rightInset, leftTitleInset: leftTitleInset, rightTitleInset: rightTitleInset)

        if self.titleNode.supernode != nil {
            var transition = transition
            if self.titleNode.frame.width.isZero {
                transition = .immediate
            }

            let titleSize = self.titleNode.updateLayout(CGSize(width: max(1.0, size.width - leftTitleInset - rightTitleInset), height: nominalHeight))

            let titleX = navigationBarTextTitleOriginX(width: size.width, leftInset: leftInset, rightInset: rightInset, leftTitleInset: leftTitleInset, rightTitleInset: rightTitleInset, titleWidth: titleSize.width)
            transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: titleX, y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize))
        }

        if let titleView = self.titleView {
            if let titleView = titleView as? NavigationBarTitleView {
                var titleViewTransition = transition
                if titleView.frame.isEmpty {
                    titleViewTransition = .immediate
                }

                let titleSize = titleView.updateLayout(availableSize: CGSize(width: max(1.0, size.width - leftTitleInset - rightTitleInset), height: nominalHeight), transition: titleViewTransition)

                let titleX = navigationBarTitleViewOriginX(width: size.width, leftInset: leftInset, rightInset: rightInset, leftTitleInset: leftTitleInset, rightTitleInset: rightTitleInset, titleWidth: titleSize.width)
                let titleFrame = CGRect(origin: CGPoint(x: titleX, y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)

                titleViewTransition.updateFrame(view: titleView, frame: titleFrame)
            } else {
                let titleHorizontalFrame = navigationBarFillingTitleFrame(width: size.width, leftInset: leftInset, rightInset: rightInset, leftTitleInset: leftTitleInset, rightTitleInset: rightTitleInset)
                let titleSize = CGSize(width: titleHorizontalFrame.width, height: nominalHeight)
                let titleFrame = CGRect(origin: CGPoint(x: titleHorizontalFrame.x, y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
                var titleViewTransition = transition
                if titleView.frame.isEmpty {
                    titleViewTransition = .immediate
                    titleView.frame = titleFrame
                }

                titleViewTransition.updateFrame(view: titleView, frame: titleFrame)
            }
        }
    }

    public var intrinsicCanTransitionInline: Bool = true

    public var passthroughTouches = true

    public var canTransitionInline: Bool {
        if let contentNode = self.contentNode, case .replacement = contentNode.mode {
            return false
        } else {
            return self.intrinsicCanTransitionInline
        }
    }

    public func contentHeight(defaultHeight: CGFloat) -> CGFloat {
        let rowHeight = ClassicNavigationBarImpl.rowHeight(defaultHeight: defaultHeight)

        var result: CGFloat = 0.0
        if let contentNode = self.contentNode {
            switch contentNode.mode {
            case .expansion:
                result += rowHeight + contentNode.height
            case .replacement:
                result += contentNode.height
            }
        } else {
            result += rowHeight
        }

        if let _ = self.secondaryContentNode {
            result += self.secondaryContentHeight
        }

        return result
    }

    // MARK: - Content

    public func setContentNode(_ contentNode: NavigationBarContentNode?, animated: Bool) {
        if self.contentNode !== contentNode {
            if let previous = self.contentNode {
                if animated {
                    previous.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self, weak previous] _ in
                        if let strongSelf = self, let previous = previous {
                            if previous !== strongSelf.contentNode {
                                previous.removeFromSupernode()
                            }
                        }
                    })
                } else {
                    previous.removeFromSupernode()
                }
            }
            self.contentNode = contentNode
            self.contentNode?.requestContainerLayout = { [weak self] transition in
                guard let self else {
                    return
                }
                self.requestContainerLayout?(transition)
            }
            if let contentNode {
                contentNode.layer.removeAnimation(forKey: "opacity")
                contentNode.clipsToBounds = true
                self.insertSubnode(contentNode, belowSubnode: self.stripeNode)
                if animated {
                    contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }

                self.applyButtonsAlpha(animated: animated)

                if !self.bounds.size.width.isZero {
                    self.requestedLayout = true
                    self.layout()
                } else {
                    self.requestLayout()
                }
            } else {
                self.applyButtonsAlpha(animated: animated)
                self.requestLayout()
            }
        }
    }

    public func setSecondaryContentNode(_ secondaryContentNode: ASDisplayNode?, animated: Bool) {
        if self.secondaryContentNode !== secondaryContentNode {
            if let previous = self.secondaryContentNode, previous.supernode === self.clippingNode {
                if animated {
                    previous.layer.animateAlpha(from: previous.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previous] finished in
                        if finished {
                            previous?.removeFromSupernode()
                            previous?.layer.removeAllAnimations()
                        }
                    })
                } else {
                    previous.removeFromSupernode()
                }
            }
            self.secondaryContentNode = secondaryContentNode
            if let secondaryContentNode = secondaryContentNode {
                self.clippingNode.addSubnode(secondaryContentNode)

                if animated {
                    secondaryContentNode.layer.animateAlpha(from: 0.0, to: secondaryContentNode.alpha, duration: 0.3)
                }
            }
        }
    }

    public func executeBack() -> Bool {
        if self.backButtonNodeImpl.isInHierarchy {
            self.backButtonNodeImpl.pressed(0)
        } else if self.leftButtonNodeImpl.isInHierarchy {
            self.leftButtonNodeImpl.pressed(0)
        } else {
            self.backButtonNodeImpl.pressed(0)
        }
        return true
    }

    // MARK: - Visibility

    private var buttonsTargetAlpha: CGFloat {
        if let contentNode = self.contentNode, case .replacement = contentNode.mode {
            return 0.0
        }
        return (self.isRowHiddenByController || self.isRowHiddenByScreen) ? 0.0 : 1.0
    }

    private func applyButtonsAlpha(animated: Bool) {
        let targetAlpha = self.buttonsTargetAlpha
        let previousAlpha = self.buttonsContainerNode.alpha
        if previousAlpha != targetAlpha {
            self.buttonsContainerNode.alpha = targetAlpha
            if animated {
                self.buttonsContainerNode.layer.animateAlpha(from: previousAlpha, to: targetAlpha, duration: 0.2)
            }
        }
    }

    public func setHidden(_ hidden: Bool, animated: Bool) {
        self.isRowHiddenByController = hidden
        self.applyButtonsAlpha(animated: animated)
    }

    public func setRowHiddenByScreen(_ hidden: Bool, transition: ContainedViewLayoutTransition) {
        if self.isRowHiddenByScreen == hidden {
            return
        }
        self.isRowHiddenByScreen = hidden
        let targetAlpha = self.buttonsTargetAlpha
        if self.buttonsContainerNode.alpha != targetAlpha {
            transition.updateAlpha(node: self.buttonsContainerNode, alpha: targetAlpha)
        }
    }

    public func animateButtonsIn(duration: Double) {
        for node in [self.backButtonNodeImpl, self.backButtonArrow, self.leftButtonNodeImpl, self.rightButtonNodeImpl] as [ASDisplayNode] {
            if node.view.superview != nil {
                node.layer.animateAlpha(from: 0.0, to: node.alpha, duration: duration)
            }
        }
        if self.badgeNode.view.superview != nil && !self.badgeNode.isHidden {
            self.badgeNode.layer.animateAlpha(from: 0.0, to: self.badgeNode.alpha, duration: duration)
        }
    }

    // MARK: - Buttons

    public func rightButtonView(for item: UIBarButtonItem) -> UIView? {
        guard self.rightButtonNodeImpl.view.superview != nil else {
            return nil
        }
        return self.rightButtonNodeImpl.view(for: item)
    }

    public func navigationButtonContextContainer(sourceView: UIView) -> ContextExtractableContainer? {
        // The flat bar's buttons have no capsule to morph into a context menu: the menu opens from the button itself.
        return nil
    }

    public func backButtonFrame(in view: UIView) -> CGRect? {
        guard self.backButtonNodeImpl.view.superview != nil, self.backButtonArrow.view.superview != nil else {
            return nil
        }
        let frame = self.backButtonArrow.frame.union(self.backButtonNodeImpl.frame)
        return self.buttonsContainerNode.view.convert(frame, to: view)
    }

    // MARK: - iPhone Duo side column

    public var isBackInSideColumn: Bool {
        return false
    }

    public func sideColumnExtent(placement: NavigationBarSideColumnPlacement) -> NavigationBarSideColumnExtent? {
        return nil
    }

    // MARK: - Navigation transition

    public func takeView() -> NavigationBarTransitionTakeViewInfo? {
        // The flat bar slides with its screen, as it did before the glass bar's morph.
        return nil
    }

    public func putBack() {
    }

    public func updateTransition(role: NavigationBarTransitionRole?, fraction: CGFloat, transition: ContainedViewLayoutTransition) {
    }

    // MARK: - Touches

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.additionalContentNode.view.hitTest(self.view.convert(point, to: self.additionalContentNode.view), with: event) {
            return result
        }

        guard let result = super.hitTest(point, with: event) else {
            if !self.bounds.contains(point) {
                if let result = self.customOverBackgroundContentView.hitTest(self.view.convert(point, to: self.customOverBackgroundContentView), with: event) {
                    if result !== self.customOverBackgroundContentView {
                        return result
                    }
                }
            }
            return nil
        }

        if self.passthroughTouches && (result == self.view || result == self.buttonsContainerNode.view || result == self.backgroundNode.view || result == self.backgroundNode.backgroundView || result == self.customOverBackgroundContentView) {
            return nil
        }

        return result
    }
}
