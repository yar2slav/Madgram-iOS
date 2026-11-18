import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import WallpaperBackgroundNode
import AnimatedCountLabelNode
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters
import AppBundle

private let badgeFont = Font.with(size: 13.0, traits: [.monospacedNumbers])

/// Madgram classic design: Telegram 12.0's reactions button glyph (`Chat/Context Menu/Reactions`), as a template
/// image of the button's 38pt size so the image view tints it like today's resources.
private let classicReactionsButtonImage: UIImage? = {
    return generateImage(CGSize(width: 38.0, height: 38.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reactions"), color: UIColor.white), let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size))
        }
    })?.withRenderingMode(.alwaysTemplate)
}()

/// Madgram classic design: Telegram 12.0's mentions button glyph (`Chat/NavigateToMentionsClassic`, the 12.0
/// `Chat/NavigateToMentions` asset), drawn like `classicReactionsButtonImage`.
private let classicMentionsButtonImage: UIImage? = {
    return generateImage(CGSize(width: 38.0, height: 38.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/NavigateToMentionsClassic"), color: UIColor.white), let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size))
        }
    })?.withRenderingMode(.alwaysTemplate)
}()

enum ChatHistoryNavigationButtonType {
    case down
    case up
    case mentions
    case reactions
    case pollVotes
}

class ChatHistoryNavigationButtonNode: ContextControllerSourceNode {
    let containerNode: ContextExtractedContentContainingNode
    private let backgroundView: GlassBackgroundView
    let imageView: GlassBackgroundView.ContentImageView
    private let badgeBackgroundView: GlassBackgroundView
    private let badgeTextNode: ImmediateAnimatedCountLabelNode
    private var tapRecognizer: UITapGestureRecognizer?
    
    /// Madgram classic design (`ClassicDesign.isEnabled`, captured at creation): Telegram 12.0's button, a 38pt
    /// circle of the input panel's blurred color under a hairline ring, an accent icon, and the theme's 18pt badge.
    /// The glass views above are then created but never put on screen.
    private let isClassic: Bool
    private var classicButtonView: UIView?
    private var classicBackgroundNode: NavigationBackgroundNode?
    private var classicBackgroundContent: WallpaperBubbleBackgroundNode?
    private var classicStrokeView: UIImageView?
    private var classicBadgeBackgroundNode: ASImageNode?
    
    /// The view that shows the badge: the classic badge image, or the glass badge.
    private var badgeContainerView: UIView {
        if let classicBadgeBackgroundNode = self.classicBadgeBackgroundNode {
            return classicBadgeBackgroundNode.view
        }
        return self.badgeBackgroundView
    }
    
    private var buttonDiameter: CGFloat {
        return self.isClassic ? 38.0 : 40.0
    }
    
    var tapped: (() -> Void)? {
        didSet {
            self.tapRecognizer?.isEnabled = self.tapped != nil && self.isEnabled
        }
    }
    
    var isEnabled: Bool = true {
        didSet {
            self.tapRecognizer?.isEnabled = self.tapped != nil && self.isEnabled
        }
    }
    
    var badge: String = "" {
        didSet {
            if self.badge != oldValue {
                self.layoutBadge()
            }
        }
    }
    
    private var theme: PresentationTheme
    private var preferClearGlass: Bool
    private let type: ChatHistoryNavigationButtonType
    
    init(theme: PresentationTheme, preferClearGlass: Bool, backgroundNode: WallpaperBackgroundNode, type: ChatHistoryNavigationButtonType) {
        self.theme = theme
        self.preferClearGlass = preferClearGlass
        self.type = type
        self.isClassic = ClassicDesign.isEnabled
        
        self.containerNode = ContextExtractedContentContainingNode()

        self.backgroundView = GlassBackgroundView()
        
        self.imageView = GlassBackgroundView.ContentImageView()
        switch type {
        case .down:
            self.imageView.image = PresentationResourcesChat.chatHistoryNavigationButtonImage(theme)
        case .up:
            self.imageView.image = PresentationResourcesChat.chatHistoryNavigationUpButtonImage(theme)
        case .mentions:
            self.imageView.image = PresentationResourcesChat.chatHistoryMentionsButtonImage(theme)
        case .reactions:
            self.imageView.image = PresentationResourcesChat.chatHistoryReactionsButtonImage(theme)
        case .pollVotes:
            self.imageView.image = PresentationResourcesChat.chatHistoryPollVotesButtonImage(theme)
        }
        
        self.badgeBackgroundView = GlassBackgroundView()
        self.badgeBackgroundView.isUserInteractionEnabled = false
        self.badgeBackgroundView.alpha = 0.0
        
        self.badgeTextNode = ImmediateAnimatedCountLabelNode()
        self.badgeTextNode.isUserInteractionEnabled = false
        self.badgeTextNode.displaysAsynchronously = false
        self.badgeTextNode.reverseAnimationDirection = true
        
        super.init()
        
        if self.isClassic {
            self.setupClassic(theme: theme, backgroundNode: backgroundNode)
            return
        }
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:)))
        self.tapRecognizer = tapRecognizer
        self.backgroundView.contentView.addGestureRecognizer(tapRecognizer)
        tapRecognizer.isEnabled = false
        
        self.addSubnode(self.containerNode)
        
        let size = CGSize(width: 40.0, height: 40.0)
        
        self.containerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
        self.containerNode.contentRect = CGRect(origin: CGPoint(), size: size)
        
        self.containerNode.contentNode.view.addSubview(self.backgroundView)

        self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: self.preferClearGlass ? .clear : .panel), isInteractive: true, transition: .immediate)
        self.imageView.tintColor = theme.chat.inputPanel.panelControlColor

        self.backgroundView.contentView.addSubview(self.imageView)
        self.imageView.frame = CGRect(origin: CGPoint(), size: size)
        
        self.containerNode.contentNode.view.addSubview(self.badgeBackgroundView)
        self.badgeBackgroundView.contentView.addSubview(self.badgeTextNode.view)
        
        self.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    /// Telegram 12.0's layout of this button (`ChatHistoryNavigationButtonNode` at release-12.0).
    private func setupClassic(theme: PresentationTheme, backgroundNode: WallpaperBackgroundNode) {
        let size = CGSize(width: 38.0, height: 38.0)
        
        let buttonView = UIView()
        buttonView.frame = CGRect(origin: CGPoint(), size: size)
        self.classicButtonView = buttonView
        
        let classicBackgroundNode = NavigationBackgroundNode(color: theme.chat.inputPanel.panelBackgroundColor)
        classicBackgroundNode.isUserInteractionEnabled = false
        classicBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        classicBackgroundNode.update(size: size, cornerRadius: size.width / 2.0, transition: .immediate)
        self.classicBackgroundNode = classicBackgroundNode
        
        let classicStrokeView = UIImageView()
        classicStrokeView.isUserInteractionEnabled = false
        classicStrokeView.image = PresentationResourcesChat.chatHistoryNavigationButtonBackground(theme)
        classicStrokeView.frame = CGRect(origin: CGPoint(), size: size)
        self.classicStrokeView = classicStrokeView
        
        let classicBadgeBackgroundNode = ASImageNode()
        classicBadgeBackgroundNode.isUserInteractionEnabled = false
        classicBadgeBackgroundNode.displayWithoutProcessing = true
        classicBadgeBackgroundNode.displaysAsynchronously = false
        classicBadgeBackgroundNode.image = PresentationResourcesChat.chatHistoryNavigationButtonBadgeImage(theme)
        classicBadgeBackgroundNode.alpha = 0.0
        self.classicBadgeBackgroundNode = classicBadgeBackgroundNode
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:)))
        self.tapRecognizer = tapRecognizer
        buttonView.addGestureRecognizer(tapRecognizer)
        tapRecognizer.isEnabled = false
        
        self.addSubnode(self.containerNode)
        
        self.containerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
        self.containerNode.contentRect = CGRect(origin: CGPoint(), size: size)
        
        self.containerNode.contentNode.view.addSubview(buttonView)
        buttonView.addSubview(classicBackgroundNode.view)
        buttonView.addSubview(classicStrokeView)
        
        // 12.0 drew these icons in the navigation bar's accent; today's resources are templates.
        self.imageView.tintColor = theme.rootController.navigationBar.accentTextColor
        self.imageView.frame = CGRect(origin: CGPoint(), size: size)
        buttonView.addSubview(self.imageView)
        self.updateImage()
        
        buttonView.addSubview(classicBadgeBackgroundNode.view)
        classicBadgeBackgroundNode.addSubnode(self.badgeTextNode)
        
        self.frame = CGRect(origin: CGPoint(), size: size)
        
        self.updateClassicBackgroundContent(backgroundNode: backgroundNode)
    }
    
    /// 12.0 tinted the button with the wallpaper's bubble background when the wallpaper has one.
    private func updateClassicBackgroundContent(backgroundNode: WallpaperBackgroundNode) {
        guard let buttonView = self.classicButtonView, let classicBackgroundNode = self.classicBackgroundNode else {
            return
        }
        if backgroundNode.hasExtraBubbleBackground() {
            if self.classicBackgroundContent == nil {
                if let backgroundContent = backgroundNode.makeBubbleBackground(for: .free) {
                    backgroundContent.allowsGroupOpacity = true
                    backgroundContent.clipsToBounds = true
                    backgroundContent.alpha = 0.3
                    backgroundContent.cornerRadius = 19.0
                    backgroundContent.isUserInteractionEnabled = false
                    backgroundContent.frame = classicBackgroundNode.frame
                    buttonView.insertSubview(backgroundContent.view, aboveSubview: classicBackgroundNode.view)
                    self.classicBackgroundContent = backgroundContent
                }
            }
        } else {
            self.classicBackgroundContent?.view.removeFromSuperview()
            self.classicBackgroundContent = nil
        }
    }
    
    func updateTheme(theme: PresentationTheme, preferClearGlass: Bool, backgroundNode: WallpaperBackgroundNode) {
        if self.isClassic {
            if self.theme !== theme {
                self.theme = theme
                
                self.classicBackgroundNode?.updateColor(color: theme.chat.inputPanel.panelBackgroundColor, transition: .immediate)
                self.classicStrokeView?.image = PresentationResourcesChat.chatHistoryNavigationButtonBackground(theme)
                self.classicBadgeBackgroundNode?.image = PresentationResourcesChat.chatHistoryNavigationButtonBadgeImage(theme)
                self.imageView.tintColor = theme.rootController.navigationBar.accentTextColor
                self.updateImage()
                self.updateBadgeSegments()
            }
            self.preferClearGlass = preferClearGlass
            self.updateClassicBackgroundContent(backgroundNode: backgroundNode)
            return
        }
        if self.theme !== theme || self.preferClearGlass != preferClearGlass {
            self.theme = theme
            self.preferClearGlass = preferClearGlass

            self.backgroundView.update(size: self.backgroundView.bounds.size, cornerRadius: self.backgroundView.bounds.size.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: self.preferClearGlass ? .clear : .panel), transition: .immediate)
            self.imageView.tintColor = theme.chat.inputPanel.panelControlColor
            
            switch self.type {
            case .down:
                self.imageView.image = PresentationResourcesChat.chatHistoryNavigationButtonImage(theme)
            case .up:
                self.imageView.image = PresentationResourcesChat.chatHistoryNavigationUpButtonImage(theme)
            case .mentions:
                self.imageView.image = PresentationResourcesChat.chatHistoryMentionsButtonImage(theme)
            case .reactions:
                self.imageView.image = PresentationResourcesChat.chatHistoryReactionsButtonImage(theme)
            case .pollVotes:
                self.imageView.image = PresentationResourcesChat.chatHistoryPollVotesButtonImage(theme)
            }
            
            self.badgeBackgroundView.update(size: self.badgeBackgroundView.bounds.size, cornerRadius: self.badgeBackgroundView.bounds.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .custom(style: .default, color: theme.chat.inputPanel.actionControlFillColor)), transition: .immediate)
            
            var segments: [AnimatedCountLabelNode.Segment] = []
            if let value = Int(self.badge) {
                self.currentValue = value
                segments.append(.number(value, NSAttributedString(string: self.badge, font: badgeFont, textColor: self.theme.chat.historyNavigation.badgeTextColor)))
            } else {
                self.currentValue = 0
                segments.append(.text(100, NSAttributedString(string: self.badge, font: badgeFont, textColor: self.theme.chat.historyNavigation.badgeTextColor)))
            }
            self.badgeTextNode.segments = segments
        }
    }
    
    private func updateImage() {
        switch self.type {
        case .down:
            self.imageView.image = PresentationResourcesChat.chatHistoryNavigationButtonImage(self.theme)
        case .up:
            self.imageView.image = PresentationResourcesChat.chatHistoryNavigationUpButtonImage(self.theme)
        case .mentions:
            // 12.0's "@" glyph; today's asset is a different drawing.
            self.imageView.image = classicMentionsButtonImage ?? PresentationResourcesChat.chatHistoryMentionsButtonImage(self.theme)
        case .reactions:
            // 12.0 drew the context-menu reactions glyph here; the asset is unchanged since then.
            self.imageView.image = classicReactionsButtonImage ?? PresentationResourcesChat.chatHistoryReactionsButtonImage(self.theme)
        case .pollVotes:
            self.imageView.image = PresentationResourcesChat.chatHistoryPollVotesButtonImage(self.theme)
        }
    }
    
    private func updateBadgeSegments() {
        var segments: [AnimatedCountLabelNode.Segment] = []
        if let value = Int(self.badge) {
            self.currentValue = value
            segments.append(.number(value, NSAttributedString(string: self.badge, font: badgeFont, textColor: self.theme.chat.historyNavigation.badgeTextColor)))
        } else {
            self.currentValue = 0
            segments.append(.text(100, NSAttributedString(string: self.badge, font: badgeFont, textColor: self.theme.chat.historyNavigation.badgeTextColor)))
        }
        self.badgeTextNode.segments = segments
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.absoluteRect = (rect, containerSize)
    }
    
    @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let tapped = self.tapped {
                tapped()
            }
        }
    }
    
    private var currentValue: Int = 0
    private func layoutBadge() {
        if !self.badge.isEmpty {
            let previousValue = self.currentValue
            var segments: [AnimatedCountLabelNode.Segment] = []
            if let value = Int(self.badge) {
                self.currentValue = value
                segments.append(.number(value, NSAttributedString(string: self.badge, font: badgeFont, textColor: self.theme.chat.historyNavigation.badgeTextColor)))
            } else {
                self.currentValue = 0
                segments.append(.text(100, NSAttributedString(string: self.badge, font: badgeFont, textColor: self.theme.chat.historyNavigation.badgeTextColor)))
            }
            self.badgeTextNode.segments = segments
            
            let badgeSize = self.badgeTextNode.updateLayout(size: CGSize(width: 200.0, height: 100.0), animated: true)
            // Classic: 12.0's 18pt badge, overlapping the button's top by half its height.
            let badgeHeight: CGFloat = self.isClassic ? 18.0 : 20.0
            let backgroundSize = CGSize(width: self.badge.count == 1 ? badgeHeight : max(badgeHeight, badgeSize.width + 10.0 + 1.0), height: badgeHeight)
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((self.buttonDiameter - backgroundSize.width) / 2.0), y: self.isClassic ? -9.0 : -7.0), size: backgroundSize)
            let badgeContainerView = self.badgeContainerView
            if backgroundFrame.width < badgeContainerView.frame.width {
                badgeContainerView.layer.animateFrame(from: badgeContainerView.frame, to: backgroundFrame, duration: 0.2)
                badgeContainerView.frame = backgroundFrame
            } else {
                badgeContainerView.frame = backgroundFrame
            }
            
            if !self.isClassic {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                self.badgeBackgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .custom(style: .default, color: self.theme.chat.inputPanel.actionControlFillColor)), transition: ComponentTransition(transition))
            }
            
            self.badgeTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundFrame.width - badgeSize.width) / 2.0), y: self.isClassic ? 1.0 : 2.0), size: badgeSize)
            
            if self.badgeContainerView.alpha < 1.0 {
                self.badgeContainerView.alpha = 1.0
                
                self.badgeContainerView.layer.animateScale(from: 0.01, to: 1.2, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
                    if let strongSelf = self {
                        strongSelf.badgeContainerView.layer.animateScale(from: 1.15, to: 1.0, duration: 0.12, removeOnCompletion: false, completion: { _ in
                            strongSelf.badgeContainerView.layer.removeAllAnimations()
                        })
                    }
                })
                self.badgeContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            } else if previousValue < self.currentValue {
                self.badgeContainerView.layer.animateScale(from: 1.0, to: 1.2, duration: 0.12, removeOnCompletion: false, completion: { [weak self] finished in
                    if let strongSelf = self {
                        strongSelf.badgeContainerView.layer.animateScale(from: 1.2, to: 1.0, duration: 0.12, removeOnCompletion: false, completion: { _ in
                            strongSelf.badgeContainerView.layer.removeAllAnimations()
                        })
                    }
                })
            }
        } else {
            self.currentValue = 0
            if self.badgeContainerView.alpha > 0.0 {
                self.badgeContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                self.badgeContainerView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
            }
            self.badgeContainerView.alpha = 0.0
        }
    }
}
