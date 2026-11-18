import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext

final class PeerInfoScreenHeaderItem: PeerInfoScreenItem {
    let id: AnyHashable
    let text: String
    let label: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(id: AnyHashable, text: String, label: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.id = id
        self.text = text
        self.label = label
        self.actionTitle = actionTitle
        self.action = action
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenHeaderItemNode()
    }
}

private final class PeerInfoScreenHeaderItemNode: PeerInfoScreenItemNode {
    private let textNode: ImmediateTextNode
    private let labelNode: ImmediateTextNode
    private let actionButton: HighlightableButtonNode
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenHeaderItem?
    
    override init() {
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        self.actionButton = HighlightableButtonNode()
        self.actionButton.isHidden = true
        
        self.activateArea = AccessibilityAreaNode()
        self.activateArea.accessibilityTraits = [.staticText, .header]
        
        super.init()
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.activateArea)
        self.addSubnode(self.actionButton)
        
        self.actionButton.addTarget(self, action: #selector(self.actionPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func actionPressed() {
        self.item?.action?()
    }
    
    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenHeaderItem else {
            return 10.0
        }
        
        self.item = item
        
        let sideInset: CGFloat = 16.0 + safeInsets.left
        let sideInsetRight: CGFloat = 16.0 + safeInsets.right
        let verticalInset: CGFloat = 7.0
        
        self.textNode.maximumNumberOfLines = 0
        self.textNode.attributedText = NSAttributedString(string: item.text, font: Font.regular(13.0), textColor: presentationData.theme.list.freeTextColor)
        self.activateArea.accessibilityLabel = item.text
        
        let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset - sideInsetRight, height: .greatestFiniteMagnitude))
        
        let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalInset), size: textSize)
        
        self.labelNode.maximumNumberOfLines = 0
        self.labelNode.attributedText = NSAttributedString(string: item.label ?? "", font: Font.regular(13.0), textColor: presentationData.theme.list.freeTextColor)
        
        let labelSize = self.labelNode.updateLayout(CGSize(width: max(0.0, width - sideInset - sideInsetRight - textSize.width - 4.0), height: .greatestFiniteMagnitude))
        
        let labelFrame = CGRect(origin: CGPoint(x: width - sideInsetRight - labelSize.width, y: verticalInset), size: labelSize)
        
        if let actionTitle = item.actionTitle, item.action != nil {
            self.actionButton.isHidden = false
            self.actionButton.setAttributedTitle(NSAttributedString(string: actionTitle, font: Font.regular(13.0), textColor: presentationData.theme.list.itemAccentColor), for: .normal)
            self.actionButton.accessibilityLabel = actionTitle
            let buttonSize = self.actionButton.measure(CGSize(width: max(0.0, width - sideInset - sideInsetRight - textSize.width - 8.0), height: 44.0))
            let buttonFrame = CGRect(x: width - sideInsetRight - buttonSize.width - 8.0, y: verticalInset + floor((textSize.height - buttonSize.height) / 2.0) - 8.0, width: buttonSize.width + 16.0, height: buttonSize.height + 16.0)
            transition.updateFrame(node: self.actionButton, frame: buttonFrame)
        } else {
            self.actionButton.isHidden = true
        }
        
        let height = textSize.height + verticalInset * 2.0
        
        transition.updateFrame(node: self.textNode, frame: textFrame)
        transition.updateFrame(node: self.labelNode, frame: labelFrame)
        
        self.activateArea.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        
        return height
    }
}
