import ComponentFlow
import Display
import Foundation
import AppBundle
import TelegramPresentationData
import UIKit

final class StoryViewingGateComponent: Component {
    let theme: PresentationTheme
    let strings: InterfaceTuningFeatureStrings
    let authorName: String?
    let proceed: () -> Void
    let close: () -> Void

    init(
        theme: PresentationTheme,
        strings: InterfaceTuningFeatureStrings,
        authorName: String?,
        proceed: @escaping () -> Void,
        close: @escaping () -> Void
    ) {
        self.theme = theme
        self.strings = strings
        self.authorName = authorName
        self.proceed = proceed
        self.close = close
    }

    static func ==(lhs: StoryViewingGateComponent, rhs: StoryViewingGateComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.strings.storyConfirmationTitle == rhs.strings.storyConfirmationTitle && lhs.authorName == rhs.authorName
    }

    final class View: UIView {
        private var component: StoryViewingGateComponent?
        private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        private let titleLabel = UILabel()
        private let descriptionLabel = UILabel()
        private let proceedButton = UIButton(type: .system)
        private let closeButton = UIButton(type: .system)

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.effectView)

            self.titleLabel.textAlignment = .center
            self.titleLabel.textColor = .white
            self.titleLabel.font = Font.semibold(20.0)
            self.titleLabel.numberOfLines = 0
            self.addSubview(self.titleLabel)

            self.descriptionLabel.textAlignment = .center
            self.descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.65)
            self.descriptionLabel.font = Font.regular(15.0)
            self.descriptionLabel.numberOfLines = 0
            self.addSubview(self.descriptionLabel)

            self.proceedButton.titleLabel?.font = Font.semibold(17.0)
            self.proceedButton.layer.cornerRadius = 12.0
            self.proceedButton.addTarget(self, action: #selector(self.proceedPressed), for: .touchUpInside)
            self.addSubview(self.proceedButton)

            self.closeButton.setImage(UIImage(bundleImageName: "Stories/Close"), for: .normal)
            self.closeButton.tintColor = .white
            self.closeButton.addTarget(self, action: #selector(self.closePressed), for: .touchUpInside)
            self.addSubview(self.closeButton)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func proceedPressed() {
            self.component?.proceed()
        }

        @objc private func closePressed() {
            self.component?.close()
        }

        func animateIn() {
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }

        func animateOut(completion: @escaping () -> Void) {
            self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                completion()
            })
        }

        func update(component: StoryViewingGateComponent, availableSize: CGSize) -> CGSize {
            self.component = component
            self.titleLabel.text = component.strings.storyConfirmationTitle
            if let authorName = component.authorName, !authorName.isEmpty {
                self.descriptionLabel.text = "\(authorName)\n\(component.strings.storyConfirmationText)"
            } else {
                self.descriptionLabel.text = component.strings.storyConfirmationText
            }
            self.proceedButton.setTitle(component.strings.storyConfirmationAction, for: .normal)
            self.proceedButton.setTitleColor(component.theme.list.itemCheckColors.foregroundColor, for: .normal)
            self.proceedButton.backgroundColor = component.theme.list.itemCheckColors.fillColor

            self.effectView.frame = CGRect(origin: .zero, size: availableSize)
            self.closeButton.frame = CGRect(x: availableSize.width - 60.0, y: 54.0, width: 50.0, height: 50.0)

            let sideInset: CGFloat = 44.0
            let contentWidth = max(1.0, availableSize.width - sideInset * 2.0)
            let titleSize = self.titleLabel.sizeThatFits(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
            let descriptionSize = self.descriptionLabel.sizeThatFits(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
            let buttonHeight: CGFloat = 50.0
            let totalHeight = titleSize.height + 12.0 + descriptionSize.height + 38.0 + buttonHeight
            var y = floor((availableSize.height - totalHeight) * 0.5)

            self.titleLabel.frame = CGRect(x: sideInset, y: y, width: contentWidth, height: titleSize.height)
            y += titleSize.height + 12.0
            self.descriptionLabel.frame = CGRect(x: sideInset, y: y, width: contentWidth, height: descriptionSize.height)
            y += descriptionSize.height + 38.0
            self.proceedButton.frame = CGRect(x: sideInset, y: y, width: contentWidth, height: buttonHeight)

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}
