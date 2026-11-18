import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import AppBundle

/// The glass bar's back arrow (or a modal stack's close X): a 44pt-wide tap target that dims to 0.6 while
/// highlighted, widened for an unread badge, with an optional long-press menu.
final class NavigationBarBackButtonView: ContextControllerSourceView {
    enum Kind: Equatable {
        case back
        case close
    }

    private let onPressed: () -> Void
    private let button: HighlightableButton
    let arrowView: UIImageView
    private var badgeNode: NavigationBarBadgeNode?
    /// Madgram classic design: 12.0's back title beside the arrow.
    private var classicTitleView: ImmediateTextView?

    private var currentColor: UIColor?
    private var currentKind: Kind?
    private var contextAction: ((UIView, ContextGesture) -> Void)?

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed

        self.button = HighlightableButton()
        self.arrowView = UIImageView()

        super.init(frame: CGRect())

        self.isGestureEnabled = false
        self.isAccessibilityElement = true
        self.accessibilityTraits = [.button]
        self.button.isAccessibilityElement = false

        self.addSubview(self.button)
        self.button.addSubview(self.arrowView)

        self.button.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.button.alpha = 0.6
            } else {
                self.button.alpha = 1.0
                self.button.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
            }
        }
        self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)

        self.activated = { [weak self] gesture, _ in
            guard let self, let contextAction = self.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(self, gesture)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func pressed() {
        self.onPressed()
    }

    override func accessibilityActivate() -> Bool {
        self.onPressed()
        return true
    }

    func update(kind: Kind, badge: String?, contextAction: ((UIView, ContextGesture) -> Void)?, theme: NavigationBarTheme, strings: NavigationBarStrings, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
        self.contextAction = contextAction
        self.isGestureEnabled = contextAction != nil
        self.accessibilityLabel = kind == .close ? strings.close : strings.back

        if ClassicDesign.isEnabled {
            return self.updateClassic(kind: kind, badge: badge, theme: theme, strings: strings, availableSize: availableSize, transition: transition)
        }

        if self.currentColor != theme.buttonColor || self.currentKind != kind {
            self.currentColor = theme.buttonColor
            self.currentKind = kind
            switch kind {
            case .back:
                let imageSize = CGSize(width: 44.0, height: 44.0)
                let topRightPoint = CGPoint(x: 24.6, y: 14.0)
                let centerPoint = CGPoint(x: 17.0, y: imageSize.height * 0.5)
                self.arrowView.image = generateImage(imageSize, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setStrokeColor(UIColor.white.cgColor)
                    context.setLineWidth(2.0)
                    context.setLineCap(.round)
                    context.setLineJoin(.round)
                    context.move(to: topRightPoint)
                    context.addLine(to: centerPoint)
                    context.addLine(to: CGPoint(x: topRightPoint.x, y: size.height - topRightPoint.y))
                    context.strokePath()
                })?.withRenderingMode(.alwaysTemplate)
                self.arrowView.tintColor = theme.buttonColor
            case .close:
                self.arrowView.image = generateTintedImage(image: UIImage(bundleImageName: "Navigation/Close"), color: theme.buttonColor)
                self.arrowView.tintColor = nil
            }
        }

        var width: CGFloat = 44.0
        if let badge, !badge.isEmpty {
            let badgeNode: NavigationBarBadgeNode
            if let current = self.badgeNode {
                badgeNode = current
            } else {
                badgeNode = NavigationBarBadgeNode(fillColor: theme.buttonColor, strokeColor: theme.buttonColor, textColor: theme.badgeTextColor)
                badgeNode.isUserInteractionEnabled = false
                self.badgeNode = badgeNode
                self.button.addSubnode(badgeNode)
            }
            badgeNode.updateTheme(fillColor: theme.buttonColor, strokeColor: theme.buttonColor, textColor: theme.badgeTextColor)
            badgeNode.text = badge
            // As the old glass bar placed it: overlapping the arrow's cell, widening the capsule.
            let badgeSize = badgeNode.measure(CGSize(width: 200.0, height: 100.0))
            badgeNode.frame = CGRect(origin: CGPoint(x: 44.0 - 14.0, y: floor((availableSize.height - badgeSize.height) * 0.5)), size: badgeSize)
            width += badgeSize.width - 3.0
        } else if let badgeNode = self.badgeNode {
            self.badgeNode = nil
            badgeNode.removeFromSupernode()
        }

        let size = CGSize(width: width, height: availableSize.height)
        transition.setFrame(view: self.button, frame: CGRect(origin: CGPoint(), size: size))

        let arrowSize = self.arrowView.image?.size ?? CGSize(width: 13.0, height: 22.0)
        let arrowFrame = arrowSize.centered(in: CGRect(origin: CGPoint(), size: CGSize(width: 44.0, height: availableSize.height)))
        transition.setPosition(view: self.arrowView, position: arrowFrame.center)
        transition.setBounds(view: self.arrowView, bounds: CGRect(origin: CGPoint(), size: arrowFrame.size))

        return size
    }

    /// Madgram classic design: 12.0's flat back button (`ChatListHeaderComponent.BackButtonView` at release-12.0): the
    /// filled chevron and a "Back" title in the button color, no circle; a modal's close X stays an icon.
    private func updateClassic(kind: Kind, badge: String?, theme: NavigationBarTheme, strings: NavigationBarStrings, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
        let color = navigationBarClassicButtonColor(theme: theme, isEnabled: true)
        if self.currentColor != color || self.currentKind != kind {
            self.currentColor = color
            self.currentKind = kind
            switch kind {
            case .back:
                self.arrowView.image = NavigationBarTheme.generateBackArrowImage(color: color)
            case .close:
                self.arrowView.image = generateTintedImage(image: UIImage(bundleImageName: "Navigation/Close"), color: color)
            }
            self.arrowView.tintColor = nil
        }

        let arrowSize = self.arrowView.image?.size ?? CGSize(width: 13.0, height: 22.0)
        var width: CGFloat
        switch kind {
        case .back:
            let titleView: ImmediateTextView
            if let current = self.classicTitleView {
                titleView = current
            } else {
                titleView = ImmediateTextView()
                titleView.isUserInteractionEnabled = false
                self.classicTitleView = titleView
                self.button.addSubview(titleView)
            }
            titleView.attributedText = NSAttributedString(string: strings.back, font: Font.regular(17.0), textColor: color)
            let titleSize = titleView.updateLayout(CGSize(width: 100.0, height: availableSize.height))

            // As 12.0 measured it: the arrow 7 pt left of the button's origin (8 pt from the bar's inset edge), the title
            // 8 pt after it.
            let iconSpacing: CGFloat = 8.0
            let iconOffset: CGFloat = -7.0
            let arrowFrame = CGRect(origin: CGPoint(x: iconOffset - 1.0, y: floor((availableSize.height - arrowSize.height) / 2.0)), size: arrowSize)
            transition.setPosition(view: self.arrowView, position: arrowFrame.center)
            transition.setBounds(view: self.arrowView, bounds: CGRect(origin: CGPoint(), size: arrowFrame.size))
            transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: iconOffset - 3.0 + arrowSize.width + iconSpacing, y: floor((availableSize.height - titleSize.height) / 2.0)), size: titleSize))
            width = iconOffset + arrowSize.width + iconSpacing + titleSize.width
        case .close:
            if let titleView = self.classicTitleView {
                self.classicTitleView = nil
                titleView.removeFromSuperview()
            }
            let arrowFrame = CGRect(origin: CGPoint(x: 0.0, y: floor((availableSize.height - arrowSize.height) / 2.0)), size: arrowSize)
            transition.setPosition(view: self.arrowView, position: arrowFrame.center)
            transition.setBounds(view: self.arrowView, bounds: CGRect(origin: CGPoint(), size: arrowFrame.size))
            width = arrowSize.width
        }

        if let badge, !badge.isEmpty {
            let badgeNode: NavigationBarBadgeNode
            if let current = self.badgeNode {
                badgeNode = current
            } else {
                badgeNode = NavigationBarBadgeNode(fillColor: theme.badgeBackgroundColor, strokeColor: theme.badgeBackgroundColor, textColor: theme.badgeTextColor)
                badgeNode.isUserInteractionEnabled = false
                self.badgeNode = badgeNode
                self.button.addSubnode(badgeNode)
            }
            badgeNode.updateTheme(fillColor: theme.badgeBackgroundColor, strokeColor: theme.badgeBackgroundColor, textColor: theme.badgeTextColor)
            badgeNode.text = badge
            let badgeSize = badgeNode.measure(CGSize(width: 200.0, height: 100.0))
            badgeNode.frame = CGRect(origin: CGPoint(x: width + 6.0, y: floor((availableSize.height - badgeSize.height) * 0.5)), size: badgeSize)
            width += 6.0 + badgeSize.width
        } else if let badgeNode = self.badgeNode {
            self.badgeNode = nil
            badgeNode.removeFromSupernode()
        }

        let size = CGSize(width: max(1.0, width), height: availableSize.height)
        transition.setFrame(view: self.button, frame: CGRect(origin: CGPoint(), size: size))
        return size
    }
}
