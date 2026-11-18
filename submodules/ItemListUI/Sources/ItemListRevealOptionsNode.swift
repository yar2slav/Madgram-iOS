import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ManagedAnimationNode

public enum ItemListRevealOptionIcon: Equatable {
    case none
    case image(image: UIImage)
    case animation(animation: String, scale: CGFloat, offset: CGFloat, replaceColors: [UInt32]?, flip: Bool, startFrame: Int = 0)

    public static func ==(lhs: ItemListRevealOptionIcon, rhs: ItemListRevealOptionIcon) -> Bool {
        switch lhs {
        case .none:
            if case .none = rhs {
                return true
            } else {
                return false
            }
        case let .image(lhsImage):
            if case let .image(rhsImage) = rhs, lhsImage == rhsImage {
                return true
            } else {
                return false
            }
        case let .animation(lhsAnimation, lhsScale, lhsOffset, lhsKeysToColor, lhsFlip, lhsStartFrame):
            if case let .animation(rhsAnimation, rhsScale, rhsOffset, rhsKeysToColor, rhsFlip, rhsStartFrame) = rhs, lhsAnimation == rhsAnimation, lhsScale == rhsScale, lhsOffset == rhsOffset, lhsKeysToColor == rhsKeysToColor, lhsFlip == rhsFlip, lhsStartFrame == rhsStartFrame {
                return true
            } else {
                return false
            }
        }
    }
}

public struct ItemListRevealOption: Equatable {
    public let key: Int32
    public let title: String
    public let icon: ItemListRevealOptionIcon
    public let color: UIColor
    public let iconColor: UIColor
    public let textColor: UIColor
    public let isDestructive: Bool

    public init(key: Int32, title: String, icon: ItemListRevealOptionIcon, color: UIColor, iconColor: UIColor, textColor: UIColor, isDestructive: Bool = false) {
        self.key = key
        self.title = title
        self.icon = icon
        self.color = color
        self.iconColor = iconColor
        self.textColor = textColor
        self.isDestructive = isDestructive
    }

    public static func ==(lhs: ItemListRevealOption, rhs: ItemListRevealOption) -> Bool {
        if lhs.isDestructive != rhs.isDestructive {
            return false
        }
        if lhs.key != rhs.key {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if !lhs.iconColor.isEqual(rhs.iconColor) {
            return false
        }
        if !lhs.textColor.isEqual(rhs.textColor) {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        return true
    }
}

private let titleFont = Font.regular(11.0)
private let iconlessTitleFont = Font.regular(13.0)

private let spacing: CGFloat = 10.0
private let edgeInset: CGFloat = 10.0
private let titleSpacing: CGFloat = 4.0
private let expandedActivationWidthFactor: CGFloat = 3.0
private let expandedTransitionDistance: CGFloat = 16.0
private let iconlessTitleExpandedHorizontalPadding: CGFloat = 8.0
private let iconlessTitleHorizontalPadding: CGFloat = 8.0
private let iconAnimationResponse: CGFloat = 18.0
private let iconAnimationSnapDistance: CGFloat = 0.5
private let animationTriggerProgress: CGFloat = 0.1
private let interactiveAnimationResetProgress: CGFloat = 0.01

public struct ItemListRevealOptionsAnimationSettings: Equatable {
    public var revealStartOverlap: CGFloat
    public var revealEndDistance: CGFloat
    public var revealProgressResponse: CGFloat
    public var minimumContentScale: CGFloat
    public var visualRevealSpring: CGFloat
    public var visualRevealDamping: CGFloat
    public var visualRevealSnapDistance: CGFloat
    public var visualRevealSnapVelocity: CGFloat

    public static let defaultSettings = ItemListRevealOptionsAnimationSettings(
        revealStartOverlap: 10.0,
        revealEndDistance: 10.0,
        revealProgressResponse: 2.7,
        minimumContentScale: 0.3,
        visualRevealSpring: 420.0,
        visualRevealDamping: 40.0,
        visualRevealSnapDistance: 0.25,
        visualRevealSnapVelocity: 12.0
    )

    public init(
        revealStartOverlap: CGFloat,
        revealEndDistance: CGFloat,
        revealProgressResponse: CGFloat,
        minimumContentScale: CGFloat,
        visualRevealSpring: CGFloat,
        visualRevealDamping: CGFloat,
        visualRevealSnapDistance: CGFloat,
        visualRevealSnapVelocity: CGFloat
    ) {
        self.revealStartOverlap = revealStartOverlap
        self.revealEndDistance = revealEndDistance
        self.revealProgressResponse = revealProgressResponse
        self.minimumContentScale = minimumContentScale
        self.visualRevealSpring = visualRevealSpring
        self.visualRevealDamping = visualRevealDamping
        self.visualRevealSnapDistance = visualRevealSnapDistance
        self.visualRevealSnapVelocity = visualRevealSnapVelocity
    }
}

public enum ItemListRevealOptionsAnimationSettingsStore {
    private static var settings: ItemListRevealOptionsAnimationSettings = .defaultSettings

    public static var current: ItemListRevealOptionsAnimationSettings {
        get {
            assert(Thread.isMainThread)
            return self.settings
        }
        set {
            assert(Thread.isMainThread)
            self.settings = newValue
        }
    }

    public static func resetToDefaults() {
        self.current = .defaultSettings
    }
}

private extension ItemListRevealOptionIcon {
    var hasVisualIcon: Bool {
        switch self {
        case .none:
            return false
        case .image, .animation:
            return true
        }
    }
}

private struct ItemListRevealOptionLayoutMetrics {
    let shapeSize: CGSize
    let slotWidth: CGFloat
    let titleWidth: CGFloat
    let iconMaxSide: CGFloat
    let cornerRadius: CGFloat
    let expandedIconInset: CGFloat

    var contentHeight: CGFloat {
        return self.shapeSize.height + titleSpacing + ceil(titleFont.lineHeight)
    }

    var slotShapeInset: CGFloat {
        return floorToScreenPixels((self.slotWidth - self.shapeSize.width) / 2.0)
    }

    static func metrics(for height: CGFloat, hasVisualIcons: Bool) -> ItemListRevealOptionLayoutMetrics {
        let regularShapeSize = CGSize(width: 50.0, height: 50.0)
        let compactShapeSize = CGSize(width: 60.0, height: 32.0)
        let regularContentHeight = regularShapeSize.height + titleSpacing + ceil(titleFont.lineHeight)
        if height < regularContentHeight || !hasVisualIcons {
            return ItemListRevealOptionLayoutMetrics(shapeSize: compactShapeSize, slotWidth: 70.0, titleWidth: 70.0, iconMaxSide: 24.0, cornerRadius: 16.0, expandedIconInset: 16.0)
        } else {
            return ItemListRevealOptionLayoutMetrics(shapeSize: regularShapeSize, slotWidth: 60.0, titleWidth: 60.0, iconMaxSide: 40.0, cornerRadius: 25.0, expandedIconInset: 20.0)
        }
    }

    func withGroupTitleWidth(_ maxTitleWidth: CGFloat) -> ItemListRevealOptionLayoutMetrics {
        if maxTitleWidth <= self.shapeSize.width - iconlessTitleExpandedHorizontalPadding {
            return self
        }

        let updatedShapeWidth = ceil(maxTitleWidth + iconlessTitleExpandedHorizontalPadding)
        let slotWidthDelta = self.slotWidth - self.shapeSize.width
        return ItemListRevealOptionLayoutMetrics(
            shapeSize: CGSize(width: updatedShapeWidth, height: self.shapeSize.height),
            slotWidth: updatedShapeWidth + slotWidthDelta,
            titleWidth: max(self.titleWidth, updatedShapeWidth - iconlessTitleExpandedHorizontalPadding),
            iconMaxSide: self.iconMaxSide,
            cornerRadius: self.cornerRadius,
            expandedIconInset: self.expandedIconInset
        )
    }

    func revealWidth(count: Int) -> CGFloat {
        if count == 0 {
            return 0.0
        }
        return edgeInset * 2.0 + self.shapeSize.width * CGFloat(count) + spacing * CGFloat(count - 1)
    }
}

private func clampToUnitInterval(_ value: CGFloat) -> CGFloat {
    return max(0.0, min(1.0, value))
}

private func frameCenter(_ frame: CGRect) -> CGPoint {
    return CGPoint(x: frame.midX, y: frame.midY)
}

private func revealProgressCurve(_ value: CGFloat, response: CGFloat) -> CGFloat {
    let value = clampToUnitInterval(value)
    return 1.0 - pow(1.0 - value, max(0.01, response))
}

private final class ItemListRevealOptionNode: ASDisplayNode {
    private let contentContainerNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let highlightNode: ASDisplayNode
    private let titleNode: ImmediateTextNode
    private let iconNode: ASImageNode?
    private let animationNode: SimpleAnimationNode?

    private let enableAnimations: Bool
    private let displaysTitleInsidePill: Bool

    private var animationScale: CGFloat = 1.0
    private var animationNodeOffset: CGFloat = 0.0
    private var animationNodeFlip = false
    private var isAnimationTriggered = false
    private var actionIsHighlighted = false

    private var contentAnimationLink: SharedDisplayLinkDriver.Link?
    private weak var manuallyAnimatedContentNode: ASDisplayNode?
    private var currentContentCenter: CGPoint?
    private var targetContentCenter: CGPoint?

    private var didApplyLayout = false
    var isExpanded: Bool = false

    var hasAppliedLayout: Bool {
        return self.didApplyLayout
    }

    var titleWidthForGroupPillSizing: CGFloat {
        var titleWidth = self.titleNode.updateLayout(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width
        if self.displaysTitleInsidePill {
            titleWidth += iconlessTitleHorizontalPadding
        }
        return titleWidth
    }

    init(title: String, icon: ItemListRevealOptionIcon, color: UIColor, iconColor: UIColor, textColor: UIColor, enableAnimations: Bool) {
        self.contentContainerNode = ASDisplayNode()
        self.backgroundNode = ASDisplayNode()
        self.highlightNode = ASDisplayNode()

        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.textAlignment = .center

        let displaysTitleInsidePill: Bool
        if case .none = icon {
            displaysTitleInsidePill = true
        } else {
            displaysTitleInsidePill = false
        }
        self.displaysTitleInsidePill = displaysTitleInsidePill
        self.titleNode.attributedText = NSAttributedString(string: title, font: displaysTitleInsidePill ? iconlessTitleFont : titleFont, textColor: displaysTitleInsidePill ? iconColor : textColor)

        self.enableAnimations = enableAnimations

        switch icon {
        case let .image(image):
            let iconNode = ASImageNode()
            iconNode.image = generateTintedImage(image: image, color: iconColor)
            self.iconNode = iconNode
            self.animationNode = nil

        case let .animation(animation, scale, offset, replaceColors, flip, startFrame):
            self.animationScale = scale
            self.iconNode = nil
            var colors: [UInt32: UInt32] = [:]
            if let replaceColors = replaceColors {
                for colorToReplace in replaceColors {
                    colors[colorToReplace] = color.rgb
                }
            }
            self.animationNode = SimpleAnimationNode(animationName: animation, replaceColors: colors, size: CGSize(width: 66.0, height: 66.0), playOnce: true, startFrame: startFrame)
            if !enableAnimations {
                self.animationNode!.seekToEnd(immediately: true)
            }
            if flip {
                self.animationNode!.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
            }
            self.animationNodeOffset = offset
            self.animationNodeFlip = flip
            break

        case .none:
            self.iconNode = nil
            self.animationNode = nil
        }

        super.init()

        self.contentContainerNode.layer.allowsGroupOpacity = true
        self.addSubnode(self.contentContainerNode)
        self.contentContainerNode.addSubnode(self.backgroundNode)
        self.contentContainerNode.addSubnode(self.titleNode)
        if let iconNode = self.iconNode {
            self.contentContainerNode.addSubnode(iconNode)
        } else if let animationNode = self.animationNode {
            self.contentContainerNode.addSubnode(animationNode)
        }
        self.backgroundNode.backgroundColor = color
        self.highlightNode.backgroundColor = color.withMultipliedBrightnessBy(0.9)
    }

    deinit {
        self.stopManualContentAnimation()
    }

    func setHighlighted(_ highlighted: Bool) {
        guard self.actionIsHighlighted != highlighted else { return }
        self.actionIsHighlighted = highlighted
        if highlighted && self.highlightNode.supernode == nil {
            self.contentContainerNode.insertSubnode(self.highlightNode, aboveSubnode: self.backgroundNode)
        }
        let previousAlpha = self.highlightNode.layer.presentation()?.opacity ?? Float(self.highlightNode.alpha)
        self.highlightNode.layer.removeAnimation(forKey: "opacity")
        self.highlightNode.alpha = highlighted ? 1.0 : 0.0
        if !UIAccessibility.isReduceMotionEnabled {
            self.highlightNode.layer.animateAlpha(from: CGFloat(previousAlpha), to: self.highlightNode.alpha, duration: highlighted ? 0.08 : 0.18)
        }
    }

    func containsActionPoint(_ point: CGPoint, from view: UIView) -> Bool {
        guard self.contentContainerNode.alpha > 0.1, abs(self.contentContainerNode.transform.m11) > 0.3 else {
            return false
        }
        return self.contentContainerNode.bounds.contains(self.contentContainerNode.view.convert(point, from: view))
    }

    func resetAnimation() {
        self.setAnimationTriggered(false)
        self.stopManualContentAnimation()
    }

    private func setAnimationTriggered(_ isTriggered: Bool) {
        guard self.enableAnimations, self.isAnimationTriggered != isTriggered else {
            return
        }
        self.isAnimationTriggered = isTriggered
        if isTriggered {
            self.animationNode?.play(immediately: true)
        } else {
            self.animationNode?.reset(immediately: true)
        }
    }

    private func currentContentPresentationCenter(contentNode: ASDisplayNode) -> CGPoint {
        return contentNode.layer.presentation()?.position ?? contentNode.position
    }

    private func isManualContentAnimationAtTarget(center: CGPoint) -> Bool {
        guard let targetContentCenter = self.targetContentCenter else {
            return true
        }
        let centerDeltaX = targetContentCenter.x - center.x
        let centerDeltaY = targetContentCenter.y - center.y
        let centerDistance = sqrt(centerDeltaX * centerDeltaX + centerDeltaY * centerDeltaY)
        return centerDistance <= iconAnimationSnapDistance
    }

    private func stopManualContentAnimation() {
        self.contentAnimationLink?.isPaused = true
        self.contentAnimationLink?.invalidate()
        self.contentAnimationLink = nil
        self.manuallyAnimatedContentNode = nil
        self.currentContentCenter = nil
        self.targetContentCenter = nil
    }

    private func updateManualContentCenter(contentNode: ASDisplayNode, targetCenter: CGPoint, forceImmediate: Bool) {
        contentNode.layer.removeAnimation(forKey: "position")

        if self.manuallyAnimatedContentNode !== contentNode || self.currentContentCenter == nil {
            self.currentContentCenter = self.currentContentPresentationCenter(contentNode: contentNode)
            self.manuallyAnimatedContentNode = contentNode
        }

        self.targetContentCenter = targetCenter

        if forceImmediate {
            contentNode.position = targetCenter
            self.stopManualContentAnimation()
            return
        }

        if let currentContentCenter = self.currentContentCenter, self.isManualContentAnimationAtTarget(center: currentContentCenter) {
            contentNode.position = targetCenter
            self.stopManualContentAnimation()
            return
        }

        if self.contentAnimationLink == nil {
            self.contentAnimationLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] deltaTime in
                self?.tickManualContentAnimation(deltaTime: deltaTime)
            })
            self.contentAnimationLink?.isPaused = false
        }
    }

    private func tickManualContentAnimation(deltaTime: CGFloat) {
        guard let contentNode = self.manuallyAnimatedContentNode, let currentContentCenter = self.currentContentCenter, let targetContentCenter = self.targetContentCenter else {
            self.stopManualContentAnimation()
            return
        }

        let clampedDeltaTime = min(0.05, max(0.0, deltaTime))
        let progress = 1.0 - exp(-clampedDeltaTime * iconAnimationResponse)
        let updatedCenter = CGPoint(
            x: currentContentCenter.x + (targetContentCenter.x - currentContentCenter.x) * progress,
            y: currentContentCenter.y + (targetContentCenter.y - currentContentCenter.y) * progress
        )

        if self.isManualContentAnimationAtTarget(center: updatedCenter) {
            contentNode.position = targetContentCenter
            self.stopManualContentAnimation()
        } else {
            self.currentContentCenter = updatedCenter
            contentNode.position = updatedCenter
        }
    }

    func updateLayout(
        isLeft: Bool,
        isPrimary: Bool,
        metrics: ItemListRevealOptionLayoutMetrics,
        revealProgress: CGFloat,
        overswipeProgress: CGFloat,
        expandedProgress: CGFloat,
        isStretched: Bool,
        isExpanded: Bool,
        transition: ContainedViewLayoutTransition,
        motionScale: CGFloat? = nil,
        motionOpacity: CGFloat? = nil
    ) {
        let didApplyLayout = self.didApplyLayout
        let bounds = CGRect(origin: CGPoint(), size: self.bounds.size)
        transition.updateFrame(node: self.contentContainerNode, frame: bounds)

        let titleSize: CGSize
        if self.titleNode.frame.isEmpty {
            titleSize = self.titleNode.updateLayout(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        } else {
            titleSize = self.titleNode.cachedLayout?.size ?? CGSize()
        }

        let pillSize = metrics.shapeSize
        let shapeY: CGFloat
        if self.displaysTitleInsidePill {
            shapeY = floorToScreenPixels((bounds.height - pillSize.height) / 2.0)
        } else {
            let contentHeight = pillSize.height + titleSpacing + titleSize.height
            shapeY = floorToScreenPixels((bounds.height - contentHeight) / 2.0)
        }

        let shapeFrameX: CGFloat
        if isStretched {
            shapeFrameX = isLeft ? 0.0 : bounds.width - pillSize.width
        } else {
            shapeFrameX = floorToScreenPixels((metrics.slotWidth - pillSize.width) / 2.0)
        }
        let shapeFrame = CGRect(origin: CGPoint(x: shapeFrameX, y: shapeY), size: pillSize)
        let backgroundFrame: CGRect
        if isStretched {
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: shapeY), size: CGSize(width: bounds.width, height: pillSize.height))
        } else {
            backgroundFrame = shapeFrame
        }

        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.highlightNode, frame: backgroundFrame)
        transition.updateCornerRadius(node: self.backgroundNode, cornerRadius: metrics.cornerRadius)
        transition.updateCornerRadius(node: self.highlightNode, cornerRadius: metrics.cornerRadius)

        let wasExpanded = self.isExpanded
        self.isExpanded = isExpanded
        self.didApplyLayout = true
        let contentAlpha: CGFloat
        if isPrimary {
            contentAlpha = revealProgress
        } else {
            contentAlpha = revealProgress * (1.0 - 0.3 * overswipeProgress)
        }
        let animationSettings = ItemListRevealOptionsAnimationSettingsStore.current
        let minimumContentScale = clampToUnitInterval(animationSettings.minimumContentScale)
        let contentScale = motionScale.map { max(0.0001, $0) } ?? (minimumContentScale + (1.0 - minimumContentScale) * revealProgress)
        let contentOpacity = motionOpacity.map { clampToUnitInterval($0) } ?? contentAlpha
        transition.updateAlpha(node: self.contentContainerNode, alpha: contentOpacity)
        transition.updateTransform(node: self.contentContainerNode, transform: CGAffineTransform(scaleX: contentScale, y: contentScale))

        var didApplyManualContentCenter = false

        let centeredIconCenterX = isPrimary ? backgroundFrame.midX : shapeFrame.midX
        let iconCenterX: CGFloat
        if isPrimary && expandedProgress > 0.0 {
            let expandedIconInset = motionScale != nil ? metrics.cornerRadius : metrics.expandedIconInset
            let expandedIconCenterX: CGFloat
            if isLeft {
                expandedIconCenterX = backgroundFrame.maxX - expandedIconInset
            } else {
                expandedIconCenterX = backgroundFrame.minX + expandedIconInset
            }
            iconCenterX = centeredIconCenterX + (expandedIconCenterX - centeredIconCenterX) * expandedProgress
        } else {
            iconCenterX = centeredIconCenterX
        }
        let iconCenterY = backgroundFrame.midY

        if let animationNode = self.animationNode {
            var imageSize = CGSize(width: animationNode.size.width * self.animationScale, height: animationNode.size.height * self.animationScale)
            let imageMaxSide = max(imageSize.width, imageSize.height)
            if imageMaxSide > metrics.iconMaxSide {
                let imageScale = metrics.iconMaxSide / imageMaxSide * 1.5
                imageSize = CGSize(width: floorToScreenPixels(imageSize.width * imageScale), height: floorToScreenPixels(imageSize.height * imageScale))
            }
            let scaleFraction = imageSize.height / 56.0
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(iconCenterX - imageSize.width / 2.0), y: floorToScreenPixels(iconCenterY - imageSize.height / 2.0) + (6.0 + self.animationNodeOffset) * scaleFraction), size: imageSize)

            if isPrimary {
                didApplyManualContentCenter = true
                transition.updateBounds(node: animationNode, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
                let targetCenter = frameCenter(iconFrame)
                if motionScale == nil && didApplyLayout && wasExpanded != isExpanded && revealProgress >= CGFloat.ulpOfOne {
                    self.updateManualContentCenter(contentNode: animationNode, targetCenter: targetCenter, forceImmediate: false)
                } else if motionScale == nil && self.manuallyAnimatedContentNode === animationNode && self.contentAnimationLink != nil && revealProgress >= CGFloat.ulpOfOne {
                    self.updateManualContentCenter(contentNode: animationNode, targetCenter: targetCenter, forceImmediate: false)
                } else {
                    self.stopManualContentAnimation()
                    transition.updatePosition(node: animationNode, position: targetCenter)
                }
            } else {
                transition.updateFrame(node: animationNode, frame: iconFrame)
            }
            if self.enableAnimations {
                if min(contentScale, contentOpacity) >= animationTriggerProgress {
                    self.setAnimationTriggered(true)
                } else if !transition.isAnimated && revealProgress <= interactiveAnimationResetProgress {
                    self.setAnimationTriggered(false)
                }
            }
        } else if let iconNode = self.iconNode, let imageSize = iconNode.image?.size {
            var fittedSize = imageSize
            let imageMaxSide = max(fittedSize.width, fittedSize.height)
            if imageMaxSide > metrics.iconMaxSide {
                let imageScale = metrics.iconMaxSide / imageMaxSide
                fittedSize = CGSize(width: floorToScreenPixels(fittedSize.width * imageScale), height: floorToScreenPixels(fittedSize.height * imageScale))
            }
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(iconCenterX - fittedSize.width / 2.0), y: floorToScreenPixels(iconCenterY - fittedSize.height / 2.0)), size: fittedSize)
            if isPrimary {
                didApplyManualContentCenter = true
                transition.updateBounds(node: iconNode, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
                let targetCenter = frameCenter(iconFrame)
                if motionScale == nil && didApplyLayout && wasExpanded != isExpanded && revealProgress >= CGFloat.ulpOfOne {
                    self.updateManualContentCenter(contentNode: iconNode, targetCenter: targetCenter, forceImmediate: false)
                } else if motionScale == nil && self.manuallyAnimatedContentNode === iconNode && self.contentAnimationLink != nil && revealProgress >= CGFloat.ulpOfOne {
                    self.updateManualContentCenter(contentNode: iconNode, targetCenter: targetCenter, forceImmediate: false)
                } else {
                    self.stopManualContentAnimation()
                    transition.updatePosition(node: iconNode, position: targetCenter)
                }
            } else {
                transition.updateFrame(node: iconNode, frame: iconFrame)
            }
        }
        let titleAlpha: CGFloat = isPrimary && !self.displaysTitleInsidePill ? 1.0 - expandedProgress : 1.0
        transition.updateAlpha(node: self.titleNode, alpha: titleAlpha)

        let titleFrame: CGRect
        if self.displaysTitleInsidePill {
            titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - titleSize.width / 2.0), y: floorToScreenPixels(backgroundFrame.midY - titleSize.height / 2.0)), size: titleSize)
            if isPrimary {
                didApplyManualContentCenter = true
                transition.updateBounds(node: self.titleNode, bounds: CGRect(origin: CGPoint(), size: titleFrame.size))
                let titleCenterX: CGFloat
                if expandedProgress > 0.0 {
                    let titleEdgeInset = max(metrics.expandedIconInset, titleSize.width / 2.0 + iconlessTitleExpandedHorizontalPadding)
                    let expandedTitleCenterX: CGFloat
                    if isLeft {
                        expandedTitleCenterX = backgroundFrame.maxX - titleEdgeInset
                    } else {
                        expandedTitleCenterX = backgroundFrame.minX + titleEdgeInset
                    }
                    titleCenterX = backgroundFrame.midX + (expandedTitleCenterX - backgroundFrame.midX) * expandedProgress
                } else {
                    titleCenterX = backgroundFrame.midX
                }
                let targetCenter = CGPoint(x: titleCenterX, y: backgroundFrame.midY)
                if motionScale == nil && didApplyLayout && wasExpanded != isExpanded && revealProgress >= CGFloat.ulpOfOne {
                    self.updateManualContentCenter(contentNode: self.titleNode, targetCenter: targetCenter, forceImmediate: false)
                } else if motionScale == nil && self.manuallyAnimatedContentNode === self.titleNode && self.contentAnimationLink != nil && revealProgress >= CGFloat.ulpOfOne {
                    self.updateManualContentCenter(contentNode: self.titleNode, targetCenter: targetCenter, forceImmediate: false)
                } else {
                    self.stopManualContentAnimation()
                    transition.updatePosition(node: self.titleNode, position: targetCenter)
                }
            } else {
                transition.updateFrame(node: self.titleNode, frame: titleFrame)
            }
        } else {
            let titleCenterX = iconCenterX
            titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(titleCenterX - titleSize.width / 2.0), y: shapeFrame.maxY + titleSpacing), size: titleSize)
            transition.updateFrame(node: self.titleNode, frame: titleFrame)
        }

        if !didApplyManualContentCenter {
            self.stopManualContentAnimation()
        }
    }

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let metrics = ItemListRevealOptionLayoutMetrics.metrics(for: constrainedSize.height, hasVisualIcons: !self.displaysTitleInsidePill)
        return CGSize(width: metrics.slotWidth, height: constrainedSize.height)
    }
}

/// Madgram classic design (`ClassicDesign.isEnabled`): one of 12.0's swipe actions (`ItemListRevealOptionNode` at
/// release-12.0): a full-height rectangle of the option's color with its icon above a 13 pt title (a 17 pt title
/// without an icon), both in the option's foreground color. The first one (the outermost) extends far past the edge,
/// so the row never shows through while it stretches.
private final class ClassicItemListRevealOptionNode: ASDisplayNode {
    enum Alignment {
        case left
        case right
    }
    
    private let backgroundNode: ASDisplayNode
    private let highlightNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let iconNode: ASImageNode?
    private let animationNode: SimpleAnimationNode?
    
    private let enableAnimations: Bool
    
    private var animationScale: CGFloat = 1.0
    private var animationNodeOffset: CGFloat = 0.0
    var alignment: Alignment?
    var isExpanded: Bool = false
    
    init(title: String, icon: ItemListRevealOptionIcon, color: UIColor, textColor: UIColor, enableAnimations: Bool) {
        self.backgroundNode = ASDisplayNode()
        self.highlightNode = ASDisplayNode()
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: icon == .none ? Font.regular(17.0) : Font.medium(13.0), textColor: textColor)
        
        self.enableAnimations = enableAnimations
        
        switch icon {
        case let .image(image):
            let iconNode = ASImageNode()
            iconNode.image = generateTintedImage(image: image, color: textColor)
            self.iconNode = iconNode
            self.animationNode = nil
        case let .animation(animation, scale, offset, replaceColors, flip, startFrame):
            self.animationScale = scale
            self.iconNode = nil
            var colors: [UInt32: UInt32] = [:]
            if let replaceColors = replaceColors {
                for colorToReplace in replaceColors {
                    colors[colorToReplace] = color.rgb
                }
            }
            let animationNode = SimpleAnimationNode(animationName: animation, replaceColors: colors, size: CGSize(width: 79.0, height: 79.0), playOnce: true, startFrame: startFrame)
            if !enableAnimations {
                animationNode.seekToEnd(immediately: true)
            }
            if flip {
                animationNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
            }
            self.animationNode = animationNode
            self.animationNodeOffset = offset
        case .none:
            self.iconNode = nil
            self.animationNode = nil
        }
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
        if let iconNode = self.iconNode {
            self.addSubnode(iconNode)
        } else if let animationNode = self.animationNode {
            self.addSubnode(animationNode)
        }
        self.backgroundNode.backgroundColor = color
        self.highlightNode.backgroundColor = color.withMultipliedBrightnessBy(0.9)
    }
    
    func setHighlighted(_ highlighted: Bool) {
        if highlighted {
            self.insertSubnode(self.highlightNode, aboveSubnode: self.backgroundNode)
            self.highlightNode.layer.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.3)
            self.highlightNode.alpha = 1.0
        } else {
            self.highlightNode.removeFromSupernode()
            self.highlightNode.alpha = 0.0
        }
    }
    
    func resetAnimation() {
        self.animationNode?.reset()
    }
    
    func updateLayout(isFirst: Bool, isLeft: Bool, baseSize: CGSize, alignment: Alignment, isExpanded: Bool, extendedWidth: CGFloat, sideInset: CGFloat, transition: ContainedViewLayoutTransition, additive: Bool, revealFactor: CGFloat, animateIconMovement: Bool) {
        self.highlightNode.frame = CGRect(origin: CGPoint(), size: baseSize)
        
        var animateAdditive = false
        if additive && transition.isAnimated && self.isExpanded != isExpanded {
            animateAdditive = true
        }
        
        let backgroundFrame: CGRect
        if isFirst {
            backgroundFrame = CGRect(origin: CGPoint(x: isLeft ? -400.0 : 0.0, y: 0.0), size: CGSize(width: extendedWidth + 400.0, height: baseSize.height))
        } else {
            backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: extendedWidth, height: baseSize.height))
        }
        let deltaX: CGFloat
        if animateAdditive {
            let previousFrame = self.backgroundNode.frame
            self.backgroundNode.frame = backgroundFrame
            if isLeft {
                deltaX = previousFrame.width - backgroundFrame.width
            } else {
                deltaX = -(previousFrame.width - backgroundFrame.width)
            }
            if !animateIconMovement {
                transition.animatePositionAdditive(node: self.backgroundNode, offset: CGPoint(x: deltaX, y: 0.0))
            }
        } else {
            deltaX = 0.0
            transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        }
        
        self.alignment = alignment
        self.isExpanded = isExpanded
        let titleSize = self.titleNode.calculatedSize
        var contentRect = CGRect(origin: CGPoint(), size: baseSize)
        switch alignment {
        case .left:
            contentRect.origin.x = 0.0
        case .right:
            contentRect.origin.x = extendedWidth - contentRect.width
        }
        
        let placeContent: (ASDisplayNode, CGRect) -> Void = { node, frame in
            if animateAdditive {
                let offsetX = animateIconMovement ? node.frame.minX - frame.minX : deltaX
                node.frame = frame
                transition.animatePositionAdditive(node: node, offset: CGPoint(x: offsetX, y: 0.0))
            } else {
                transition.updateFrame(node: node, frame: frame)
            }
        }
        
        if let animationNode = self.animationNode {
            let imageSize = CGSize(width: animationNode.size.width * self.animationScale, height: animationNode.size.height * self.animationScale)
            let iconOffset: CGFloat = -2.0 + self.animationNodeOffset
            let titleIconSpacing: CGFloat = 11.0
            placeContent(animationNode, CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - imageSize.width + sideInset) / 2.0), y: contentRect.midY - imageSize.height / 2.0 + iconOffset), size: imageSize))
            placeContent(self.titleNode, CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - titleSize.width + sideInset) / 2.0), y: contentRect.midY + titleIconSpacing), size: titleSize))
            
            if self.enableAnimations {
                if abs(revealFactor) >= 0.4 {
                    animationNode.play()
                } else if abs(revealFactor) < CGFloat.ulpOfOne && !transition.isAnimated {
                    animationNode.reset()
                }
            }
        } else if let iconNode = self.iconNode, let imageSize = iconNode.image?.size {
            let iconOffset: CGFloat = -9.0
            let titleIconSpacing: CGFloat = 11.0
            placeContent(iconNode, CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - imageSize.width + sideInset) / 2.0), y: contentRect.midY - imageSize.height / 2.0 + iconOffset), size: imageSize))
            placeContent(self.titleNode, CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - titleSize.width + sideInset) / 2.0), y: contentRect.midY + titleIconSpacing), size: titleSize))
        } else {
            placeContent(self.titleNode, CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - titleSize.width + sideInset) / 2.0), y: contentRect.minY + floor((baseSize.height - titleSize.height) / 2.0)), size: titleSize))
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let titleSize = self.titleNode.measure(constrainedSize)
        var maxWidth = titleSize.width
        if let iconNode = self.iconNode, let image = iconNode.image {
            maxWidth = max(image.size.width, maxWidth)
        }
        return CGSize(width: max(74.0, maxWidth + 20.0), height: constrainedSize.height)
    }
}

public final class ItemListRevealOptionsNode: ASDisplayNode {
    private let optionSelected: (ItemListRevealOption) -> Void
    private let tapticAction: () -> Void
    private let clippingContainerNode: ASDisplayNode
    private let optionsContainerNode: ASDisplayNode

    private var options: [ItemListRevealOption] = []
    private var enableAnimations = true
    private var isLeft: Bool = false

    private var optionNodes: [ItemListRevealOptionNode] = []
    private var revealOffset: CGFloat = 0.0
    private var sideInset: CGFloat = 0.0
    private var currentMetrics: (containerSize: CGSize, metrics: ItemListRevealOptionLayoutMetrics)?

    /// Madgram classic design: 12.0's rectangles in place of the glass circles (`ClassicItemListRevealOptionNode`),
    /// laid out by 12.0's rule (`updateClassicNodesLayout`). Fixed for the node's lifetime.
    private let isClassic: Bool = ClassicDesign.isEnabled
    private var classicOptionNodes: [ClassicItemListRevealOptionNode] = []

    private var visualRevealDistance: CGFloat = 0.0
    private var visualRevealVelocity: CGFloat = 0.0
    private var targetVisualRevealDistance: CGFloat = 0.0
    private var visualRevealAnimationLink: SharedDisplayLinkDriver.Link?

    public init(optionSelected: @escaping (ItemListRevealOption) -> Void, tapticAction: @escaping () -> Void) {
        self.optionSelected = optionSelected
        self.tapticAction = tapticAction
        self.clippingContainerNode = ASDisplayNode()
        self.optionsContainerNode = ASDisplayNode()

        super.init()

        self.clippingContainerNode.clipsToBounds = true
        self.addSubnode(self.clippingContainerNode)
        self.clippingContainerNode.addSubnode(self.optionsContainerNode)
    }

    deinit {
        self.stopVisualRevealAnimation()
    }

    override public func didLoad() {
        super.didLoad()

        let gestureRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        gestureRecognizer.highlight = { [weak self] location in
            guard let self else { return }
            if self.isClassic {
                // 12.0 drew no highlight while a finger was down.
                return
            }
            for node in self.optionNodes {
                node.setHighlighted(location.map { self.containsActionPoint($0) && node.containsActionPoint($0, from: self.view) } ?? false)
            }
        }
        gestureRecognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.view.addGestureRecognizer(gestureRecognizer)
    }

    public func setOptions(_ options: [ItemListRevealOption], isLeft: Bool, enableAnimations: Bool) {
        if self.options != options || self.isLeft != isLeft || self.enableAnimations != enableAnimations {
            self.resetVisualRevealDistance(to: abs(self.revealOffset))
            self.options = options
            self.enableAnimations = enableAnimations
            self.isLeft = isLeft
            for node in self.optionNodes {
                node.removeFromSupernode()
            }
            for node in self.classicOptionNodes {
                node.removeFromSupernode()
            }
            if self.isClassic {
                // The classic rectangles draw their title on the option's color, in its foreground (`iconColor`).
                self.optionNodes = []
                self.classicOptionNodes = options.map { option in
                    return ClassicItemListRevealOptionNode(title: option.title, icon: option.icon, color: option.color, textColor: option.iconColor, enableAnimations: enableAnimations)
                }
                if isLeft {
                    for node in self.classicOptionNodes.reversed() {
                        self.addSubnode(node)
                    }
                } else {
                    for node in self.classicOptionNodes {
                        self.addSubnode(node)
                    }
                }
                self.currentMetrics = nil
                self.invalidateCalculatedLayout()
                return
            }
            self.optionNodes = options.map { option in
                return ItemListRevealOptionNode(title: option.title, icon: option.icon, color: option.color, iconColor: option.iconColor, textColor: option.textColor, enableAnimations: enableAnimations)
            }
            if isLeft {
                for node in self.optionNodes.reversed() {
                    self.optionsContainerNode.addSubnode(node)
                }
            } else {
                for node in self.optionNodes {
                    self.optionsContainerNode.addSubnode(node)
                }
            }
            self.currentMetrics = nil
            self.invalidateCalculatedLayout()
        }
    }

    private func layoutMetrics(for containerSize: CGSize) -> ItemListRevealOptionLayoutMetrics {
        if let currentMetrics = self.currentMetrics, currentMetrics.containerSize == containerSize {
            return currentMetrics.metrics
        }

        let metrics = ItemListRevealOptionLayoutMetrics.metrics(for: containerSize.height, hasVisualIcons: self.options.contains(where: { $0.icon.hasVisualIcon }))
        let maxTitleWidth = self.optionNodes.reduce(0.0) { result, node in
            return max(result, node.titleWidthForGroupPillSizing)
        }
        let updatedMetrics = metrics.withGroupTitleWidth(maxTitleWidth)
        self.currentMetrics = (containerSize, updatedMetrics)
        return updatedMetrics
    }

    /// Madgram classic design: 12.0's option width, the widest option's, which every option takes.
    private func classicOptionWidth(_ constrainedSize: CGSize) -> CGFloat {
        var maxWidth: CGFloat = 0.0
        for node in self.classicOptionNodes {
            let nodeSize = node.measure(constrainedSize)
            maxWidth = max(nodeSize.width, maxWidth)
        }
        return maxWidth
    }

    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        if self.isClassic {
            return CGSize(width: self.classicOptionWidth(constrainedSize) * CGFloat(self.classicOptionNodes.count), height: constrainedSize.height)
        }
        let metrics = self.layoutMetrics(for: constrainedSize)
        for node in self.optionNodes {
            let _ = node.measure(constrainedSize)
        }
        return CGSize(width: metrics.revealWidth(count: self.optionNodes.count), height: constrainedSize.height)
    }

    func motionParameters(width: CGFloat, sideInset: CGFloat, displayScale: CGFloat) -> ItemListRevealMotionParameters {
        if self.isClassic {
            // 12.0 opened the row by exactly its options' width (and the safe inset), with no gaps or margins.
            self.sideInset = self.isLeft ? abs(sideInset) : -abs(sideInset)
            let optionWidth = self.classicOptionWidth(CGSize(width: CGFloat.greatestFiniteMagnitude, height: self.bounds.height))
            return ItemListRevealMotionParameters(width: Double(width), buttonWidth: Double(optionWidth), spacing: 0.0, edgeInset: 0.0, sideInset: Double(abs(sideInset)), count: self.options.count, isDestructive: (self.isLeft ? self.options.first : self.options.last)?.isDestructive ?? false, displayScale: Double(displayScale))
        }
        let metrics = self.layoutMetrics(for: self.bounds.size)
        return ItemListRevealMotionParameters(width: Double(width), buttonWidth: Double(metrics.shapeSize.width), spacing: Double(spacing), edgeInset: Double(edgeInset), sideInset: Double(abs(sideInset)), count: self.options.count, isDestructive: (self.isLeft ? self.options.first : self.options.last)?.isDestructive ?? false, displayScale: Double(displayScale))
    }

    func render(motion: ItemListRevealMotion) {
        self.stopVisualRevealAnimation()
        let distance = CGFloat(max(0, motion.body.value))
        if self.isClassic {
            self.revealOffset = self.isLeft ? -distance : distance
            self.updateClassicNodesLayout(transition: .immediate)
            return
        }
        self.revealOffset = self.isLeft ? -distance : distance
        let size = self.bounds.size
        let metrics = self.layoutMetrics(for: size)
        let clipX = self.isLeft ? max(0, size.width - distance) : 0
        self.clippingContainerNode.frame = CGRect(x: clipX, y: 0, width: distance, height: size.height)
        self.optionsContainerNode.frame = CGRect(x: -clipX, y: 0, width: max(size.width, distance), height: size.height)
        let geometry = motion.buttonGeometry
        for (index, node) in self.optionNodes.enumerated() {
            let order = self.isLeft ? index : self.optionNodes.count - 1 - index
            guard order < geometry.count else { continue }
            let g = geometry[order]
            let primary = order == 0
            let stretched = primary && g.width > Double(metrics.shapeSize.width) + 0.001
            let center = self.isLeft ? max(0, size.width - distance) + CGFloat(g.center) : distance - CGFloat(g.center)
            let nodeWidth = stretched ? CGFloat(g.width) : metrics.slotWidth
            node.frame = CGRect(x: center - nodeWidth / 2, y: 0, width: nodeWidth, height: size.height)
            node.updateLayout(isLeft: self.isLeft, isPrimary: primary, metrics: metrics, revealProgress: CGFloat(motion.scales[order].value), overswipeProgress: 0, expandedProgress: primary ? CGFloat(min(1, max(0, motion.expansion.value))) : 0, isStretched: stretched, isExpanded: motion.isExpanded && primary, transition: .immediate, motionScale: CGFloat(motion.scales[order].value), motionOpacity: CGFloat(motion.opacities[order].value))
        }
    }

    func containsActionPoint(_ point: CGPoint) -> Bool {
        if self.isClassic {
            return self.classicOptionNodes.contains(where: { $0.frame.contains(point) })
        }
        let clipPoint = self.clippingContainerNode.view.convert(point, from: self.view)
        guard self.clippingContainerNode.bounds.contains(clipPoint) else { return false }
        return self.optionNodes.contains { $0.containsActionPoint(point, from: self.view) }
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !self.isHidden, self.alpha > 0.01, self.isUserInteractionEnabled, self.containsActionPoint(point) else {
            return nil
        }
        return self.view
    }

    public func updateRevealOffset(offset: CGFloat, sideInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.revealOffset = offset
        self.sideInset = sideInset
        if self.isClassic {
            self.updateClassicNodesLayout(transition: transition)
            return
        }
        self.updateVisualRevealDistance(targetDistance: abs(offset), transition: transition)
        self.updateNodesLayout(transition: transition)
    }

    private func stopVisualRevealAnimation() {
        self.visualRevealAnimationLink?.isPaused = true
        self.visualRevealAnimationLink?.invalidate()
        self.visualRevealAnimationLink = nil
    }

    private func resetVisualRevealDistance(to distance: CGFloat) {
        let distance = max(0.0, distance)
        self.stopVisualRevealAnimation()
        self.visualRevealDistance = distance
        self.targetVisualRevealDistance = distance
        self.visualRevealVelocity = 0.0
    }

    private func updateVisualRevealDistance(targetDistance: CGFloat, transition: ContainedViewLayoutTransition) {
        let targetDistance = max(0.0, targetDistance)
        let animationSettings = ItemListRevealOptionsAnimationSettingsStore.current
        self.targetVisualRevealDistance = targetDistance

        if transition.isAnimated {
            self.resetVisualRevealDistance(to: targetDistance)
            return
        }

        if self.visualRevealDistance > targetDistance {
            self.visualRevealDistance = targetDistance
            self.visualRevealVelocity = 0.0
        }

        if abs(self.visualRevealDistance - targetDistance) <= animationSettings.visualRevealSnapDistance && abs(self.visualRevealVelocity) <= animationSettings.visualRevealSnapVelocity {
            self.resetVisualRevealDistance(to: targetDistance)
            return
        }

        if self.visualRevealAnimationLink == nil {
            self.visualRevealAnimationLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] deltaTime in
                self?.tickVisualRevealAnimation(deltaTime: deltaTime)
            })
            self.visualRevealAnimationLink?.isPaused = false
        }
    }

    private func tickVisualRevealAnimation(deltaTime: CGFloat) {
        let clampedDeltaTime = min(0.05, max(0.0, deltaTime))
        let targetDistance = self.targetVisualRevealDistance
        let animationSettings = ItemListRevealOptionsAnimationSettingsStore.current

        if self.visualRevealDistance > targetDistance {
            self.visualRevealDistance = targetDistance
            self.visualRevealVelocity = 0.0
        }

        let acceleration = (targetDistance - self.visualRevealDistance) * animationSettings.visualRevealSpring - self.visualRevealVelocity * animationSettings.visualRevealDamping
        self.visualRevealVelocity += acceleration * clampedDeltaTime

        var updatedDistance = self.visualRevealDistance + self.visualRevealVelocity * clampedDeltaTime
        if updatedDistance > targetDistance {
            updatedDistance = targetDistance
            self.visualRevealVelocity = 0.0
        } else if updatedDistance < 0.0 {
            updatedDistance = 0.0
            self.visualRevealVelocity = 0.0
        }
        self.visualRevealDistance = updatedDistance

        if abs(self.visualRevealDistance - targetDistance) <= animationSettings.visualRevealSnapDistance && abs(self.visualRevealVelocity) <= animationSettings.visualRevealSnapVelocity {
            self.resetVisualRevealDistance(to: targetDistance)
        }

        self.updateNodesLayout(transition: .immediate)
    }

    private func updateNodesLayout(transition: ContainedViewLayoutTransition) {
        let size = self.bounds.size
        if size.width.isLessThanOrEqualTo(0.0) || self.optionNodes.isEmpty {
            return
        }
        let metrics = self.layoutMetrics(for: size)
        let animationSettings = ItemListRevealOptionsAnimationSettingsStore.current
        let revealedDistance = abs(self.revealOffset)
        let boundedRevealedDistance = min(revealedDistance, size.width)
        let boundedVisualRevealedDistance = min(self.visualRevealDistance, revealedDistance, size.width)
        let overswipeDistance = max(0.0, revealedDistance - size.width)
        let overswipeProgress = clampToUnitInterval(overswipeDistance / expandedTransitionDistance)
        let expandedActivationDistance = 50.0 * (expandedActivationWidthFactor - 1.0)
        let primaryIndex = self.isLeft ? 0 : self.optionNodes.count - 1
        let stride = metrics.shapeSize.width + spacing

        let clippingFrameX: CGFloat
        if self.isLeft {
            clippingFrameX = max(0.0, size.width - revealedDistance)
        } else {
            clippingFrameX = 0.0
        }
        let clippingFrame = CGRect(origin: CGPoint(x: clippingFrameX, y: 0.0), size: CGSize(width: revealedDistance, height: size.height))
        transition.updateFrame(node: self.clippingContainerNode, frame: clippingFrame, completion: { [weak self] completed in
            guard completed, revealedDistance < CGFloat.ulpOfOne, let self, abs(self.revealOffset) < CGFloat.ulpOfOne else {
                return
            }
            for node in self.optionNodes {
                node.resetAnimation()
            }
        })
        transition.updateFrame(node: self.optionsContainerNode, frame: CGRect(origin: CGPoint(x: -clippingFrameX, y: 0.0), size: CGSize(width: max(size.width, revealedDistance), height: size.height)))

        var i = self.isLeft ? (self.optionNodes.count - 1) : 0
        while i >= 0 && i < self.optionNodes.count {
            let node = self.optionNodes[i]
            let isPrimary = i == primaryIndex
            let isStretched = isPrimary && overswipeDistance > CGFloat.ulpOfOne
            let isExpanded = isPrimary && overswipeDistance > expandedActivationDistance
            let expandedProgress: CGFloat = isExpanded ? 1.0 : 0.0
            if node.hasAppliedLayout && node.isExpanded != isExpanded && !transition.isAnimated {
                self.tapticAction()
            }

            let baseCircleFrame: CGRect
            let nodeFrame: CGRect
            let revealProgress: CGFloat

            if self.isLeft {
                let baseCircleLeft = size.width - boundedRevealedDistance + self.sideInset + edgeInset + CGFloat(i) * stride
                baseCircleFrame = CGRect(origin: CGPoint(x: baseCircleLeft, y: 0.0), size: metrics.shapeSize)
                let visualBaseCircleLeft = size.width - boundedVisualRevealedDistance + self.sideInset + edgeInset + CGFloat(i) * stride
                let distanceFromShutterEdge = size.width - (visualBaseCircleLeft + metrics.shapeSize.width)
                revealProgress = revealProgressCurve((distanceFromShutterEdge + animationSettings.revealStartOverlap) / max(1.0, animationSettings.revealStartOverlap + animationSettings.revealEndDistance), response: animationSettings.revealProgressResponse)

                if isStretched {
                    let primaryLeft = size.width - boundedRevealedDistance + self.sideInset + edgeInset
                    let primaryRight: CGFloat
                    if self.optionNodes.count > 1 {
                        let neighborLeft = primaryLeft + stride + overswipeDistance
                        primaryRight = max(primaryLeft + metrics.shapeSize.width, neighborLeft - spacing)
                    } else {
                        primaryRight = primaryLeft + metrics.shapeSize.width + overswipeDistance
                    }
                    nodeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(primaryLeft), y: 0.0), size: CGSize(width: max(metrics.shapeSize.width, primaryRight - primaryLeft), height: size.height))
                } else {
                    let circleLeft = baseCircleLeft + (isPrimary ? 0.0 : overswipeDistance)
                    nodeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(circleLeft - metrics.slotShapeInset), y: 0.0), size: CGSize(width: metrics.slotWidth, height: size.height))
                }
            } else {
                let baseCircleRight = revealedDistance + self.sideInset - edgeInset - CGFloat(self.optionNodes.count - 1 - i) * stride
                baseCircleFrame = CGRect(origin: CGPoint(x: baseCircleRight - metrics.shapeSize.width, y: 0.0), size: metrics.shapeSize)
                let visualBaseCircleRight = boundedVisualRevealedDistance + self.sideInset - edgeInset - CGFloat(self.optionNodes.count - 1 - i) * stride
                revealProgress = revealProgressCurve((visualBaseCircleRight - metrics.shapeSize.width + animationSettings.revealStartOverlap) / max(1.0, animationSettings.revealStartOverlap + animationSettings.revealEndDistance), response: animationSettings.revealProgressResponse)

                if isStretched {
                    let primaryRight = revealedDistance + self.sideInset - edgeInset
                    let primaryLeft: CGFloat
                    if self.optionNodes.count > 1 {
                        let neighborRight = primaryRight - stride - overswipeDistance
                        primaryLeft = min(primaryRight - metrics.shapeSize.width, neighborRight + spacing)
                    } else {
                        primaryLeft = primaryRight - metrics.shapeSize.width - overswipeDistance
                    }
                    nodeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(primaryLeft), y: 0.0), size: CGSize(width: max(metrics.shapeSize.width, primaryRight - primaryLeft), height: size.height))
                } else {
                    let circleLeft = baseCircleFrame.minX - (isPrimary ? 0.0 : overswipeDistance)
                    nodeFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(circleLeft - metrics.slotShapeInset), y: 0.0), size: CGSize(width: metrics.slotWidth, height: size.height))
                }
            }

            transition.updateFrame(node: node, frame: nodeFrame)

            node.updateLayout(isLeft: self.isLeft, isPrimary: isPrimary, metrics: metrics, revealProgress: revealProgress, overswipeProgress: overswipeProgress, expandedProgress: expandedProgress, isStretched: isStretched, isExpanded: isExpanded, transition: transition)

            if self.isLeft {
                i -= 1
            } else {
                i += 1
            }
        }
    }

    /// Madgram classic design: 12.0's layout (`ItemListRevealOptionsNode.updateNodesLayout` at release-12.0). The
    /// options share the revealed width equally, each stretching with the swipe, and the outermost one expands over the
    /// others past the boundary (a full swipe).
    private func updateClassicNodesLayout(transition: ContainedViewLayoutTransition) {
        let size = self.bounds.size
        if size.width.isLessThanOrEqualTo(0.0) || self.classicOptionNodes.isEmpty {
            return
        }
        let optionNodes = self.classicOptionNodes
        let basicNodeWidth = floor((size.width - abs(self.sideInset)) / CGFloat(optionNodes.count))
        let lastNodeWidth = size.width - basicNodeWidth * CGFloat(optionNodes.count - 1)
        let revealFactor = self.revealOffset / size.width
        let boundaryRevealFactor: CGFloat
        if optionNodes.count > 2 {
            boundaryRevealFactor = 1.0 + 16.0 / size.width
        } else {
            boundaryRevealFactor = 1.0 + basicNodeWidth / size.width
        }
        let startingOffset: CGFloat
        if self.isLeft {
            startingOffset = size.width + max(0.0, abs(revealFactor) - 1.0) * size.width
        } else {
            startingOffset = 0.0
        }
        
        let animated = transition.isAnimated
        var completionCount = optionNodes.count
        // A strong capture, as 12.0's: a `[weak]` closure that also captures the mutable `completionCount` is the shape
        // Swift 6.4 miscompiles (CLAUDE.md, "Swift 6.4: `[weak]` in a local closure that also captures a `var`").
        let intermediateCompletion = {
            if completionCount == 0 && animated && abs(self.revealOffset) < CGFloat.ulpOfOne {
                for node in self.classicOptionNodes {
                    node.resetAnimation()
                }
            }
        }
        
        var i = self.isLeft ? (optionNodes.count - 1) : 0
        while i >= 0 && i < optionNodes.count {
            let node = optionNodes[i]
            let nodeWidth = i == (optionNodes.count - 1) ? lastNodeWidth : basicNodeWidth
            var nodeTransition = transition
            var isExpanded = false
            if (self.isLeft && i == 0) || (!self.isLeft && i == optionNodes.count - 1) {
                if abs(revealFactor) > boundaryRevealFactor {
                    isExpanded = true
                }
            }
            if let _ = node.alignment, node.isExpanded != isExpanded {
                nodeTransition = transition.isAnimated ? transition : .animated(duration: 0.2, curve: .easeInOut)
                if !transition.isAnimated {
                    self.tapticAction()
                }
            }
            
            var sideInset: CGFloat = 0.0
            if i == optionNodes.count - 1 {
                sideInset = self.sideInset
            }
            
            let extendedWidth: CGFloat
            let nodeLeftOffset: CGFloat
            if isExpanded {
                nodeLeftOffset = 0.0
                extendedWidth = size.width * max(1.0, abs(revealFactor))
            } else if self.isLeft {
                let offset = basicNodeWidth * CGFloat(optionNodes.count - 1 - i)
                extendedWidth = (size.width - offset) * max(1.0, abs(revealFactor))
                nodeLeftOffset = startingOffset - extendedWidth - floorToScreenPixels(offset * abs(revealFactor))
            } else {
                let offset = basicNodeWidth * CGFloat(i)
                extendedWidth = (size.width - offset) * max(1.0, abs(revealFactor))
                nodeLeftOffset = startingOffset + floorToScreenPixels(offset * abs(revealFactor))
            }
            
            transition.updateFrame(node: node, frame: CGRect(origin: CGPoint(x: nodeLeftOffset, y: 0.0), size: CGSize(width: extendedWidth, height: size.height)), completion: { _ in
                completionCount -= 1
                intermediateCompletion()
            })
            
            let nodeAlignment: ClassicItemListRevealOptionNode.Alignment
            if optionNodes.count > 1 {
                nodeAlignment = self.isLeft ? .right : .left
            } else if self.isLeft {
                nodeAlignment = isExpanded ? .right : .left
            } else {
                nodeAlignment = isExpanded ? .left : .right
            }
            let animateIconMovement = optionNodes.count == 1
            node.updateLayout(isFirst: (self.isLeft && i == 0) || (!self.isLeft && i == optionNodes.count - 1), isLeft: self.isLeft, baseSize: CGSize(width: nodeWidth, height: size.height), alignment: nodeAlignment, isExpanded: isExpanded, extendedWidth: extendedWidth, sideInset: sideInset, transition: nodeTransition, additive: !transition.isAnimated, revealFactor: revealFactor, animateIconMovement: animateIconMovement)
            
            if self.isLeft {
                i -= 1
            } else {
                i += 1
            }
        }
    }

    @objc private func tapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        if self.isClassic {
            if case .ended = recognizer.state, let gesture = recognizer.lastRecognizedGestureAndLocation?.0, case .tap = gesture {
                let location = recognizer.location(in: self.view)
                var i = self.isLeft ? 0 : (self.classicOptionNodes.count - 1)
                while i >= 0 && i < self.classicOptionNodes.count {
                    self.classicOptionNodes[i].setHighlighted(false)
                    if self.classicOptionNodes[i].frame.contains(location) {
                        self.optionSelected(self.options[i])
                        break
                    }
                    if self.isLeft {
                        i += 1
                    } else {
                        i -= 1
                    }
                }
            }
            return
        }
        if case .ended = recognizer.state, let gesture = recognizer.lastRecognizedGestureAndLocation?.0, case .tap = gesture {
            let location = recognizer.location(in: self.view)
            var selectedOption: Int?

            var i = self.isLeft ? 0 : (self.optionNodes.count - 1)
            while i >= 0 && i < self.optionNodes.count {
                self.optionNodes[i].setHighlighted(false)
                if self.containsActionPoint(location) && self.optionNodes[i].containsActionPoint(location, from: self.view) {
                    selectedOption = i
                    break
                }
                if self.isLeft {
                    i += 1
                } else {
                    i -= 1
                }
            }
            if let selectedOption = selectedOption {
                self.optionSelected(self.options[selectedOption])
            }
        }
    }

    public func isDisplayingExtendedAction() -> Bool {
        if self.isClassic {
            return self.classicOptionNodes.contains(where: { $0.isExpanded })
        }
        return self.optionNodes.contains(where: { $0.isExpanded })
    }
}
