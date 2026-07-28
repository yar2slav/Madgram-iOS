import Foundation
import UIKit
import Photos
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import WallpaperBackgroundNode
import UndoUI

public let messageShotMessageLimit: Int = 20

public struct MessageShotOptions: Equatable {
    public var showWallpaper: Bool = true
    public var darkTheme: Bool = false
    public var showAvatar: Bool = true
    public var showDateHeader: Bool = true
    public var showReactions: Bool = true
    public var revealSpoilers: Bool = false
}

private enum MessageShotToggle: Int, CaseIterable {
    case wallpaper
    case darkTheme
    case avatar
    case dateHeader
    case reactions
    case spoilers
}

private final class MessageShotToggleNode: HighlightTrackingButtonNode {
    private let backgroundNode: ASImageNode
    private let labelNode: ImmediateTextNode

    var isSelectedValue: Bool = false

    init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false

        super.init()

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
    }

    func update(title: String, isSelected: Bool, theme: PresentationTheme) -> CGSize {
        self.isSelectedValue = isSelected
        let textColor = isSelected ? theme.list.itemCheckColors.foregroundColor : theme.list.itemPrimaryTextColor
        self.labelNode.attributedText = NSAttributedString(string: title, font: Font.regular(14.0), textColor: textColor)
        let titleSize = self.labelNode.updateLayout(CGSize(width: 200.0, height: 100.0))
        let size = CGSize(width: titleSize.width + 24.0, height: 30.0)
        self.labelNode.frame = CGRect(origin: CGPoint(x: 12.0, y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
        self.backgroundNode.image = generateStretchableFilledCircleImage(
            radius: 15.0,
            color: isSelected ? theme.list.itemCheckColors.fillColor : theme.list.itemBlocksBackgroundColor
        )
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        return size
    }
}

private final class MessageShotActionNode: HighlightTrackingButtonNode {
    private let backgroundNode: ASImageNode
    private let labelNode: ImmediateTextNode

    init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false

        super.init()

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
    }

    func update(title: String, isPrimary: Bool, width: CGFloat, theme: PresentationTheme) -> CGSize {
        let textColor = isPrimary ? theme.list.itemCheckColors.foregroundColor : theme.list.itemAccentColor
        self.labelNode.attributedText = NSAttributedString(string: title, font: Font.semibold(15.0), textColor: textColor)
        let titleSize = self.labelNode.updateLayout(CGSize(width: width, height: 100.0))
        let size = CGSize(width: width, height: 44.0)
        self.labelNode.frame = CGRect(
            origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: floorToScreenPixels((size.height - titleSize.height) / 2.0)),
            size: titleSize
        )
        self.backgroundNode.image = generateStretchableFilledCircleImage(
            radius: 11.0,
            color: isPrimary ? theme.list.itemCheckColors.fillColor : theme.list.itemBlocksBackgroundColor
        )
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        return size
    }
}

private final class MessageShotScreenNode: ASDisplayNode {
    private let context: AccountContext
    private let messages: [EngineMessage]
    private let preservesWallpaperAcrossThemes: Bool

    private var presentationData: PresentationData
    private var options = MessageShotOptions()

    private let previewContainerNode: ASDisplayNode
    private let wallpaperBackgroundNode: WallpaperBackgroundNode
    private let messagesContainerNode: ASDisplayNode
    private var messageNodes: [ListViewItemNode]?
    private var dateHeaderNode: ListViewItemHeaderNode?
    private var avatarHeaderNodes: [ListViewItemHeaderNode] = []

    private let panelNode: ASDisplayNode
    private let panelSeparatorNode: ASDisplayNode
    private var toggleNodes: [MessageShotToggle: MessageShotToggleNode] = [:]
    private let shareNode: MessageShotActionNode
    private let saveNode: MessageShotActionNode
    private let copyNode: MessageShotActionNode

    private var validLayout: (ContainerViewLayout, CGFloat)?
    private var messagesBoundingFrame: CGRect?

    var presentToast: ((String) -> Void)?
    var presentNativeController: ((UIViewController) -> Void)?

    init(context: AccountContext, messages: [EngineMessage], wallpaper: TelegramWallpaper) {
        self.context = context
        self.messages = messages
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.preservesWallpaperAcrossThemes = wallpaper != presentationData.theme.chat.defaultWallpaper
        self.presentationData = presentationData.withUpdated(chatWallpaper: wallpaper)
        self.options.darkTheme = self.presentationData.theme.overallDarkAppearance

        self.previewContainerNode = ASDisplayNode()
        self.previewContainerNode.clipsToBounds = true

        self.wallpaperBackgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
        self.wallpaperBackgroundNode.displaysAsynchronously = false

        self.messagesContainerNode = ASDisplayNode()
        self.messagesContainerNode.clipsToBounds = false
        self.messagesContainerNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)

        self.panelNode = ASDisplayNode()
        self.panelSeparatorNode = ASDisplayNode()
        self.shareNode = MessageShotActionNode()
        self.saveNode = MessageShotActionNode()
        self.copyNode = MessageShotActionNode()

        super.init()

        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.panelNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.panelSeparatorNode.backgroundColor = self.presentationData.theme.list.itemBlocksSeparatorColor

        self.addSubnode(self.previewContainerNode)
        self.previewContainerNode.addSubnode(self.wallpaperBackgroundNode)
        self.previewContainerNode.addSubnode(self.messagesContainerNode)
        self.addSubnode(self.panelNode)
        self.addSubnode(self.panelSeparatorNode)

        for toggle in MessageShotToggle.allCases {
            let node = MessageShotToggleNode()
            node.addTarget(self, action: #selector(self.togglePressed(_:)), forControlEvents: .touchUpInside)
            self.toggleNodes[toggle] = node
            self.panelNode.addSubnode(node)
        }
        self.panelNode.addSubnode(self.shareNode)
        self.panelNode.addSubnode(self.saveNode)
        self.panelNode.addSubnode(self.copyNode)

        self.shareNode.addTarget(self, action: #selector(self.sharePressed), forControlEvents: .touchUpInside)
        self.saveNode.addTarget(self, action: #selector(self.savePressed), forControlEvents: .touchUpInside)
        self.copyNode.addTarget(self, action: #selector(self.copyPressed), forControlEvents: .touchUpInside)

        self.applyWallpaper()
    }

    private var effectivePresentationData: PresentationData {
        if self.options.darkTheme == self.presentationData.theme.overallDarkAppearance {
            return self.presentationData
        }
        let theme = self.options.darkTheme ? defaultDarkColorPresentationTheme : defaultPresentationTheme
        var result = self.presentationData.withUpdated(theme: theme)
        if !self.preservesWallpaperAcrossThemes {
            result = result.withUpdated(chatWallpaper: theme.chat.defaultWallpaper)
        }
        return result
    }

    private func applyWallpaper() {
        let presentationData = self.effectivePresentationData
        self.wallpaperBackgroundNode.update(wallpaper: presentationData.chatWallpaper, animated: false)
        self.wallpaperBackgroundNode.updateBubbleTheme(bubbleTheme: presentationData.theme, bubbleCorners: presentationData.chatBubbleCorners)
        self.wallpaperBackgroundNode.isHidden = !self.options.showWallpaper
    }

    @objc private func togglePressed(_ sender: HighlightTrackingButtonNode) {
        guard let toggle = self.toggleNodes.first(where: { $0.value === sender })?.key else {
            return
        }
        switch toggle {
        case .wallpaper:
            self.options.showWallpaper = !self.options.showWallpaper
        case .darkTheme:
            self.options.darkTheme = !self.options.darkTheme
        case .avatar:
            self.options.showAvatar = !self.options.showAvatar
        case .dateHeader:
            self.options.showDateHeader = !self.options.showDateHeader
        case .reactions:
            self.options.showReactions = !self.options.showReactions
        case .spoilers:
            self.options.revealSpoilers = !self.options.revealSpoilers
        }

        if let messageNodes = self.messageNodes {
            for node in messageNodes {
                node.removeFromSupernode()
            }
            self.messageNodes = nil
        }
        self.dateHeaderNode?.removeFromSupernode()
        self.dateHeaderNode = nil
        for node in self.avatarHeaderNodes {
            node.removeFromSupernode()
        }
        self.avatarHeaderNodes.removeAll()

        self.applyWallpaper()
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }

    private func displayMessage(_ message: EngineMessage) -> EngineMessage {
        let rawMessage = message._asMessage()
        var attributes = rawMessage.attributes
        if !self.options.showReactions {
            attributes = attributes.filter { !($0 is ReactionsMessageAttribute) }
        }
        if self.options.revealSpoilers {
            attributes = attributes.map { attribute in
                if let entities = attribute as? TextEntitiesMessageAttribute {
                    return TextEntitiesMessageAttribute(entities: entities.entities.filter { entity in
                        if case .Spoiler = entity.type {
                            return false
                        }
                        return true
                    })
                }
                return attribute
            }
        }
        attributes.append(MessagePreviewForceIncomingAttribute())
        let flags = rawMessage.flags.union([.Incoming])
        var updatedMessage = rawMessage.withUpdatedFlags(flags).withUpdatedAttributes(attributes)
        if !self.options.showDateHeader {
            updatedMessage = updatedMessage.withUpdatedTimestamp(0)
        }
        return EngineMessage(updatedMessage)
    }

    private func updateMessagesLayout(layout: ContainerViewLayout, containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        let presentationData = self.effectivePresentationData
        let theme = presentationData.theme.withUpdated(preview: true)

        var items: [ListViewItem] = []
        for message in self.messages {
            let displayMessage = self.displayMessage(message)
            items.append(self.context.sharedContext.makeChatMessagePreviewItem(
                context: self.context,
                messages: [displayMessage._asMessage()],
                theme: theme,
                strings: presentationData.strings,
                wallpaper: presentationData.chatWallpaper,
                fontSize: presentationData.chatFontSize,
                chatBubbleCorners: presentationData.chatBubbleCorners,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameOrder: presentationData.nameDisplayOrder,
                forcedResourceStatus: nil,
                tapMessage: nil,
                clickThroughMessage: nil,
                backgroundNode: self.wallpaperBackgroundNode,
                availableReactions: nil,
                accountPeer: nil,
                isCentered: false,
                isPreview: true,
                isStandalone: false,
                rank: nil,
                rankRole: nil,
                alwaysDisplayAuthorInfo: self.options.showAvatar
            ))
        }

        let leftInset: CGFloat = self.options.showAvatar ? 37.0 : 0.0
        let width = containerSize.width
        let params = ListViewItemLayoutParams(width: width, leftInset: 0.0, rightInset: 0.0, availableHeight: layout.size.height)

        if let messageNodes = self.messageNodes {
            for i in 0 ..< items.count {
                let itemNode = messageNodes[i]
                let previousItem = i == items.count - 1 ? nil : items[i + 1]
                let nextItem = i == 0 ? nil : items[i - 1]
                items[i].updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, previousItem: previousItem, nextItem: nextItem, animation: .None, completion: { (itemLayout, apply) in
                    itemNode.contentSize = itemLayout.contentSize
                    itemNode.insets = itemLayout.insets
                    itemNode.frame = CGRect(origin: itemNode.frame.origin, size: CGSize(width: width, height: itemLayout.size.height))
                    itemNode.isUserInteractionEnabled = false
                    apply(ListViewItemApply(isOnScreen: true))
                })
            }
        } else {
            var messageNodes: [ListViewItemNode] = []
            for i in 0 ..< items.count {
                var itemNode: ListViewItemNode?
                let previousItem = i == items.count - 1 ? nil : items[i + 1]
                let nextItem = i == 0 ? nil : items[i - 1]
                items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: true, previousItem: previousItem, nextItem: nextItem, completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                if let itemNode {
                    itemNode.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                    itemNode.isUserInteractionEnabled = false
                    messageNodes.append(itemNode)
                    self.messagesContainerNode.addSubnode(itemNode)
                }
            }
            self.messageNodes = messageNodes
        }

        var bottomOffset: CGFloat = 10.0
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxY: CGFloat = 0.0
        if let messageNodes = self.messageNodes {
            for itemNode in messageNodes.reversed() {
                let itemFrame = CGRect(origin: CGPoint(x: leftInset, y: bottomOffset), size: itemNode.frame.size)
                transition.updateFrame(node: itemNode, frame: itemFrame)
                itemNode.updateFrame(itemFrame, within: layout.size)
                minY = min(minY, itemFrame.minY)
                maxY = max(maxY, itemFrame.maxY)
                bottomOffset += itemNode.frame.height
            }
        }

        if self.options.showAvatar, let messageNodes = self.messageNodes {
            var avatarMessages: [(index: Int, message: EngineMessage)] = []
            for index in self.messages.indices {
                let message = self.messages[index]
                guard message.author != nil else {
                    continue
                }
                let nextAuthorId = index + 1 < self.messages.count ? self.messages[index + 1].author?.id : nil
                if message.author?.id != nextAuthorId {
                    avatarMessages.append((index, message))
                }
            }

            if self.avatarHeaderNodes.count != avatarMessages.count {
                for node in self.avatarHeaderNodes {
                    node.removeFromSupernode()
                }
                self.avatarHeaderNodes.removeAll()
            }

            for avatarIndex in avatarMessages.indices {
                let avatarMessage = avatarMessages[avatarIndex]
                guard let author = avatarMessage.message.author else {
                    continue
                }
                let avatarHeaderItem = self.context.sharedContext.makeChatMessageAvatarHeaderItem(
                    context: self.context,
                    timestamp: avatarMessage.message.timestamp,
                    peer: author._asPeer(),
                    message: avatarMessage.message._asMessage(),
                    theme: theme,
                    strings: presentationData.strings,
                    wallpaper: presentationData.chatWallpaper,
                    fontSize: presentationData.chatFontSize,
                    chatBubbleCorners: presentationData.chatBubbleCorners,
                    dateTimeFormat: presentationData.dateTimeFormat,
                    nameOrder: presentationData.nameDisplayOrder
                )
                let avatarHeaderNode: ListViewItemHeaderNode
                if avatarIndex < self.avatarHeaderNodes.count {
                    avatarHeaderNode = self.avatarHeaderNodes[avatarIndex]
                    avatarHeaderItem.updateNode(avatarHeaderNode, previous: nil, next: avatarHeaderItem)
                } else {
                    avatarHeaderNode = avatarHeaderItem.node(synchronousLoad: true)
                    avatarHeaderNode.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                    self.messagesContainerNode.addSubnode(avatarHeaderNode)
                    self.avatarHeaderNodes.append(avatarHeaderNode)
                }

                let messageFrame = messageNodes[avatarMessage.index].frame
                let avatarFrame = CGRect(
                    origin: CGPoint(x: 0.0, y: messageFrame.minY - 7.0),
                    size: CGSize(width: width, height: avatarHeaderItem.height)
                )
                avatarHeaderNode.frame = avatarFrame
                avatarHeaderNode.updateLayout(size: containerSize, leftInset: 0.0, rightInset: 0.0, transition: .immediate)
                minY = min(minY, avatarFrame.minY)
                maxY = max(maxY, avatarFrame.maxY)
            }
        } else if !self.avatarHeaderNodes.isEmpty {
            for node in self.avatarHeaderNodes {
                node.removeFromSupernode()
            }
            self.avatarHeaderNodes.removeAll()
        }

        if self.options.showDateHeader, let firstMessage = self.messages.first {
            let headerItem = self.context.sharedContext.makeChatMessageDateHeaderItem(
                context: self.context,
                timestamp: firstMessage.timestamp,
                theme: theme,
                strings: presentationData.strings,
                wallpaper: presentationData.chatWallpaper,
                fontSize: presentationData.chatFontSize,
                chatBubbleCorners: presentationData.chatBubbleCorners,
                dateTimeFormat: presentationData.dateTimeFormat,
                nameOrder: presentationData.nameDisplayOrder
            )
            let dateHeaderNode: ListViewItemHeaderNode
            if let current = self.dateHeaderNode {
                dateHeaderNode = current
                headerItem.updateNode(dateHeaderNode, previous: nil, next: headerItem)
            } else {
                dateHeaderNode = headerItem.node(synchronousLoad: true)
                dateHeaderNode.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                self.messagesContainerNode.addSubnode(dateHeaderNode)
                self.dateHeaderNode = dateHeaderNode
            }
            let headerFrame = CGRect(origin: CGPoint(x: 0.0, y: bottomOffset), size: CGSize(width: width, height: headerItem.height))
            transition.updateFrame(node: dateHeaderNode, frame: headerFrame)
            dateHeaderNode.updateLayout(size: containerSize, leftInset: 0.0, rightInset: 0.0, transition: .immediate)
            maxY = max(maxY, headerFrame.maxY)
            bottomOffset += headerItem.height
        }

        if minY <= maxY {
            let height = maxY - minY
            self.messagesBoundingFrame = CGRect(x: 0.0, y: containerSize.height - maxY, width: containerSize.width, height: height)
        } else {
            self.messagesBoundingFrame = nil
        }
    }

    private func updatePanel(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        let strings = self.presentationData.strings.localFeatures.messageShot
        let theme = self.presentationData.theme
        let sideInset: CGFloat = 16.0 + layout.safeInsets.left
        let availableWidth = layout.size.width - sideInset * 2.0

        let titles: [MessageShotToggle: (String, Bool)] = [
            .wallpaper: (strings.showWallpaper, self.options.showWallpaper),
            .darkTheme: (strings.darkTheme, self.options.darkTheme),
            .avatar: (strings.showAvatar, self.options.showAvatar),
            .dateHeader: (strings.showTime, self.options.showDateHeader),
            .reactions: (strings.showReactions, self.options.showReactions),
            .spoilers: (strings.revealSpoilers, self.options.revealSpoilers)
        ]

        var x: CGFloat = sideInset
        var y: CGFloat = 12.0
        var rowHeight: CGFloat = 0.0
        for toggle in MessageShotToggle.allCases {
            guard let node = self.toggleNodes[toggle], let (title, isSelected) = titles[toggle] else {
                continue
            }
            let size = node.update(title: title, isSelected: isSelected, theme: theme)
            if x > sideInset && x + size.width > sideInset + availableWidth {
                x = sideInset
                y += size.height + 8.0
            }
            transition.updateFrame(node: node, frame: CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + 8.0
            rowHeight = size.height
        }
        y += rowHeight + 16.0

        let actionSpacing: CGFloat = 8.0
        let actionWidth = floor((availableWidth - actionSpacing * 2.0) / 3.0)
        let shareSize = self.shareNode.update(title: strings.share, isPrimary: true, width: actionWidth, theme: theme)
        let saveSize = self.saveNode.update(title: strings.saveToPhotos, isPrimary: false, width: actionWidth, theme: theme)
        let copySize = self.copyNode.update(title: strings.copy, isPrimary: false, width: availableWidth - actionWidth * 2.0 - actionSpacing * 2.0, theme: theme)
        transition.updateFrame(node: self.shareNode, frame: CGRect(origin: CGPoint(x: sideInset, y: y), size: shareSize))
        transition.updateFrame(node: self.saveNode, frame: CGRect(origin: CGPoint(x: sideInset + actionWidth + actionSpacing, y: y), size: saveSize))
        transition.updateFrame(node: self.copyNode, frame: CGRect(origin: CGPoint(x: sideInset + (actionWidth + actionSpacing) * 2.0, y: y), size: copySize))
        y += shareSize.height + 12.0

        return y + layout.intrinsicInsets.bottom
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)

        let panelHeight = self.updatePanel(layout: layout, transition: transition)
        let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - panelHeight), size: CGSize(width: layout.size.width, height: panelHeight))
        transition.updateFrame(node: self.panelNode, frame: panelFrame)
        transition.updateFrame(node: self.panelSeparatorNode, frame: CGRect(origin: panelFrame.origin, size: CGSize(width: layout.size.width, height: UIScreenPixel)))

        let previewFrame = CGRect(
            origin: CGPoint(x: 0.0, y: navigationBarHeight),
            size: CGSize(width: layout.size.width, height: max(1.0, panelFrame.minY - navigationBarHeight))
        )
        transition.updateFrame(node: self.previewContainerNode, frame: previewFrame)
        self.wallpaperBackgroundNode.frame = CGRect(origin: CGPoint(), size: previewFrame.size)
        self.wallpaperBackgroundNode.updateLayout(size: previewFrame.size, displayMode: .aspectFill, transition: transition)
        self.messagesContainerNode.frame = CGRect(origin: CGPoint(), size: previewFrame.size)

        self.updateMessagesLayout(layout: layout, containerSize: previewFrame.size, transition: transition)
    }

    private func renderImage() -> UIImage? {
        guard let boundingFrame = self.messagesBoundingFrame else {
            return nil
        }
        let padding: CGFloat = 8.0
        var cropFrame = boundingFrame.insetBy(dx: 0.0, dy: -padding)
        cropFrame = cropFrame.intersection(CGRect(origin: CGPoint(), size: self.previewContainerNode.frame.size))
        guard cropFrame.width > 1.0, cropFrame.height > 1.0 else {
            return nil
        }

        let scale: CGFloat = 3.0
        UIGraphicsBeginImageContextWithOptions(cropFrame.size, false, scale)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        context.translateBy(x: -cropFrame.minX, y: -cropFrame.minY)
        self.previewContainerNode.view.drawHierarchy(in: CGRect(origin: CGPoint(), size: self.previewContainerNode.frame.size), afterScreenUpdates: true)
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    @objc private func sharePressed() {
        guard let image = self.renderImage(), let data = image.pngData() else {
            return
        }
        let tempFilePath = NSTemporaryDirectory() + "message-shot-\(UInt32.random(in: 0 ..< UInt32.max)).png"
        let tempFileUrl = URL(fileURLWithPath: tempFilePath)
        try? FileManager.default.removeItem(at: tempFileUrl)
        try? data.write(to: tempFileUrl)

        let activityController = UIActivityViewController(activityItems: [tempFileUrl], applicationActivities: nil)
        if let window = self.view.window {
            activityController.popoverPresentationController?.sourceView = window
            activityController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
        }
        self.presentNativeController?(activityController)
    }

    @objc private func savePressed() {
        let strings = self.presentationData.strings.localFeatures.messageShot
        guard let image = self.renderImage() else {
            self.presentToast?(strings.saveFailed)
            return
        }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { [weak self] success, _ in
            Queue.mainQueue().async {
                self?.presentToast?(success ? strings.savedToPhotos : strings.saveFailed)
            }
        })
    }

    @objc private func copyPressed() {
        let strings = self.presentationData.strings.localFeatures.messageShot
        guard let image = self.renderImage() else {
            self.presentToast?(strings.saveFailed)
            return
        }
        UIPasteboard.general.image = image
        self.presentToast?(strings.copied)
    }
}

public final class MessageShotScreen: ViewController {
    private let context: AccountContext
    private let messages: [EngineMessage]
    private let wallpaper: TelegramWallpaper
    private var presentationData: PresentationData

    private var controllerNode: MessageShotScreenNode {
        return self.displayNode as! MessageShotScreenNode
    }

    public init(context: AccountContext, messages: [EngineMessage], wallpaper: TelegramWallpaper) {
        self.context = context
        self.messages = Array(messages.prefix(messageShotMessageLimit))
        self.wallpaper = wallpaper
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

        self.title = self.presentationData.strings.localFeatures.messageShot.title
        self.navigationPresentation = .modal
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))

        if messages.count > messageShotMessageLimit {
            let text = self.presentationData.strings.localFeatures.messageShot.selectionLimit(messageShotMessageLimit)
            Queue.mainQueue().after(0.3, { [weak self] in
                self?.presentToast(text)
            })
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        let controllerNode = MessageShotScreenNode(context: self.context, messages: self.messages, wallpaper: self.wallpaper)
        controllerNode.presentToast = { [weak self] text in
            self?.presentToast(text)
        }
        controllerNode.presentNativeController = { [weak self] controller in
            self?.context.sharedContext.applicationBindings.presentNativeController(controller)
        }
        self.displayNode = controllerNode
        self.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    private func presentToast(_ text: String) {
        self.present(UndoOverlayController(
            presentationData: self.presentationData,
            content: .info(title: nil, text: text, timeout: nil, customUndoText: nil),
            elevatedLayout: false,
            animateInAsReplacement: false,
            action: { _ in return false }
        ), in: .current)
    }

    @objc private func cancelPressed() {
        self.dismiss()
    }
}
