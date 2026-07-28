import Foundation
import UIKit
import AccountContext
import ComponentFlow
import Display
import EmojiStatusComponent
import PresentationDataUtils
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences

public final class PeerBadgeComponent: Component {
    public typealias EnvironmentType = Empty

    public let context: AccountContext
    public let badge: PeerBadge
    public let size: CGSize
    public let isVisibleForAnimations: Bool
    public let action: (() -> Void)?

    public init(
        context: AccountContext,
        badge: PeerBadge,
        size: CGSize,
        isVisibleForAnimations: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.context = context
        self.badge = badge
        self.size = size
        self.isVisibleForAnimations = isVisibleForAnimations
        self.action = action
    }

    public static func ==(lhs: PeerBadgeComponent, rhs: PeerBadgeComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.badge != rhs.badge {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        if lhs.isVisibleForAnimations != rhs.isVisibleForAnimations {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }

    public final class View: UIControl {
        private let imageView: UIImageView
        private let placeholderView: UIView
        private var emojiView: ComponentView<Empty>?
        private var component: PeerBadgeComponent?
        private var requestedBadgeId: String?
        private var resolvedEmojiDocumentId: Int64?
        private var resolvedEmojiFile: TelegramMediaFile?
        private var emojiFileDisposable: Disposable?
        private var componentState: EmptyComponentState?

        override public init(frame: CGRect) {
            self.imageView = UIImageView()
            self.imageView.contentMode = .scaleAspectFit
            self.imageView.isUserInteractionEnabled = false

            self.placeholderView = UIView()
            self.placeholderView.isUserInteractionEnabled = false
            self.placeholderView.backgroundColor = UIColor(rgb: 0x8e99a8, alpha: 0.18)

            super.init(frame: frame)

            self.accessibilityTraits = [.button, .image]
            self.addSubview(self.placeholderView)
            self.addSubview(self.imageView)
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }

        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.emojiFileDisposable?.dispose()
        }

        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            if let action = component.action {
                action()
            } else {
                presentPeerBadgeInfo(context: component.context, badge: component.badge)
            }
        }

        func update(component: PeerBadgeComponent, state: EmptyComponentState, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
            self.accessibilityLabel = component.badge.title
            self.accessibilityHint = localizedPeerBadgeStrings(
                languageCode: component.context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
            ).detailsHint

            transition.setFrame(view: self.placeholderView, frame: CGRect(origin: .zero, size: component.size))
            self.placeholderView.layer.cornerRadius = component.size.width * 0.3

            switch component.badge.media {
            case .image:
                if let emojiView = self.emojiView {
                    self.emojiView = nil
                    emojiView.view?.removeFromSuperview()
                }
                transition.setFrame(view: self.imageView, frame: CGRect(origin: .zero, size: component.size))
                self.imageView.isHidden = false
                if self.requestedBadgeId != component.badge.id {
                    self.requestedBadgeId = component.badge.id
                    self.imageView.image = nil
                    self.placeholderView.isHidden = false
                    PeerBadgeRegistryStore.shared.loadImageData(
                        for: component.badge,
                        preferredSize: component.size.width > 22.0 ? 128 : 64,
                        completion: { [weak self] data in
                            guard
                                let self,
                                self.requestedBadgeId == component.badge.id,
                                let data,
                                let image = UIImage(data: data)
                            else {
                                return
                            }
                            self.imageView.image = image
                            self.placeholderView.isHidden = true
                            self.imageView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
                        }
                    )
                } else if self.imageView.image != nil {
                    self.placeholderView.isHidden = true
                }
            case let .customEmoji(documentId):
                self.requestedBadgeId = component.badge.id
                self.imageView.isHidden = true
                self.placeholderView.isHidden = self.resolvedEmojiFile != nil

                if self.resolvedEmojiDocumentId != documentId {
                    self.resolvedEmojiDocumentId = documentId
                    self.resolvedEmojiFile = nil
                    self.emojiFileDisposable?.dispose()
                    self.emojiFileDisposable = (component.context.engine.stickers.resolveInlineStickers(fileIds: [documentId])
                    |> deliverOnMainQueue).start(next: { [weak self] files in
                        guard let self, self.resolvedEmojiDocumentId == documentId else {
                            return
                        }
                        self.resolvedEmojiFile = files[documentId]
                        self.placeholderView.isHidden = self.resolvedEmojiFile != nil
                        self.componentState?.updated(transition: .immediate)
                    })
                }

                let emojiView: ComponentView<Empty>
                if let current = self.emojiView {
                    emojiView = current
                } else {
                    emojiView = ComponentView()
                    self.emojiView = emojiView
                }
                let animationContent: EmojiStatusComponent.AnimationContent
                if let resolvedEmojiFile = self.resolvedEmojiFile {
                    animationContent = .file(file: resolvedEmojiFile)
                } else {
                    animationContent = .customEmoji(fileId: documentId)
                }
                let emojiSize = emojiView.update(
                    transition: transition,
                    component: AnyComponent(EmojiStatusComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        content: .animation(
                            content: animationContent,
                            size: CGSize(width: 80.0, height: 80.0),
                            placeholderColor: UIColor(rgb: 0x8e99a8, alpha: 0.2),
                            themeColor: nil,
                            loopMode: .forever
                        ),
                        size: component.size,
                        isVisibleForAnimations: component.isVisibleForAnimations,
                        useSharedAnimation: true,
                        action: { [weak self] in
                            self?.pressed()
                        }
                    )),
                    environment: {},
                    containerSize: component.size
                )
                if let emojiViewValue = emojiView.view {
                    if emojiViewValue.superview == nil {
                        self.addSubview(emojiViewValue)
                    }
                    transition.setFrame(
                        view: emojiViewValue,
                        frame: CGRect(
                            origin: CGPoint(
                                x: floor((component.size.width - emojiSize.width) * 0.5),
                                y: floor((component.size.height - emojiSize.height) * 0.5)
                            ),
                            size: emojiSize
                        )
                    )
                }
            }
            return component.size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, state: state, transition: transition)
    }
}

private struct PeerBadgeStrings {
    let close: String
    let openLink: String
    let confirmTitle: String
    let confirmText: String
    let detailsHint: String
}

private func localizedPeerBadgeStrings(languageCode: String) -> PeerBadgeStrings {
    if languageCode.hasPrefix("ru") {
        return PeerBadgeStrings(
            close: "Закрыть",
            openLink: "Открыть ссылку",
            confirmTitle: "Открыть внешнюю ссылку?",
            confirmText: "Telegram передаст управление браузеру.",
            detailsHint: "Показать описание бейджа"
        )
    } else if languageCode.hasPrefix("uk") {
        return PeerBadgeStrings(
            close: "Закрити",
            openLink: "Відкрити посилання",
            confirmTitle: "Відкрити зовнішнє посилання?",
            confirmText: "Telegram передасть керування браузеру.",
            detailsHint: "Показати опис бейджа"
        )
    } else {
        return PeerBadgeStrings(
            close: "Close",
            openLink: "Open Link",
            confirmTitle: "Open external link?",
            confirmText: "Telegram will hand over to your browser.",
            detailsHint: "Show badge details"
        )
    }
}

public func presentPeerBadgeInfo(context: AccountContext, badge: PeerBadge) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = localizedPeerBadgeStrings(languageCode: presentationData.strings.baseLanguageCode)
    var actions: [TextAlertAction] = [
        TextAlertAction(type: .defaultAction, title: strings.close, action: {})
    ]
    if let linkUrl = badge.linkUrl, let url = URL(string: linkUrl), url.scheme == "https" {
        actions.append(TextAlertAction(type: .genericAction, title: strings.openLink, action: {
            let confirmation = textAlertController(
                context: context,
                title: strings.confirmTitle,
                text: strings.confirmText,
                actions: [
                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}),
                    TextAlertAction(type: .genericAction, title: strings.openLink, action: {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    })
                ]
            )
            context.sharedContext.mainWindow?.present(confirmation, on: .root)
        }))
    }
    let controller = textAlertController(
        context: context,
        title: badge.title,
        text: badge.description,
        actions: actions,
        actionLayout: .vertical
    )
    context.sharedContext.mainWindow?.present(controller, on: .root)
}
