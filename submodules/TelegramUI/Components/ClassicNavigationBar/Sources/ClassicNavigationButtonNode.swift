import UIKit
import AsyncDisplayKit
import Display
import AppBundle

/// One button of the classic bar: a text, an image or a node the screen owns, tinted with the bar's button colour
/// (`NavigationButtonItemNode` of the flat bar).
final class ClassicNavigationButtonItemNode: ImmediateTextNode {
    var requestUpdate: (() -> Void)?

    private func fontForCurrentState() -> UIFont {
        return self.bold ? UIFont.boldSystemFont(ofSize: 17.0) : UIFont.systemFont(ofSize: 17.0)
    }

    private func attributesForCurrentState() -> [NSAttributedString.Key: AnyObject] {
        return [
            NSAttributedString.Key.font: self.fontForCurrentState(),
            NSAttributedString.Key.foregroundColor: self.isEnabled ? self.color : self.disabledColor
        ]
    }

    private var setEnabledListener: Int?
    private var setTitleListener: Int?

    var item: UIBarButtonItem? {
        didSet {
            if self.item !== oldValue {
                if let oldValue {
                    if let setEnabledListener = self.setEnabledListener {
                        oldValue.removeSetEnabledListener(setEnabledListener)
                        self.setEnabledListener = nil
                    }
                    if let setTitleListener = self.setTitleListener {
                        oldValue.removeSetTitleListener(setTitleListener)
                        self.setTitleListener = nil
                    }
                }

                if let item = self.item {
                    self.setEnabledListener = item.addSetEnabledListener { [weak self] value in
                        guard let self else {
                            return
                        }
                        if self.isEnabled != value {
                            self.isEnabled = value
                            self.requestUpdate?()
                        }
                    }
                    self.setTitleListener = item.addSetTitleListener { [weak self, weak item] value in
                        guard let self, let item, self.item === item else {
                            return
                        }
                        let title: String = (value as String?) ?? ""
                        // A plain text item (Edit / Done); the sentinel titles and images are set by `updateItems`.
                        if item.customDisplayNode == nil, item.image == nil, !title.hasPrefix("___") {
                            self.text = title
                            self.requestUpdate?()
                        }
                    }
                    self.accessibilityHint = item.accessibilityHint
                    self.accessibilityLabel = item.accessibilityLabel
                }
            }
        }
    }

    private var _text: String?
    var text: String {
        get {
            return self._text ?? ""
        }
        set(value) {
            self._text = value

            // VoiceOver reads the item's own label, else this text (`accessibilityLabel`).
            self.attributedText = NSAttributedString(string: self.text, attributes: self.attributesForCurrentState())
        }
    }

    private(set) var imageView: UIImageView?

    private var _image: UIImage?
    var image: UIImage? {
        get {
            return self._image
        } set(value) {
            self._image = value

            if let _ = value {
                if self.imageView == nil {
                    let imageView = UIImageView()
                    self.imageView = imageView

                    self.view.addSubview(imageView)
                }
                self.imageView?.image = self.image
                if self.imageView?.image?.renderingMode == .alwaysTemplate {
                    self.imageView?.tintColor = self.color
                } else {
                    self.imageView?.tintColor = nil
                }
            } else if let imageView = self.imageView {
                imageView.removeFromSuperview()
                self.imageView = nil
            }

            self.invalidateCalculatedLayout()
            self.setNeedsLayout()
        }
    }

    var node: ASDisplayNode? {
        didSet {
            if self.node !== oldValue {
                if oldValue?.supernode === self {
                    oldValue?.removeFromSupernode()
                }
                if let node = self.node {
                    self.addSubnode(node)
                    self.invalidateCalculatedLayout()
                    self.setNeedsLayout()
                    self.updatePointerInteraction()
                }
            }
        }
    }

    var color: UIColor = UIColor(rgb: 0x007aff) {
        didSet {
            if self.color != oldValue {
                if self.imageView?.image?.renderingMode == .alwaysTemplate {
                    self.imageView?.tintColor = self.color
                } else {
                    self.image = self.image
                }
                if let text = self._text {
                    self.attributedText = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
                }
            }
        }
    }

    var disabledColor: UIColor = UIColor(rgb: 0xd0d0d0) {
        didSet {
            if let text = self._text {
                self.attributedText = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
            }
        }
    }

    private var _bold: Bool = false
    var bold: Bool {
        get {
            return self._bold
        }
        set(value) {
            if self._bold != value {
                self._bold = value

                self.attributedText = NSAttributedString(string: self.text, attributes: self.attributesForCurrentState())
            }
        }
    }

    private var touchCount = 0
    var pressed: () -> () = { }
    var highlightChanged: (Bool) -> () = { _ in }

    override var isAccessibilityElement: Bool {
        get {
            return true
        } set(value) {
            super.isAccessibilityElement = true
        }
    }

    override var accessibilityLabel: String? {
        get {
            if let item = self.item, let accessibilityLabel = item.accessibilityLabel {
                return accessibilityLabel
            } else {
                return self.attributedText?.string
            }
        } set(value) {
        }
    }

    override var accessibilityHint: String? {
        get {
            if let item = self.item, let accessibilityHint = item.accessibilityHint {
                return accessibilityHint
            } else {
                return nil
            }
        } set(value) {
        }
    }

    private var pointerInteraction: PointerInteraction?

    override init() {
        super.init()

        self.isAccessibilityElement = true

        self.isUserInteractionEnabled = true
        self.isExclusiveTouch = true
        self.hitTestSlop = UIEdgeInsets(top: -16.0, left: -10.0, bottom: -16.0, right: -10.0)
        self.displaysAsynchronously = false

        self.verticalAlignment = .middle

        self.accessibilityTraits = .button
    }

    override func didLoad() {
        super.didLoad()
        self.updatePointerInteraction()
    }

    private func updatePointerInteraction() {
        guard self.isNodeLoaded else {
            return
        }
        let pointerStyle: PointerStyle
        if self.node != nil {
            pointerStyle = .lift
        } else {
            pointerStyle = .insetRectangle(-8.0, 2.0)
        }
        self.pointerInteraction = PointerInteraction(node: self, style: pointerStyle)
    }

    override func updateLayout(_ constrainedSize: CGSize) -> CGSize {
        var superSize = super.updateLayout(constrainedSize)

        if let node = self.node {
            let nodeSize = node.measure(constrainedSize)
            let size = CGSize(width: max(nodeSize.width, superSize.width), height: max(nodeSize.height, superSize.height))
            node.frame = CGRect(origin: CGPoint(), size: nodeSize)
            return size
        } else if let imageView = self.imageView {
            let nodeSize = imageView.image?.size ?? CGSize()
            let size = CGSize(width: max(nodeSize.width, superSize.width), height: max(44.0, max(nodeSize.height, superSize.height)))
            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - nodeSize.width) / 2.0), y: floorToScreenPixels((size.height - nodeSize.height) / 2.0)), size: nodeSize)
            imageView.frame = imageFrame
            return size
        } else {
            superSize.height = max(44.0, superSize.height)
        }
        return superSize
    }

    private func touchInsideApparentBounds(_ touch: UITouch) -> Bool {
        var apparentBounds = self.bounds
        let hitTestSlop = self.hitTestSlop
        apparentBounds.origin.x += hitTestSlop.left
        apparentBounds.size.width += -hitTestSlop.left - hitTestSlop.right
        apparentBounds.origin.y += hitTestSlop.top
        apparentBounds.size.height += -hitTestSlop.top - hitTestSlop.bottom

        return apparentBounds.contains(touch.location(in: self.view))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.touchCount += touches.count
        self.updateHighlightedState(true, animated: false)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.updateHighlightedState(false, animated: false)

        let previousTouchCount = self.touchCount
        self.touchCount = max(0, self.touchCount - touches.count)

        var touchInside = true
        if let touch = touches.first {
            touchInside = self.touchInsideApparentBounds(touch)
        }
        if previousTouchCount != 0 && self.touchCount == 0 && self.isEnabled && touchInside {
            self.pressed()
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let node = self.node as? HighlightableButtonNode {
            let result = node.view.hitTest(self.view.convert(point, to: node.view), with: event)
            return result
        } else {
            let previousAlpha = self.alpha
            self.alpha = 1.0
            let result = super.hitTest(point, with: event)
            self.alpha = previousAlpha
            return result
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)

        self.touchCount = max(0, self.touchCount - (touches?.count ?? 0))
        self.updateHighlightedState(false, animated: false)
    }

    private var _highlighted = false
    private func updateHighlightedState(_ highlighted: Bool, animated: Bool) {
        if self._highlighted != highlighted {
            self._highlighted = highlighted

            var shouldChangeHighlight = true
            if let node = self.node as? NavigationButtonCustomDisplayNode {
                shouldChangeHighlight = node.isHighlightable
            }

            if shouldChangeHighlight {
                if self.alpha > 0.0 {
                    self.alpha = !self.isEnabled ? 1.0 : (highlighted ? 0.4 : 1.0)
                }
                self.highlightChanged(highlighted)
            }
        }
    }

    var isEnabled: Bool = true {
        didSet {
            if self.isEnabled != oldValue {
                self.attributedText = NSAttributedString(string: self.text, attributes: self.attributesForCurrentState())
                if let constrainedSize = self.constrainedSize {
                    let _ = self.updateLayout(constrainedSize)
                }
            }
        }
    }
}

/// A row of classic buttons (the back button's text, the left button, or the right buttons), as
/// `NavigationButtonNodeImpl` drew them before the glass bar.
final class ClassicNavigationButtonNode: ContextControllerSourceNode {
    private var isBack: Bool = false

    private var items: [UIBarButtonItem] = []
    private var nodes: [ClassicNavigationButtonItemNode] = []
    /// Buttons fading out of a set swap, with the frame and row size they left at: a right-aligned row keeps them where
    /// they were on screen while the row resizes for the incoming set (12.0 `NavigationButtonNode.disappearingNodes`).
    private var disappearingNodes: [(frame: CGRect, size: CGSize, node: ClassicNavigationButtonItemNode)] = []

    var requestUpdate: (() -> Void)?

    /// The title the bar draws for `___close` (the old bar's "Close").
    var closeTitle: String = "Close"

    var pressed: (Int) -> () = { _ in }
    var highlightChanged: (Int, Bool) -> () = { _, _ in }

    var color: UIColor = UIColor(rgb: 0x007aff) {
        didSet {
            if !self.color.isEqual(oldValue) {
                for node in self.nodes {
                    node.color = self.color
                }
            }
        }
    }

    var disabledColor: UIColor = UIColor(rgb: 0xd0d0d0) {
        didSet {
            if !self.disabledColor.isEqual(oldValue) {
                for node in self.nodes {
                    node.disabledColor = self.disabledColor
                }
            }
        }
    }

    override var accessibilityElements: [Any]? {
        get {
            return self.nodes
        } set(value) {
        }
    }

    override init() {
        super.init()

        self.isAccessibilityElement = false
        self.isGestureEnabled = false
    }

    var manualAlpha: CGFloat = 1.0 {
        didSet {
            for node in self.nodes {
                node.alpha = self.manualAlpha
            }
        }
    }

    private func makeItemNode() -> ClassicNavigationButtonItemNode {
        let node = ClassicNavigationButtonItemNode()
        node.color = self.color
        node.disabledColor = self.disabledColor
        node.highlightChanged = { [weak node, weak self] value in
            if let strongSelf = self, let node = node {
                if let index = strongSelf.nodes.firstIndex(where: { $0 === node }) {
                    strongSelf.highlightChanged(index, value)
                }
            }
        }
        node.pressed = { [weak self, weak node] in
            if let strongSelf = self, let node = node {
                if let index = strongSelf.nodes.firstIndex(where: { $0 === node }) {
                    strongSelf.pressed(index)
                }
            }
        }
        node.requestUpdate = { [weak self] in
            self?.requestUpdate?()
        }
        return node
    }

    func updateManualText(_ text: String, isBack: Bool = true) {
        self.isBack = isBack
        self.items = []

        let node: ClassicNavigationButtonItemNode
        if self.nodes.count > 0 {
            node = self.nodes[0]
        } else {
            node = self.makeItemNode()
            self.nodes.append(node)
            self.addSubnode(node)
        }
        node.alpha = self.manualAlpha
        node.item = nil
        node.image = nil
        node.text = text
        node.bold = false
        node.isEnabled = true
        node.node = nil
        node.hitTestSlop = isBack ? UIEdgeInsets(top: 0.0, left: -20.0, bottom: 0.0, right: 0.0) : UIEdgeInsets()

        if 1 < self.nodes.count {
            for i in 1 ..< self.nodes.count {
                self.nodes[i].removeFromSupernode()
            }
            self.nodes.removeSubrange(1...)
        }
    }

    func updateItems(_ items: [UIBarButtonItem], animated: Bool) {
        self.isBack = false
        self.items = items

        for i in 0 ..< items.count {
            let node: ClassicNavigationButtonItemNode
            if self.nodes.count > i {
                node = self.nodes[i]
            } else {
                node = self.makeItemNode()
                self.nodes.append(node)
                self.addSubnode(node)
            }
            node.alpha = self.manualAlpha
            node.item = items[i]
            node.hitTestSlop = UIEdgeInsets(top: -16.0, left: -10.0, bottom: -16.0, right: -10.0)
            if items[i].customDisplayNode != nil {
                node.image = nil
                node.text = ""
            } else if items[i].title == "___close" {
                // The glass bar draws an X; the flat bar said "Close".
                node.image = nil
                node.text = self.closeTitle
            } else if items[i].title == "___clear" {
                node.text = ""
                node.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: .white)?.withRenderingMode(.alwaysTemplate)
            } else if items[i].title == "___done" {
                node.text = ""
                node.image = generateTintedImage(image: UIImage(bundleImageName: "Navigation/Done"), color: .white)?.withRenderingMode(.alwaysTemplate)
            } else {
                node.image = items[i].image
                node.text = items[i].title ?? ""
            }
            node.bold = items[i].style == .done
            node.isEnabled = items[i].isEnabled
            node.node = items[i].customDisplayNode

            if animated {
                node.layer.animateAlpha(from: 0.0, to: self.manualAlpha, duration: 0.16)
                node.layer.animateScale(from: 0.001, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            }
        }
        if items.count < self.nodes.count {
            for i in items.count ..< self.nodes.count {
                let itemNode = self.nodes[i]
                if animated {
                    self.disappearingNodes.append((itemNode.frame, self.bounds.size, itemNode))
                    itemNode.layer.animateAlpha(from: self.manualAlpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self, weak itemNode] _ in
                        guard let itemNode else {
                            return
                        }
                        itemNode.removeFromSupernode()
                        // Its item's listeners would otherwise outlive it in the item.
                        itemNode.item = nil
                        if let self, let index = self.disappearingNodes.firstIndex(where: { $0.node === itemNode }) {
                            self.disappearingNodes.remove(at: index)
                        }
                    })
                    itemNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                } else {
                    itemNode.removeFromSupernode()
                    itemNode.item = nil
                }
            }
            self.nodes.removeSubrange(items.count...)
        }
    }

    /// `isLeftAligned`: the row grows from its left edge (the left button); the right buttons' row grows leftwards from
    /// its right edge, so its fading-out buttons are re-anchored to that edge.
    func updateLayout(constrainedSize: CGSize, isLandscape: Bool, isLeftAligned: Bool = true) -> CGSize {
        var nodeOrigin = CGPoint(x: 0.0, y: 0.0)
        var totalHeight: CGFloat = 0.0
        for i in 0 ..< self.nodes.count {
            if i != 0 {
                nodeOrigin.x += 15.0
            }

            let node = self.nodes[i]

            var nodeSize = node.updateLayout(constrainedSize)

            nodeSize.width = ceil(nodeSize.width)
            nodeSize.height = ceil(nodeSize.height)
            totalHeight = max(totalHeight, nodeSize.height)
            node.frame = CGRect(origin: CGPoint(x: nodeOrigin.x, y: floor((totalHeight - nodeSize.height) / 2.0)), size: nodeSize)
            nodeOrigin.x += node.bounds.width
            if isLandscape {
                nodeOrigin.x += 16.0
            }

            if node.node == nil && node.imageView != nil && i == self.nodes.count - 1 {
                nodeOrigin.x -= 5.0
            }
        }

        if !isLeftAligned {
            for disappearingNode in self.disappearingNodes {
                disappearingNode.node.frame = disappearingNode.frame.offsetBy(dx: nodeOrigin.x - disappearingNode.size.width, dy: (totalHeight - disappearingNode.size.height) * 0.5)
            }
        }

        return CGSize(width: nodeOrigin.x, height: totalHeight)
    }

    /// The back button's touch area, which also covers the arrow beside it: the row's and its text's.
    func updateHitTestSlop(_ hitTestSlop: UIEdgeInsets) {
        self.hitTestSlop = hitTestSlop
        if self.isBack, let node = self.nodes.first {
            node.hitTestSlop = hitTestSlop
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.nodes.count == 1 {
            // Within the slop (the back arrow left of the back title, the margin around a right button).
            if self.bounds.inset(by: self.hitTestSlop).contains(point) {
                if self.isBack {
                    return self.nodes[0].view
                }
                return self.nodes[0].view.hitTest(self.view.convert(point, to: self.nodes[0].view), with: event)
            } else {
                return nil
            }
        } else {
            return super.hitTest(point, with: event)
        }
    }

    /// The view drawing `item`, nil if this row shows none for it.
    func view(for item: UIBarButtonItem) -> UIView? {
        guard let index = self.items.firstIndex(where: { $0 === item }), index < self.nodes.count else {
            return nil
        }
        let node = self.nodes[index]
        if let customNode = node.node {
            return customNode.view
        }
        return node.view
    }

    /// The first button's view, for the bar's own sizing and frames (the back button's text).
    var mainContentView: UIView? {
        return self.nodes.first?.view
    }

    var isEmpty: Bool {
        if self.isBack {
            return false
        }
        for node in self.nodes {
            if node.bounds.width != 0.0 {
                return false
            }
        }
        return true
    }
}
