import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle

/// Madgram: the media viewer's footer buttons as Telegram 12.0 drew them while `ClassicDesign.isEnabled` — plain
/// white 44pt icons on the footer's flat dark bar, with no glass capsule around them: the forward button at the left
/// edge, delete at the right edge and every other button (edit, picture in picture, playback settings, …) packed
/// leftwards from delete, where 12.0 put its edit button.
final class ClassicGalleryFooterButtonsView: UIView {
    enum Content: Equatable {
        case icon(String)
        case settings(speed: String?, quality: String?)
    }

    struct Item {
        let id: AnyHashable
        let content: Content
        let action: () -> Void
    }

    private final class ButtonView: HighlightTrackingButton {
        let iconView = UIImageView()
        var customIcon: ComponentView<Empty>?
        var action: (() -> Void)?
        private var currentContent: Content?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.iconView.isUserInteractionEnabled = false
            self.iconView.contentMode = .center
            self.addSubview(self.iconView)

            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.layer.removeAnimation(forKey: "opacity")
                    self.alpha = 0.4
                } else {
                    self.alpha = 1.0
                    self.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func pressed() {
            self.action?()
        }

        func update(content: Content, size: CGSize) {
            let bounds = CGRect(origin: CGPoint(), size: size)
            switch content {
            case let .icon(name):
                if self.currentContent != content {
                    self.iconView.image = generateTintedImage(image: UIImage(bundleImageName: name), color: .white)
                }
                self.iconView.isHidden = false
                self.iconView.frame = bounds
                self.customIcon?.view?.isHidden = true
            case let .settings(speed, quality):
                self.iconView.isHidden = true
                let customIcon: ComponentView<Empty>
                if let current = self.customIcon {
                    customIcon = current
                } else {
                    customIcon = ComponentView()
                    self.customIcon = customIcon
                }
                let iconSize = customIcon.update(
                    transition: .immediate,
                    component: AnyComponent(SettingsNavigationIconComponent(speed: speed, quality: quality, isOpen: false)),
                    environment: {},
                    containerSize: size
                )
                if let iconView = customIcon.view {
                    if iconView.superview == nil {
                        iconView.isUserInteractionEnabled = false
                        self.addSubview(iconView)
                    }
                    iconView.isHidden = false
                    iconView.frame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
                }
            }
            self.currentContent = content
        }
    }

    private var buttons: [AnyHashable: ButtonView] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The button of an item, for presenting a menu from it.
    func itemView(id: AnyHashable) -> UIView? {
        return self.buttons[id]
    }

    /// Lays the buttons out in a row of `size`, 44pt each: `left` at the left edge, `right` at the right edge and
    /// `packed` leftwards from the right edge (after `right`, when there is one).
    func update(left: [Item], packed: [Item], right: [Item], size: CGSize, transition: ContainedViewLayoutTransition) {
        let buttonSize = CGSize(width: 44.0, height: 44.0)
        let spacing: CGFloat = 6.0

        var frames: [(Item, CGRect)] = []
        var leftX: CGFloat = 0.0
        for item in left {
            frames.append((item, CGRect(origin: CGPoint(x: leftX, y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)))
            leftX += buttonSize.width + spacing
        }
        var rightX: CGFloat = size.width
        for item in Array(right.reversed()) + Array(packed.reversed()) {
            rightX -= buttonSize.width
            frames.append((item, CGRect(origin: CGPoint(x: rightX, y: floor((size.height - buttonSize.height) / 2.0)), size: buttonSize)))
            rightX -= spacing
        }

        var validIds = Set<AnyHashable>()
        for (item, frame) in frames {
            validIds.insert(item.id)
            var itemTransition = transition
            let button: ButtonView
            if let current = self.buttons[item.id] {
                button = current
            } else {
                itemTransition = .immediate
                button = ButtonView(frame: frame)
                self.buttons[item.id] = button
                self.addSubview(button)
                if transition.isAnimated {
                    button.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            button.action = item.action
            button.update(content: item.content, size: buttonSize)
            itemTransition.updateFrame(view: button, frame: frame)
        }

        var removeIds: [AnyHashable] = []
        for (id, button) in self.buttons where !validIds.contains(id) {
            removeIds.append(id)
            if transition.isAnimated {
                button.layer.animateAlpha(from: button.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak button] _ in
                    button?.removeFromSuperview()
                })
            } else {
                button.removeFromSuperview()
            }
        }
        for id in removeIds {
            self.buttons.removeValue(forKey: id)
        }
    }
}
