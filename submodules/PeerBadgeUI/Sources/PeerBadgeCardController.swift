import Foundation
import UIKit
import AsyncDisplayKit
import AccountContext
import ComponentFlow
import Display
import EmojiStatusComponent
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences

func peerBadgeAccentColor(image: UIImage?) -> UIColor {
    guard let cgImage = image?.cgImage else {
        return UIColor(rgb: 0x9b6dff)
    }
    let side = 16
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    guard let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return UIColor(rgb: 0x9b6dff)
    }
    context.interpolationQuality = .medium
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var total: CGFloat = 0.0
    for index in 0 ..< side * side {
        let alpha = CGFloat(pixels[index * 4 + 3]) / 255.0
        if alpha < 0.5 {
            continue
        }
        let r = CGFloat(pixels[index * 4]) / 255.0 / alpha
        let g = CGFloat(pixels[index * 4 + 1]) / 255.0 / alpha
        let b = CGFloat(pixels[index * 4 + 2]) / 255.0 / alpha
        let maxValue = max(r, g, b)
        let minValue = min(r, g, b)
        let saturation = maxValue > 0.0 ? (maxValue - minValue) / maxValue : 0.0
        let weight = alpha * (0.15 + saturation)
        red += r * weight
        green += g * weight
        blue += b * weight
        total += weight
    }
    guard total > 0.0 else {
        return UIColor(rgb: 0xcfcfd8)
    }
    let average = UIColor(red: min(1.0, red / total), green: min(1.0, green / total), blue: min(1.0, blue / total), alpha: 1.0)
    var hue: CGFloat = 0.0
    var saturation: CGFloat = 0.0
    var value: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    guard average.getHue(&hue, saturation: &saturation, brightness: &value, alpha: &alpha), saturation >= 0.12 else {
        return UIColor(rgb: 0xcfcfd8)
    }
    return UIColor(hue: hue, saturation: max(saturation, 0.45), brightness: max(value, 0.85), alpha: 1.0)
}

private func badgeCardLinkUrl(_ value: String?) -> URL? {
    guard let value, let url = URL(string: value), let scheme = url.scheme?.lowercased() else {
        return nil
    }
    if scheme == "https" || scheme == "tg" {
        return url
    }
    return nil
}

private func isTelegramLink(_ url: URL) -> Bool {
    if url.scheme?.lowercased() == "tg" {
        return true
    }
    guard let host = url.host?.lowercased() else {
        return false
    }
    return ["t.me", "telegram.me", "telegram.dog"].contains(host) || host.hasSuffix(".t.me")
}

private final class PeerBadgeCardNode: ASDisplayNode {
    private let context: AccountContext
    private let badge: PeerBadge
    private let strings: PeerBadgeCardStrings
    var dismiss: (() -> Void)?

    private let dimView = UIView()
    private let tiltView = UIView()
    private let glowView = UIView()
    private let cardView = UIView()
    private let borderLayer = CAGradientLayer()
    private let borderMaskLayer = CAShapeLayer()
    private let innerGlowLayer = CAGradientLayer()
    private let glareLayer = CAGradientLayer()
    private let imageView = UIImageView()
    private var emojiView: ComponentView<Empty>?
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private var linkButton: UIButton?

    private var emojiFile: TelegramMediaFile?
    private var emojiDisposable: Disposable?
    private var accentColor = UIColor(rgb: 0x9b6dff)
    private var tilt = CGPoint()
    private var validLayout: CGSize?

    init(context: AccountContext, badge: PeerBadge, strings: PeerBadgeCardStrings) {
        self.context = context
        self.badge = badge
        self.strings = strings
        super.init()
    }

    deinit {
        self.emojiDisposable?.dispose()
    }

    override func didLoad() {
        super.didLoad()

        self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.55)
        self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapped)))
        self.view.addSubview(self.dimView)

        self.tiltView.layer.zPosition = 1000.0
        self.view.addSubview(self.tiltView)

        self.glowView.layer.shadowOpacity = 1.0
        self.glowView.layer.shadowRadius = 36.0
        self.glowView.layer.shadowOffset = CGSize()
        self.glowView.layer.cornerRadius = 24.0
        self.glowView.backgroundColor = UIColor(rgb: 0x141218)
        self.tiltView.addSubview(self.glowView)

        self.cardView.backgroundColor = UIColor(rgb: 0x141218)
        self.cardView.layer.cornerRadius = 24.0
        self.cardView.clipsToBounds = true
        self.tiltView.addSubview(self.cardView)

        self.innerGlowLayer.type = .radial
        self.cardView.layer.addSublayer(self.innerGlowLayer)

        self.imageView.contentMode = .scaleAspectFit
        self.cardView.addSubview(self.imageView)

        self.titleLabel.textColor = .white
        self.titleLabel.textAlignment = .center
        self.titleLabel.numberOfLines = 3
        self.titleLabel.text = self.badge.title
        self.cardView.addSubview(self.titleLabel)

        self.descriptionLabel.textColor = UIColor(rgb: 0xb9b3cf)
        self.descriptionLabel.font = UIFont.systemFont(ofSize: 15.0)
        self.descriptionLabel.textAlignment = .center
        self.descriptionLabel.numberOfLines = 8
        self.descriptionLabel.lineBreakMode = .byTruncatingTail
        self.descriptionLabel.text = self.badge.description
        self.cardView.addSubview(self.descriptionLabel)

        self.glareLayer.type = .radial
        self.glareLayer.colors = [UIColor(white: 1.0, alpha: 0.16).cgColor, UIColor(white: 1.0, alpha: 0.0).cgColor]
        self.glareLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.glareLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.glareLayer.opacity = 0.0
        self.cardView.layer.addSublayer(self.glareLayer)

        self.borderLayer.type = .conic
        self.borderLayer.colors = [0xff9fd6, 0xb69cff, 0x7fe0ff, 0xb4ffb0, 0xffe08a, 0xff9fd6].map { UIColor(rgb: UInt32($0)).cgColor }
        self.borderLayer.locations = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
        self.borderMaskLayer.fillColor = UIColor.clear.cgColor
        self.borderMaskLayer.strokeColor = UIColor.black.cgColor
        self.borderMaskLayer.lineWidth = 1.5
        self.borderLayer.mask = self.borderMaskLayer
        self.tiltView.layer.addSublayer(self.borderLayer)

        self.setupButton(self.closeButton, title: self.strings.close, action: #selector(self.closePressed))
        self.view.addSubview(self.closeButton)
        if let url = badgeCardLinkUrl(self.badge.linkUrl) {
            let linkButton = UIButton(type: .system)
            self.setupButton(linkButton, title: self.strings.openLink, action: #selector(self.linkPressed))
            self.linkButton = linkButton
            self.view.addSubview(linkButton)
            linkButton.accessibilityValue = url.absoluteString
        }

        let pan = UIPanGestureRecognizer(target: self, action: #selector(self.panned(_:)))
        self.tiltView.addGestureRecognizer(pan)

        self.loadArt()
        self.applyAccent()
    }

    private func setupButton(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.14)
        button.layer.cornerRadius = 14.0
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func loadArt() {
        switch self.badge.media {
        case .image:
            PeerBadgeRegistryStore.shared.loadImageData(for: self.badge, preferredSize: 128, completion: { [weak self] data in
                guard let self, let data, let image = UIImage(data: data) else {
                    return
                }
                self.imageView.image = image
                self.accentColor = peerBadgeAccentColor(image: image)
                self.applyAccent()
            })
        case let .customEmoji(documentId):
            self.emojiDisposable = (self.context.engine.stickers.resolveInlineStickers(fileIds: [documentId])
            |> deliverOnMainQueue).start(next: { [weak self] files in
                guard let self else {
                    return
                }
                self.emojiFile = files[documentId]
                if let size = self.validLayout {
                    self.layout(size: size)
                }
                Queue.mainQueue().after(0.6, { [weak self] in
                    self?.captureEmojiAccent()
                })
            })
        }
    }

    private func captureEmojiAccent() {
        guard let view = self.emojiView?.view, view.bounds.width > 0.0 else {
            return
        }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
        self.accentColor = peerBadgeAccentColor(image: image)
        self.applyAccent()
    }

    private func applyAccent() {
        let accent = self.accentColor
        self.glowView.layer.shadowColor = accent.withAlphaComponent(0.35).cgColor
        self.innerGlowLayer.colors = [accent.withAlphaComponent(0.42).cgColor, accent.withAlphaComponent(0.0).cgColor]
    }

    func animateIn() {
        self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.24)
        let timing = CAMediaTimingFunction(controlPoints: 0.33, 1.0, 0.68, 1.0)
        for view in [self.tiltView, self.closeButton] + (self.linkButton.flatMap { [$0] } ?? []) {
            view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.24)
        }
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.9
        animation.toValue = 1.0
        animation.duration = 0.24
        animation.timingFunction = timing
        self.tiltView.layer.add(animation, forKey: "appear")
    }

    func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.16, delay: 0.0, options: [.curveLinear], animations: {
            self.view.alpha = 0.0
        }, completion: { _ in
            completion()
        })
    }

    @objc private func dimTapped() {
        self.dismiss?()
    }

    @objc private func closePressed() {
        self.dismiss?()
    }

    @objc private func linkPressed() {
        guard let url = badgeCardLinkUrl(self.badge.linkUrl) else {
            return
        }
        let context = self.context
        self.dismiss?()
        if isTelegramLink(url) {
            var components = URLComponents()
            components.scheme = "mad"
            components.host = "open"
            components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
            if let wrapped = components.url {
                context.sharedContext.applicationBindings.openUrl(wrapped.absoluteString)
            }
        } else {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    @objc private func panned(_ recognizer: UIPanGestureRecognizer) {
        let size = self.tiltView.bounds.size
        guard size.width > 0.0, size.height > 0.0 else {
            return
        }
        switch recognizer.state {
        case .began, .changed:
            let location = recognizer.location(in: self.tiltView)
            self.tilt = CGPoint(x: max(-1.0, min(1.0, (location.x / size.width) * 2.0 - 1.0)), y: max(-1.0, min(1.0, (location.y / size.height) * 2.0 - 1.0)))
            self.setGlareVisible(true)
            self.applyTilt(animated: false)
        default:
            self.tilt = CGPoint()
            self.setGlareVisible(false)
            self.applyTilt(animated: true)
        }
    }

    private func applyTilt(animated: Bool) {
        let maxAngle: CGFloat = 9.0 * .pi / 180.0
        var transform = CATransform3DIdentity
        transform.m34 = -1.0 / 700.0
        transform = CATransform3DRotate(transform, self.tilt.x * maxAngle, 0.0, 1.0, 0.0)
        transform = CATransform3DRotate(transform, -self.tilt.y * maxAngle, 1.0, 0.0, 0.0)
        let updates = {
            self.tiltView.layer.transform = transform
        }
        if animated {
            UIView.animate(withDuration: 0.35, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [.allowUserInteraction], animations: updates)
        } else {
            updates()
        }
        self.updateGlare()
        self.updateBorderAngle()
    }

    private func setGlareVisible(_ visible: Bool) {
        let target: Float = visible ? 1.0 : 0.0
        if self.glareLayer.opacity == target {
            return
        }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = self.glareLayer.presentation()?.opacity ?? self.glareLayer.opacity
        animation.toValue = target
        animation.duration = visible ? 0.15 : 0.3
        self.glareLayer.opacity = target
        self.glareLayer.add(animation, forKey: "opacity")
    }

    private func updateGlare() {
        let bounds = self.cardView.bounds
        guard bounds.width > 0.0 else {
            return
        }
        let radius = bounds.width * 0.75
        let center = CGPoint(x: bounds.midX + self.tilt.x * bounds.width * 0.5, y: bounds.midY + self.tilt.y * bounds.height * 0.5)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.glareLayer.frame = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2.0, height: radius * 2.0)
        CATransaction.commit()
    }

    private func updateBorderAngle() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let angle = (210.0 - self.tilt.x * 60.0) * .pi / 180.0
        self.borderLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.borderLayer.endPoint = CGPoint(x: 0.5 + cos(angle) * 0.5, y: 0.5 - sin(angle) * 0.5)
        CATransaction.commit()
    }

    private func titleFont(width: CGFloat) -> (UIFont, Int) {
        let text = self.badge.title as NSString
        var size: CGFloat = 20.0
        while size >= 13.0 {
            let font = UIFont.systemFont(ofSize: size, weight: .bold)
            let measured = text.size(withAttributes: [.font: font]).width
            if measured <= width * 0.9 {
                return (font, 1)
            }
            size -= 1.0
        }
        return (UIFont.systemFont(ofSize: 13.0, weight: .bold), 3)
    }

    func layout(size: CGSize) {
        self.validLayout = size
        self.dimView.frame = CGRect(origin: CGPoint(), size: size)

        let cardWidth = min(300.0, size.width - 32.0)
        let sideInset: CGFloat = 22.0
        let textWidth = cardWidth - sideInset * 2.0
        let artSize: CGFloat = min(150.0, cardWidth - 60.0)
        let artArea: CGFloat = artSize + 40.0

        let (font, lines) = self.titleFont(width: textWidth)
        self.titleLabel.font = font
        self.titleLabel.numberOfLines = lines
        self.titleLabel.adjustsFontSizeToFitWidth = false
        let titleSize = self.titleLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        let descriptionSize = self.badge.description.isEmpty ? CGSize() : self.descriptionLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))

        var height: CGFloat = 22.0 + artArea + ceil(titleSize.height)
        if descriptionSize.height > 0.0 {
            height += 8.0 + ceil(descriptionSize.height)
        }
        height += 26.0

        let buttonHeight: CGFloat = 50.0
        let buttonsHeight = buttonHeight + (self.linkButton != nil ? buttonHeight + 10.0 : 0.0)
        let totalHeight = height + 22.0 + buttonsHeight
        let originY = max(20.0, floor((size.height - totalHeight) * 0.5))
        let cardFrame = CGRect(x: floor((size.width - cardWidth) * 0.5), y: originY, width: cardWidth, height: height)

        self.tiltView.bounds = CGRect(origin: CGPoint(), size: cardFrame.size)
        self.tiltView.center = CGPoint(x: cardFrame.midX, y: cardFrame.midY)
        let localBounds = CGRect(origin: CGPoint(), size: cardFrame.size)
        self.glowView.frame = localBounds
        self.cardView.frame = localBounds
        self.borderLayer.frame = localBounds
        self.borderMaskLayer.frame = localBounds
        self.borderMaskLayer.path = UIBezierPath(roundedRect: localBounds.insetBy(dx: 0.75, dy: 0.75), cornerRadius: 23.25).cgPath
        self.glowView.layer.shadowPath = UIBezierPath(roundedRect: localBounds, cornerRadius: 24.0).cgPath

        let artFrame = CGRect(x: floor((cardWidth - artSize) * 0.5), y: 22.0 + floor((artArea - artSize) * 0.5), width: artSize, height: artSize)
        self.imageView.frame = artFrame
        let glowRadius = cardWidth * 0.62
        self.innerGlowLayer.frame = CGRect(x: artFrame.midX - glowRadius, y: artFrame.midY - glowRadius, width: glowRadius * 2.0, height: glowRadius * 2.0)
        self.innerGlowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.innerGlowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)

        if case let .customEmoji(documentId) = self.badge.media {
            let emojiView: ComponentView<Empty>
            if let current = self.emojiView {
                emojiView = current
            } else {
                emojiView = ComponentView()
                self.emojiView = emojiView
            }
            let content: EmojiStatusComponent.AnimationContent = self.emojiFile.flatMap { .file(file: $0) } ?? .customEmoji(fileId: documentId)
            let emojiSize = emojiView.update(
                transition: .immediate,
                component: AnyComponent(EmojiStatusComponent(
                    context: self.context,
                    animationCache: self.context.animationCache,
                    animationRenderer: self.context.animationRenderer,
                    content: .animation(content: content, size: CGSize(width: artSize * 2.0, height: artSize * 2.0), placeholderColor: UIColor(white: 1.0, alpha: 0.1), themeColor: nil, loopMode: .forever),
                    size: CGSize(width: artSize, height: artSize),
                    isVisibleForAnimations: true,
                    useSharedAnimation: true,
                    action: nil
                )),
                environment: {},
                containerSize: CGSize(width: artSize, height: artSize)
            )
            if let view = emojiView.view {
                if view.superview == nil {
                    self.cardView.addSubview(view)
                }
                view.frame = CGRect(x: artFrame.midX - emojiSize.width * 0.5, y: artFrame.midY - emojiSize.height * 0.5, width: emojiSize.width, height: emojiSize.height)
            }
        }

        let titleFrame = CGRect(x: sideInset, y: 22.0 + artArea, width: textWidth, height: ceil(titleSize.height))
        self.titleLabel.frame = titleFrame
        self.descriptionLabel.frame = CGRect(x: sideInset, y: titleFrame.maxY + 8.0, width: textWidth, height: ceil(descriptionSize.height))

        var buttonY = cardFrame.maxY + 22.0
        if let linkButton = self.linkButton {
            linkButton.frame = CGRect(x: cardFrame.minX, y: buttonY, width: cardWidth, height: buttonHeight)
            buttonY += buttonHeight + 10.0
        }
        self.closeButton.frame = CGRect(x: cardFrame.minX, y: buttonY, width: cardWidth, height: buttonHeight)

        self.updateGlare()
        self.updateBorderAngle()
    }
}

struct PeerBadgeCardStrings {
    let close: String
    let openLink: String
}

public final class PeerBadgeCardController: ViewController {
    private let context: AccountContext
    private let badge: PeerBadge
    private let strings: PeerBadgeCardStrings
    private var animatedIn = false

    private var cardNode: PeerBadgeCardNode {
        return self.displayNode as! PeerBadgeCardNode
    }

    init(context: AccountContext, badge: PeerBadge, strings: PeerBadgeCardStrings) {
        self.context = context
        self.badge = badge
        self.strings = strings
        super.init(navigationBarPresentationData: nil)
        self.statusBar.statusBarStyle = .White
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let node = PeerBadgeCardNode(context: self.context, badge: self.badge, strings: self.strings)
        node.dismiss = { [weak self] in
            self?.dismissCard()
        }
        self.displayNode = node
        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.cardNode.layout(size: layout.size)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !self.animatedIn {
            self.animatedIn = true
            self.cardNode.animateIn()
        }
    }

    private func dismissCard() {
        self.cardNode.animateOut(completion: { [weak self] in
            self?.dismiss()
        })
    }
}
