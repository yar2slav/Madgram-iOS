import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import PresentationDataUtils
import UndoUI
import MadgramAgent
import PhotosUI

public func agentChatController(context: AccountContext) -> ViewController {
    return AgentChatController(context: context)
}

public func agentTabController(context: AccountContext) -> ViewController {
    let controller = AgentChatController(context: context)
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = AgentStrings(languageCode: presentationData.strings.baseLanguageCode)
    let icon = UIImage(systemName: "sparkles", withConfiguration: UIImage.SymbolConfiguration(pointSize: 21.0, weight: .regular))?.withRenderingMode(.alwaysTemplate)
    controller.tabBarItem.title = strings.tabTitle
    controller.tabBarItem.image = icon
    controller.tabBarItem.selectedImage = icon
    controller.isTabInstance = true
    controller.updateInboxBadge()
    return controller
}

private enum AgentRow: Equatable {
    case user(id: String, text: String)
    case assistant(id: String, text: String, streaming: Bool)
    case tool(id: String, title: String, icon: String, state: AgentToolRowState)
    case thinking(String)
    case confirm(AgentPendingSend)
    case error(text: String, canRetry: Bool)

    var identity: String {
        switch self {
        case let .user(id, _):
            return "u" + id
        case let .assistant(id, _, _):
            return "a" + id
        case let .tool(id, _, _, _):
            return "t" + id
        case .thinking:
            return "thinking"
        case let .confirm(pending):
            return "c" + pending.id
        case .error:
            return "error"
        }
    }
}

private enum AgentToolRowState: Equatable {
    case running
    case done
    case failed
}

private struct AgentColors {
    let background: UIColor
    let text: UIColor
    let secondaryText: UIColor
    let accent: UIColor
    let userBubble: UIColor
    let userText: UIColor
    let chipBackground: UIColor
    let codeBackground: UIColor
    let destructive: UIColor
    let inputBackground: UIColor
    let inputFieldBackground: UIColor
    let separator: UIColor
    let isDark: Bool

    init(theme: PresentationTheme) {
        self.background = theme.list.plainBackgroundColor
        self.text = theme.list.itemPrimaryTextColor
        self.secondaryText = theme.list.itemSecondaryTextColor
        self.accent = theme.list.itemAccentColor
        self.userBubble = theme.list.itemAccentColor
        self.userText = theme.list.itemCheckColors.foregroundColor
        self.chipBackground = theme.list.itemBlocksBackgroundColor.mixedWith(theme.list.itemPrimaryTextColor, alpha: 0.06)
        self.codeBackground = theme.list.itemPrimaryTextColor.withAlphaComponent(0.07)
        self.destructive = theme.list.itemDestructiveColor
        self.inputBackground = theme.rootController.navigationBar.opaqueBackgroundColor
        self.inputFieldBackground = theme.list.itemPrimaryTextColor.withAlphaComponent(theme.overallDarkAppearance ? 0.1 : 0.06)
        self.separator = theme.list.itemPlainSeparatorColor
        self.isDark = theme.overallDarkAppearance
    }
}

private final class AgentUserCell: UITableViewCell {
    let bubble = UIView()
    let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.bubble.layer.cornerRadius = 18.0
        self.bubble.layer.cornerCurve = .continuous
        self.label.numberOfLines = 0
        self.label.font = UIFont.systemFont(ofSize: 17.0)
        self.contentView.addSubview(self.bubble)
        self.bubble.addSubview(self.label)
        self.bubble.translatesAutoresizingMaskIntoConstraints = false
        self.label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.bubble.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 6.0),
            self.bubble.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -6.0),
            self.bubble.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -14.0),
            self.bubble.leadingAnchor.constraint(greaterThanOrEqualTo: self.contentView.leadingAnchor, constant: 60.0),
            self.label.topAnchor.constraint(equalTo: self.bubble.topAnchor, constant: 9.0),
            self.label.bottomAnchor.constraint(equalTo: self.bubble.bottomAnchor, constant: -9.0),
            self.label.leadingAnchor.constraint(equalTo: self.bubble.leadingAnchor, constant: 14.0),
            self.label.trailingAnchor.constraint(equalTo: self.bubble.trailingAnchor, constant: -14.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class AgentAssistantCell: UITableViewCell {
    let textView = UITextView()
    private let caret = UIView()
    private var caretAnimating = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.textView.isEditable = false
        self.textView.isScrollEnabled = false
        self.textView.backgroundColor = .clear
        self.textView.textContainerInset = .zero
        self.textView.textContainer.lineFragmentPadding = 0.0
        self.textView.dataDetectorTypes = [.link]
        self.contentView.addSubview(self.textView)
        self.textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.textView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 8.0),
            self.textView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -8.0),
            self.textView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 18.0),
            self.textView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -18.0)
        ])
        self.caret.layer.cornerRadius = 1.5
        self.caret.isHidden = true
        self.contentView.addSubview(self.caret)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setStreaming(_ streaming: Bool, color: UIColor) {
        self.caret.backgroundColor = color
        self.caret.isHidden = !streaming
        if streaming && !self.caretAnimating {
            self.caretAnimating = true
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1.0
            animation.toValue = 0.15
            animation.duration = 0.55
            animation.autoreverses = true
            animation.repeatCount = .infinity
            self.caret.layer.add(animation, forKey: "blink")
        } else if !streaming && self.caretAnimating {
            self.caretAnimating = false
            self.caret.layer.removeAnimation(forKey: "blink")
        }
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !self.caret.isHidden else {
            return
        }
        let layoutManager = self.textView.layoutManager
        let length = self.textView.textStorage.length
        var rect = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 20.0)
        if length > 0 {
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: length - 1)
            let lineRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            rect = CGRect(x: lineRect.maxX, y: lineRect.minY, width: 0.0, height: lineRect.height)
        }
        let origin = self.textView.frame.origin
        self.caret.frame = CGRect(x: origin.x + rect.minX + 3.0, y: origin.y + rect.minY + 2.0, width: 3.0, height: max(14.0, rect.height - 4.0))
    }
}

private final class AgentToolCell: UITableViewCell {
    let chip = UIView()
    let icon = UIImageView()
    let label = UILabel()
    let spinner = UIActivityIndicatorView(style: .medium)
    let check = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.chip.layer.cornerRadius = 14.0
        self.chip.layer.cornerCurve = .continuous
        self.label.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        self.label.numberOfLines = 1
        self.label.lineBreakMode = .byTruncatingTail
        self.icon.contentMode = .scaleAspectFit
        self.check.contentMode = .scaleAspectFit
        self.contentView.addSubview(self.chip)
        for view in [self.icon, self.label, self.spinner, self.check] as [UIView] {
            self.chip.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        self.chip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.chip.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 3.0),
            self.chip.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -3.0),
            self.chip.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 16.0),
            self.chip.trailingAnchor.constraint(lessThanOrEqualTo: self.contentView.trailingAnchor, constant: -16.0),
            self.chip.heightAnchor.constraint(equalToConstant: 30.0),
            self.icon.leadingAnchor.constraint(equalTo: self.chip.leadingAnchor, constant: 10.0),
            self.icon.centerYAnchor.constraint(equalTo: self.chip.centerYAnchor),
            self.icon.widthAnchor.constraint(equalToConstant: 15.0),
            self.icon.heightAnchor.constraint(equalToConstant: 15.0),
            self.label.leadingAnchor.constraint(equalTo: self.icon.trailingAnchor, constant: 7.0),
            self.label.centerYAnchor.constraint(equalTo: self.chip.centerYAnchor),
            self.spinner.leadingAnchor.constraint(equalTo: self.label.trailingAnchor, constant: 8.0),
            self.spinner.centerYAnchor.constraint(equalTo: self.chip.centerYAnchor),
            self.spinner.trailingAnchor.constraint(equalTo: self.chip.trailingAnchor, constant: -10.0),
            self.check.leadingAnchor.constraint(equalTo: self.label.trailingAnchor, constant: 8.0),
            self.check.centerYAnchor.constraint(equalTo: self.chip.centerYAnchor),
            self.check.widthAnchor.constraint(equalToConstant: 13.0),
            self.check.heightAnchor.constraint(equalToConstant: 13.0)
        ])
        self.spinner.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class AgentThinkingCell: UITableViewCell {
    let icon = UIImageView()
    let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.label.font = UIFont.systemFont(ofSize: 15.0)
        self.icon.contentMode = .scaleAspectFit
        self.contentView.addSubview(self.icon)
        self.contentView.addSubview(self.label)
        self.icon.translatesAutoresizingMaskIntoConstraints = false
        self.label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.icon.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 18.0),
            self.icon.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            self.icon.widthAnchor.constraint(equalToConstant: 17.0),
            self.icon.heightAnchor.constraint(equalToConstant: 17.0),
            self.label.leadingAnchor.constraint(equalTo: self.icon.trailingAnchor, constant: 8.0),
            self.label.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 10.0),
            self.label.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -10.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startAnimating() {
        if self.icon.layer.animation(forKey: "pulse") != nil {
            return
        }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.3
        pulse.duration = 0.7
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        self.icon.layer.add(pulse, forKey: "pulse")
        self.label.layer.add(pulse, forKey: "pulse")
    }
}

private final class AgentConfirmCell: UITableViewCell {
    let card = UIView()
    let titleLabel = UILabel()
    let textLabel2 = UILabel()
    let quoteBar = UIView()
    let sendButton = UIButton(type: .system)
    let cancelButton = UIButton(type: .system)
    var send: (() -> Void)?
    var cancel: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.card.layer.cornerRadius = 16.0
        self.card.layer.cornerCurve = .continuous
        self.titleLabel.font = UIFont.systemFont(ofSize: 15.0, weight: .semibold)
        self.titleLabel.numberOfLines = 2
        self.textLabel2.font = UIFont.systemFont(ofSize: 16.0)
        self.textLabel2.numberOfLines = 0
        self.quoteBar.layer.cornerRadius = 1.5
        for button in [self.sendButton, self.cancelButton] {
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
            button.layer.cornerRadius = 12.0
            button.layer.cornerCurve = .continuous
        }
        self.sendButton.addTarget(self, action: #selector(self.sendPressed), for: .touchUpInside)
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), for: .touchUpInside)
        self.contentView.addSubview(self.card)
        for view in [self.titleLabel, self.quoteBar, self.textLabel2, self.sendButton, self.cancelButton] as [UIView] {
            self.card.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        self.card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.card.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 6.0),
            self.card.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -6.0),
            self.card.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 16.0),
            self.card.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -16.0),
            self.titleLabel.topAnchor.constraint(equalTo: self.card.topAnchor, constant: 14.0),
            self.titleLabel.leadingAnchor.constraint(equalTo: self.card.leadingAnchor, constant: 16.0),
            self.titleLabel.trailingAnchor.constraint(equalTo: self.card.trailingAnchor, constant: -16.0),
            self.quoteBar.leadingAnchor.constraint(equalTo: self.card.leadingAnchor, constant: 16.0),
            self.quoteBar.topAnchor.constraint(equalTo: self.textLabel2.topAnchor),
            self.quoteBar.bottomAnchor.constraint(equalTo: self.textLabel2.bottomAnchor),
            self.quoteBar.widthAnchor.constraint(equalToConstant: 3.0),
            self.textLabel2.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 10.0),
            self.textLabel2.leadingAnchor.constraint(equalTo: self.quoteBar.trailingAnchor, constant: 10.0),
            self.textLabel2.trailingAnchor.constraint(equalTo: self.card.trailingAnchor, constant: -16.0),
            self.cancelButton.topAnchor.constraint(equalTo: self.textLabel2.bottomAnchor, constant: 14.0),
            self.cancelButton.leadingAnchor.constraint(equalTo: self.card.leadingAnchor, constant: 12.0),
            self.cancelButton.heightAnchor.constraint(equalToConstant: 44.0),
            self.cancelButton.bottomAnchor.constraint(equalTo: self.card.bottomAnchor, constant: -12.0),
            self.sendButton.topAnchor.constraint(equalTo: self.cancelButton.topAnchor),
            self.sendButton.leadingAnchor.constraint(equalTo: self.cancelButton.trailingAnchor, constant: 10.0),
            self.sendButton.trailingAnchor.constraint(equalTo: self.card.trailingAnchor, constant: -12.0),
            self.sendButton.heightAnchor.constraint(equalToConstant: 44.0),
            self.sendButton.widthAnchor.constraint(equalTo: self.cancelButton.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func sendPressed() {
        self.send?()
    }

    @objc private func cancelPressed() {
        self.cancel?()
    }
}

private final class AgentErrorCell: UITableViewCell {
    let label = UILabel()
    let button = UIButton(type: .system)
    var retry: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.selectionStyle = .none
        self.label.font = UIFont.systemFont(ofSize: 15.0)
        self.label.numberOfLines = 0
        self.button.titleLabel?.font = UIFont.systemFont(ofSize: 15.0, weight: .semibold)
        self.button.addTarget(self, action: #selector(self.retryPressed), for: .touchUpInside)
        self.contentView.addSubview(self.label)
        self.contentView.addSubview(self.button)
        self.label.translatesAutoresizingMaskIntoConstraints = false
        self.button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.label.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 8.0),
            self.label.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 18.0),
            self.label.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -18.0),
            self.button.topAnchor.constraint(equalTo: self.label.bottomAnchor, constant: 2.0),
            self.button.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 18.0),
            self.button.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -6.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func retryPressed() {
        self.retry?()
    }
}

private final class AgentChatControllerNode: ASDisplayNode {
    override init() {
        super.init()
        self.setViewBlock({
            return UIView()
        })
    }
}

final class AgentChatController: ViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, PHPickerViewControllerDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let strings: AgentStrings
    private var colors: AgentColors
    private let executor: AgentToolExecutorImpl
    private let runner: AgentRunner

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputPanel = UIView()
    private let inputSeparator = UIView()
    private let inputField = UIView()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let sendButton = UIButton(type: .custom)
    private let attachButton = UIButton(type: .custom)
    private var pendingImage: (UIImage, AgentImage)?
    private let emptyView = UIView()
    private let emptyIcon = UIImageView()
    private let emptyTitle = UILabel()
    private let emptyText = UILabel()
    private let emptyStack = UIStackView()
    private let autoReplyBar = UIView()
    private let autoReplyLabel = UILabel()
    private let autoReplyStopButton = UIButton(type: .system)

    private var rows: [AgentRow] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    private var updateScheduled = false
    private var lastUpdate: CFTimeInterval = 0
    private var presentationDataDisposable: Disposable?
    private var settingsObserver: NSObjectProtocol?
    private var inboxObserver: NSObjectProtocol?
    fileprivate var isTabInstance = false
    private var isOnScreen = false

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.strings = AgentStrings(languageCode: self.presentationData.strings.baseLanguageCode)
        self.colors = AgentColors(theme: self.presentationData.theme)
        let executor = AgentToolExecutorImpl(context: context, strings: self.strings)
        self.executor = executor
        self.runner = AgentRunner(store: AgentConversationStore(accountId: context.account.peerId.toInt64()), executor: executor)

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

        self.title = self.strings.title
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationMoreCircledIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.morePressed))

        let accountPeerId = context.account.peerId
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountPeerId))
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let self, let peer else {
                return
            }
            self.runner.accountName = peer.compactDisplayTitle
        })

        self.runner.onUpdate = { [weak self] in
            self?.scheduleUpdate()
        }
        executor.pendingSendUpdated = { [weak self] _ in
            self?.scheduleUpdate(immediate: true)
        }

        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let self else {
                return
            }
            if self.presentationData.theme !== presentationData.theme {
                self.presentationData = presentationData
                self.colors = AgentColors(theme: presentationData.theme)
                self.applyTheme()
                self.tableView.reloadData()
            }
        })
        self.inboxObserver = NotificationCenter.default.addObserver(forName: AgentInbox.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
            guard let self else {
                return
            }
            if self.isOnScreen && UIApplication.shared.applicationState == .active {
                AgentInbox.markRead(accountId: self.context.account.peerId.toInt64())
            }
            self.updateInboxBadge()
        })
        self.settingsObserver = NotificationCenter.default.addObserver(forName: AgentSettingsStore.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
            guard let self else {
                return
            }
            self.updateInboxBadge()
            self.updateEmptyState()
            self.updateAutoReplyBar()
            if let (layout, navigationHeight) = self.validLayout {
                self.layout(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.2, curve: .easeInOut))
            }
        })
    }

    fileprivate func updateInboxBadge() {
        guard self.isTabInstance else {
            return
        }
        let count = AgentSettingsStore.shared.current.agentNotifications ? AgentInbox.unreadCount(accountId: self.context.account.peerId.toInt64()) : 0
        self.tabBarItem.badgeValue = count > 0 ? "\(count)" : ""
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.isOnScreen = true
        AgentInbox.markRead(accountId: self.context.account.peerId.toInt64())
        self.updateInboxBadge()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.isOnScreen = false
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.presentationDataDisposable?.dispose()
        if let inboxObserver = self.inboxObserver {
            NotificationCenter.default.removeObserver(inboxObserver)
        }
        if let settingsObserver = self.settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    override func loadDisplayNode() {
        self.displayNode = AgentChatControllerNode()
        self.displayNodeDidLoad()

        let view = self.displayNode.view
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.separatorStyle = .none
        self.tableView.backgroundColor = .clear
        self.tableView.keyboardDismissMode = .interactive
        self.tableView.estimatedRowHeight = 60.0
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.register(AgentUserCell.self, forCellReuseIdentifier: "user")
        self.tableView.register(AgentAssistantCell.self, forCellReuseIdentifier: "assistant")
        self.tableView.register(AgentToolCell.self, forCellReuseIdentifier: "tool")
        self.tableView.register(AgentThinkingCell.self, forCellReuseIdentifier: "thinking")
        self.tableView.register(AgentConfirmCell.self, forCellReuseIdentifier: "confirm")
        self.tableView.register(AgentErrorCell.self, forCellReuseIdentifier: "error")
        view.addSubview(self.tableView)

        self.emptyStack.axis = .vertical
        self.emptyStack.alignment = .center
        self.emptyStack.spacing = 10.0
        self.emptyIcon.contentMode = .scaleAspectFit
        self.emptyIcon.image = UIImage(systemName: "sparkles", withConfiguration: UIImage.SymbolConfiguration(pointSize: 44.0, weight: .regular))
        self.emptyTitle.font = UIFont.systemFont(ofSize: 22.0, weight: .bold)
        self.emptyTitle.textAlignment = .center
        self.emptyText.font = UIFont.systemFont(ofSize: 15.0)
        self.emptyText.textAlignment = .center
        self.emptyText.numberOfLines = 0
        self.emptyView.addSubview(self.emptyStack)
        self.emptyStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.emptyStack.leadingAnchor.constraint(equalTo: self.emptyView.leadingAnchor, constant: 32.0),
            self.emptyStack.trailingAnchor.constraint(equalTo: self.emptyView.trailingAnchor, constant: -32.0),
            self.emptyStack.centerYAnchor.constraint(equalTo: self.emptyView.centerYAnchor)
        ])
        view.addSubview(self.emptyView)

        self.inputPanel.addSubview(self.inputSeparator)
        self.inputField.layer.cornerRadius = 20.0
        self.inputField.layer.cornerCurve = .continuous
        self.inputPanel.addSubview(self.inputField)
        self.textView.font = UIFont.systemFont(ofSize: 17.0)
        self.textView.backgroundColor = .clear
        self.textView.textContainerInset = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 4.0)
        self.textView.delegate = self
        self.textView.isScrollEnabled = false
        self.inputField.addSubview(self.textView)
        self.placeholderLabel.font = UIFont.systemFont(ofSize: 17.0)
        self.placeholderLabel.text = self.strings.inputPlaceholder
        self.inputField.addSubview(self.placeholderLabel)
        self.sendButton.layer.cornerRadius = 16.0
        self.sendButton.addTarget(self, action: #selector(self.sendPressed), for: .touchUpInside)
        self.inputField.addSubview(self.sendButton)
        self.attachButton.layer.cornerRadius = 8.0
        self.attachButton.clipsToBounds = true
        self.attachButton.imageView?.contentMode = .scaleAspectFill
        self.attachButton.accessibilityLabel = self.strings.attachPhoto
        self.attachButton.addTarget(self, action: #selector(self.attachPressed), for: .touchUpInside)
        self.inputPanel.addSubview(self.attachButton)
        view.addSubview(self.inputPanel)

        self.autoReplyBar.layer.cornerRadius = 14.0
        self.autoReplyBar.layer.cornerCurve = .continuous
        self.autoReplyLabel.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        self.autoReplyLabel.lineBreakMode = .byTruncatingTail
        self.autoReplyStopButton.titleLabel?.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        self.autoReplyStopButton.addTarget(self, action: #selector(self.stopAutoReplies), for: .touchUpInside)
        self.autoReplyBar.addSubview(self.autoReplyLabel)
        self.autoReplyBar.addSubview(self.autoReplyStopButton)
        view.addSubview(self.autoReplyBar)

        self.applyTheme()
        self.rebuildRows(forceReload: true)
    }

    private func applyTheme() {
        guard self.isNodeLoaded else {
            return
        }
        self.displayNode.view.backgroundColor = self.colors.background
        self.inputPanel.backgroundColor = self.colors.inputBackground
        self.inputSeparator.backgroundColor = self.colors.separator
        self.inputField.backgroundColor = self.colors.inputFieldBackground
        self.textView.textColor = self.colors.text
        self.textView.tintColor = self.colors.accent
        self.textView.keyboardAppearance = self.colors.isDark ? .dark : .light
        self.placeholderLabel.textColor = self.colors.secondaryText
        self.emptyIcon.tintColor = self.colors.accent
        self.emptyTitle.textColor = self.colors.text
        self.emptyText.textColor = self.colors.secondaryText
        self.updateSendButton()
        self.updateEmptyState()
        self.autoReplyBar.backgroundColor = self.colors.chipBackground
        self.autoReplyLabel.textColor = self.colors.text
        self.autoReplyStopButton.setTitleColor(self.colors.destructive, for: .normal)
        self.updateAutoReplyBar()
    }

    private var activeAutoReplies: [AgentAutoReply] {
        return AgentSettingsStore.shared.current.autoReplies.filter { $0.isEnabled }
    }

    private func updateAutoReplyBar() {
        let active = self.activeAutoReplies
        self.autoReplyBar.isHidden = active.isEmpty
        if active.count == 1 {
            self.autoReplyLabel.text = self.strings.autoReplyBar(active[0].title)
        } else {
            self.autoReplyLabel.text = self.strings.autoReplyBarMany(active.count)
        }
        self.autoReplyStopButton.setTitle(active.count > 1 ? self.strings.autoReplyStopAll : self.strings.autoReplyStop, for: .normal)
    }

    @objc private func stopAutoReplies() {
        AgentSettingsStore.shared.update { settings in
            for index in settings.autoReplies.indices {
                settings.autoReplies[index].isEnabled = false
            }
        }
    }

    private func hasApiKey() -> Bool {
        #if DEBUG
        if AgentDemoScript.isActive {
            return true
        }
        #endif
        let settings = AgentSettingsStore.shared.current
        return AgentKeychain.apiKey(for: settings.provider) != nil
    }

    private func updateEmptyState() {
        for view in self.emptyStack.arrangedSubviews {
            self.emptyStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        self.emptyStack.addArrangedSubview(self.emptyIcon)
        self.emptyStack.addArrangedSubview(self.emptyTitle)
        self.emptyStack.addArrangedSubview(self.emptyText)
        self.emptyStack.setCustomSpacing(18.0, after: self.emptyText)
        self.emptyTitle.text = self.strings.emptyTitle
        if self.hasApiKey() {
            self.emptyText.text = self.strings.emptyText
            for suggestion in self.strings.suggestions {
                self.emptyStack.addArrangedSubview(self.makeSuggestionButton(title: suggestion, action: { [weak self] in
                    self?.runner.send(suggestion)
                }))
            }
        } else {
            self.emptyText.text = self.strings.emptyNoKeyText
            self.emptyStack.addArrangedSubview(self.makeSuggestionButton(title: self.strings.openSettings, action: { [weak self] in
                self?.openSettings()
            }))
        }
        self.emptyView.isHidden = !self.rows.isEmpty
    }

    private func makeSuggestionButton(title: String, action: @escaping () -> Void) -> UIView {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15.0, weight: .medium)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.setTitleColor(self.colors.accent, for: .normal)
        button.backgroundColor = self.colors.chipBackground
        button.layer.cornerRadius = 17.0
        button.layer.cornerCurve = .continuous
        button.contentEdgeInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 8.0, right: 16.0)
        button.addAction(UIAction(handler: { _ in action() }), for: .touchUpInside)
        return button
    }

    private func updateSendButton() {
        let running = self.runner.isRunning
        let hasText = !self.textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.pendingImage != nil
        if let (image, _) = self.pendingImage {
            self.attachButton.setImage(image, for: .normal)
            self.attachButton.tintColor = nil
        } else {
            self.attachButton.setImage(UIImage(systemName: "paperclip", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19.0, weight: .regular)), for: .normal)
            self.attachButton.tintColor = self.colors.secondaryText
        }
        let symbol = running ? "stop.fill" : "arrow.up"
        let configuration = UIImage.SymbolConfiguration(pointSize: running ? 12.0 : 15.0, weight: .bold)
        self.sendButton.setImage(UIImage(systemName: symbol, withConfiguration: configuration), for: .normal)
        self.sendButton.tintColor = .white
        let enabled = running || hasText
        self.sendButton.backgroundColor = enabled ? self.colors.accent : self.colors.secondaryText.withAlphaComponent(0.35)
        self.sendButton.isEnabled = enabled
    }

    private func toolIcon(_ name: String) -> String {
        switch name {
        case AgentToolName.listChats:
            return "list.bullet"
        case AgentToolName.searchChats:
            return "magnifyingglass"
        case AgentToolName.readChat:
            return "text.bubble"
        case AgentToolName.sendMessage:
            return "paperplane"
        default:
            return "wrench.and.screwdriver"
        }
    }

    private func computeRows() -> [AgentRow] {
        var rows: [AgentRow] = []
        let messages = self.runner.messages
        var results: [String: AgentMessage] = [:]
        for message in messages where message.role == .tool {
            if let id = message.toolCallId {
                results[id] = message
            }
        }
        for message in messages {
            switch message.role {
            case .user:
                let prefix = (message.images?.isEmpty == false) ? self.strings.photoPrefix : ""
                rows.append(.user(id: message.id, text: prefix + message.text))
            case .assistant:
                if !message.text.isEmpty {
                    rows.append(.assistant(id: message.id, text: message.text, streaming: false))
                }
                for call in message.toolCalls {
                    let state: AgentToolRowState
                    var title = self.executor.runningTitle(for: call)
                    #if DEBUG
                    if let demoTitle = AgentDemoScript.runningTitles[call.id] {
                        title = demoTitle
                    }
                    #endif
                    if let result = results[call.id] {
                        state = result.isError ? .failed : .done
                        if let resultTitle = result.toolTitle {
                            title = resultTitle
                        }
                    } else {
                        state = .running
                    }
                    rows.append(.tool(id: call.id, title: title, icon: self.toolIcon(call.name), state: state))
                }
            case .tool:
                break
            }
        }
        if !self.runner.streamingText.isEmpty {
            rows.append(.assistant(id: "streaming", text: self.runner.streamingText, streaming: true))
        } else if self.runner.isRunning && self.runner.activeToolCall == nil && self.executor.pendingSend == nil {
            let status: String
            switch self.runner.activeServerTool {
            case "web_search":
                status = self.strings.webSearching
            case "web_fetch":
                status = self.strings.webFetching
            default:
                status = self.strings.thinking
            }
            rows.append(.thinking(status))
        }
        if let pending = self.executor.pendingSend {
            rows.append(.confirm(pending))
        }
        if let error = self.runner.lastError, !self.runner.isRunning {
            rows.append(.error(text: error, canRetry: self.runner.canRetry))
        }
        return rows
    }

    private func scheduleUpdate(immediate: Bool = false) {
        if immediate || !self.runner.isRunning {
            self.rebuildRows(forceReload: false)
            return
        }
        if self.updateScheduled {
            return
        }
        let now = CACurrentMediaTime()
        let delay = max(0.0, 0.05 - (now - self.lastUpdate))
        self.updateScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else {
                return
            }
            self.updateScheduled = false
            self.rebuildRows(forceReload: false)
        }
    }

    private var isNearBottom: Bool {
        let offset = self.tableView.contentOffset.y
        let maxOffset = self.tableView.contentSize.height - self.tableView.bounds.height + self.tableView.contentInset.bottom
        return offset >= maxOffset - 80.0
    }

    private func rebuildRows(forceReload: Bool) {
        self.lastUpdate = CACurrentMediaTime()
        guard self.isNodeLoaded else {
            return
        }
        let newRows = self.computeRows()
        let wasNearBottom = self.isNearBottom || forceReload
        let oldRows = self.rows
        self.rows = newRows
        if !forceReload && oldRows.count == newRows.count && zip(oldRows, newRows).allSatisfy({ $0.identity == $1.identity }) {
            var changed = false
            for (index, (old, new)) in zip(oldRows, newRows).enumerated() where old != new {
                changed = true
                if let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) {
                    self.configure(cell: cell, row: new)
                }
            }
            if changed {
                UIView.performWithoutAnimation {
                    self.tableView.performBatchUpdates(nil)
                }
            }
        } else {
            self.tableView.reloadData()
        }
        self.emptyView.isHidden = !newRows.isEmpty
        self.updateSendButton()
        if wasNearBottom {
            self.scrollToBottom(animated: false)
        }
    }

    private func scrollToBottom(animated: Bool) {
        guard !self.rows.isEmpty else {
            return
        }
        self.tableView.layoutIfNeeded()
        let maxOffset = max(-self.tableView.contentInset.top, self.tableView.contentSize.height - self.tableView.bounds.height + self.tableView.contentInset.bottom)
        self.tableView.setContentOffset(CGPoint(x: 0.0, y: maxOffset), animated: animated)
    }

    private var markdownStyle: AgentMarkdownStyle {
        return AgentMarkdownStyle(fontSize: 17.0, textColor: self.colors.text, secondaryColor: self.colors.secondaryText, linkColor: self.colors.accent, codeBackground: self.colors.codeBackground)
    }

    private func configure(cell: UITableViewCell, row: AgentRow) {
        switch row {
        case let .user(_, text):
            guard let cell = cell as? AgentUserCell else {
                return
            }
            cell.bubble.backgroundColor = self.colors.userBubble
            cell.label.textColor = self.colors.userText
            cell.label.text = text
        case let .assistant(_, text, streaming):
            guard let cell = cell as? AgentAssistantCell else {
                return
            }
            cell.textView.attributedText = AgentMarkdown.render(text, style: self.markdownStyle)
            cell.textView.linkTextAttributes = [.foregroundColor: self.colors.accent]
            cell.textView.tintColor = self.colors.accent
            cell.setStreaming(streaming, color: self.colors.accent)
        case let .tool(_, title, icon, state):
            guard let cell = cell as? AgentToolCell else {
                return
            }
            cell.chip.backgroundColor = self.colors.chipBackground
            cell.icon.image = UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 13.0, weight: .semibold))
            cell.icon.tintColor = state == .failed ? self.colors.destructive : self.colors.accent
            cell.label.text = title
            cell.label.textColor = state == .failed ? self.colors.destructive : self.colors.text
            switch state {
            case .running:
                cell.spinner.color = self.colors.secondaryText
                cell.spinner.isHidden = false
                cell.spinner.startAnimating()
                cell.check.isHidden = true
            case .done, .failed:
                cell.spinner.stopAnimating()
                cell.spinner.isHidden = true
                cell.check.isHidden = false
                cell.check.image = UIImage(systemName: state == .done ? "checkmark" : "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11.0, weight: .bold))
                cell.check.tintColor = state == .done ? self.colors.secondaryText : self.colors.destructive
            }
        case let .thinking(status):
            guard let cell = cell as? AgentThinkingCell else {
                return
            }
            cell.icon.image = UIImage(systemName: "sparkles", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15.0, weight: .medium))
            cell.icon.tintColor = self.colors.accent
            cell.label.text = status
            cell.label.textColor = self.colors.secondaryText
            cell.startAnimating()
        case let .confirm(pending):
            guard let cell = cell as? AgentConfirmCell else {
                return
            }
            cell.card.backgroundColor = self.colors.chipBackground
            cell.titleLabel.text = pending.title ?? self.strings.confirmTitle(pending.chatTitle)
            cell.titleLabel.textColor = self.colors.text
            cell.textLabel2.text = pending.text
            cell.textLabel2.textColor = self.colors.text
            cell.quoteBar.backgroundColor = self.colors.accent
            cell.sendButton.setTitle(self.strings.send, for: .normal)
            cell.sendButton.setTitleColor(.white, for: .normal)
            cell.sendButton.backgroundColor = self.colors.accent
            cell.cancelButton.setTitle(self.strings.cancel, for: .normal)
            cell.cancelButton.setTitleColor(self.colors.accent, for: .normal)
            cell.cancelButton.backgroundColor = self.colors.accent.withAlphaComponent(0.12)
            cell.send = { [weak self] in
                self?.executor.resolvePendingSend(true)
            }
            cell.cancel = { [weak self] in
                self?.executor.resolvePendingSend(false)
            }
        case let .error(text, canRetry):
            guard let cell = cell as? AgentErrorCell else {
                return
            }
            cell.label.text = text
            cell.label.textColor = self.colors.destructive
            cell.button.setTitle(self.strings.retry, for: .normal)
            cell.button.setTitleColor(self.colors.accent, for: .normal)
            cell.button.isHidden = !canRetry
            cell.retry = { [weak self] in
                self?.runner.retry()
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = self.rows[indexPath.row]
        let identifier: String
        switch row {
        case .user:
            identifier = "user"
        case .assistant:
            identifier = "assistant"
        case .tool:
            identifier = "tool"
        case .thinking:
            identifier = "thinking"
        case .confirm:
            identifier = "confirm"
        case .error:
            identifier = "error"
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
        self.configure(cell: cell, row: row)
        return cell
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.row < self.rows.count else {
            return nil
        }
        let text: String
        switch self.rows[indexPath.row] {
        case let .user(_, value), let .assistant(_, value, _):
            text = value
        default:
            return nil
        }
        let strings = self.strings
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { [weak self] _ in
            return UIMenu(children: [
                UIAction(title: strings.copy, image: UIImage(systemName: "doc.on.doc"), handler: { _ in
                    UIPasteboard.general.string = text
                    guard let self else {
                        return
                    }
                    self.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: strings.copied), elevatedLayout: false, action: { _ in return false }), in: .current)
                })
            ])
        })
    }

    func textViewDidChange(_ textView: UITextView) {
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.updateSendButton()
        if let (layout, navigationHeight) = self.validLayout {
            self.layout(layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.15, curve: .easeInOut))
        }
    }

    @objc private func sendPressed() {
        if self.runner.isRunning {
            self.executor.cancelPendingSend()
            self.runner.stop()
            return
        }
        let text = self.textView.text ?? ""
        let images = self.pendingImage.flatMap { [$0.1] } ?? []
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty else {
            return
        }
        if !self.hasApiKey() {
            self.openSettings()
            return
        }
        self.textView.text = ""
        self.pendingImage = nil
        self.textViewDidChange(self.textView)
        self.runner.send(text, images: images)
        self.scrollToBottom(animated: true)
    }

    @objc private func attachPressed() {
        if self.pendingImage != nil {
            self.pendingImage = nil
            self.updateSendButton()
            return
        }
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        self.view.window?.rootViewController?.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        provider.loadObject(ofClass: UIImage.self, completionHandler: { [weak self] object, _ in
            guard let image = object as? UIImage, let encoded = AgentImageLoader.encode(image) else {
                return
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.pendingImage = (image, encoded)
                self.updateSendButton()
            }
        })
    }

    @objc private func morePressed() {
        let presentationData = self.presentationData
        let sheet = ActionSheetController(presentationData: presentationData)
        sheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.strings.newChat, action: { [weak self, weak sheet] in
                    sheet?.dismissAnimated()
                    self?.startNewChat()
                }),
                ActionSheetButtonItem(title: self.strings.chatHistory, action: { [weak self, weak sheet] in
                    sheet?.dismissAnimated()
                    self?.openHistory()
                }),
                ActionSheetButtonItem(title: self.strings.settingsTitle, action: { [weak self, weak sheet] in
                    sheet?.dismissAnimated()
                    self?.openSettings()
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak sheet] in
                    sheet?.dismissAnimated()
                })
            ])
        ])
        self.present(sheet, in: .window(.root))
    }

    private var accountId: Int64 {
        return self.context.account.peerId.toInt64()
    }

    private func showToast(_ text: String) {
        self.present(UndoOverlayController(presentationData: self.presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
    }

    private func startNewChat() {
        guard !self.runner.messages.isEmpty else {
            return
        }
        guard !self.runner.isRunning else {
            self.showToast(self.strings.waitForReply)
            return
        }
        self.executor.cancelPendingSend()
        let id = AgentConversations.create(accountId: self.accountId)
        self.runner.switchTo(AgentConversationStore(accountId: self.accountId, conversationId: id))
    }

    fileprivate func openConversation(_ id: String) -> Bool {
        if id == self.runner.store.conversationId {
            return true
        }
        guard !self.runner.isRunning else {
            self.showToast(self.strings.waitForReply)
            return false
        }
        self.executor.cancelPendingSend()
        AgentConversations.setCurrent(accountId: self.accountId, id: id)
        self.runner.switchTo(AgentConversationStore(accountId: self.accountId, conversationId: id))
        self.scrollToBottom(animated: false)
        return true
    }

    fileprivate func conversationDeleted(_ id: String) {
        guard id == self.runner.store.conversationId else {
            return
        }
        self.executor.cancelPendingSend()
        self.runner.stop()
        let current = AgentConversations.currentId(accountId: self.accountId)
        if !self.runner.switchTo(AgentConversationStore(accountId: self.accountId, conversationId: current)) {
            Queue.mainQueue().after(0.3) { [weak self] in
                guard let self else {
                    return
                }
                self.runner.switchTo(AgentConversationStore(accountId: self.accountId, conversationId: AgentConversations.currentId(accountId: self.accountId)))
            }
        }
    }

    private func openHistory() {
        self.view.endEditing(true)
        let controller = AgentHistoryController(context: self.context, strings: self.strings, currentId: { [weak self] in
            return self?.runner.store.conversationId
        }, open: { [weak self] id in
            return self?.openConversation(id) ?? false
        }, deleted: { [weak self] id in
            self?.conversationDeleted(id)
        }, newChat: { [weak self] in
            self?.startNewChat()
        })
        (self.navigationController as? NavigationController)?.pushViewController(controller)
    }

    private func openSettings() {
        self.view.endEditing(true)
        let controller = agentSettingsController(context: self.context, clearHistory: { [weak self] in
            self?.executor.cancelPendingSend()
            self?.runner.clear()
        })
        (self.navigationController as? NavigationController)?.pushViewController(controller)
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let navigationHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        let firstLayout = self.validLayout == nil
        self.validLayout = (layout, navigationHeight)
        self.layout(layout, navigationHeight: navigationHeight, transition: transition)
        if firstLayout {
            self.scrollToBottom(animated: false)
        }
    }

    private func layout(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let size = layout.size
        let sideInset = layout.safeInsets.left
        let keyboardHeight = layout.inputHeight ?? 0.0
        let bottomInset = max(layout.intrinsicInsets.bottom, keyboardHeight)

        let fieldWidth = size.width - sideInset - layout.safeInsets.right - 24.0 - 40.0
        let textWidth = fieldWidth - 44.0
        let fitted = self.textView.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
        let maxTextHeight: CGFloat = 140.0
        let textHeight = min(maxTextHeight, max(40.0, ceil(fitted.height)))
        self.textView.isScrollEnabled = fitted.height > maxTextHeight
        let fieldHeight = textHeight
        let panelHeight = fieldHeight + 16.0 + bottomInset

        let panelFrame = CGRect(x: 0.0, y: size.height - panelHeight, width: size.width, height: panelHeight)
        let wasNearBottom = self.isNearBottom
        transition.updateFrame(view: self.inputPanel, frame: panelFrame)
        self.inputSeparator.frame = CGRect(x: 0.0, y: 0.0, width: size.width, height: UIScreenPixel)
        let fieldFrame = CGRect(x: sideInset + 12.0 + 40.0, y: 8.0, width: fieldWidth, height: fieldHeight)
        self.attachButton.frame = CGRect(x: sideInset + 12.0, y: 8.0 + fieldHeight - 36.0, width: 34.0, height: 34.0)
        transition.updateFrame(view: self.inputField, frame: fieldFrame)
        self.textView.frame = CGRect(x: 0.0, y: 0.0, width: textWidth, height: fieldHeight)
        self.placeholderLabel.frame = CGRect(x: 15.0, y: 0.0, width: textWidth - 15.0, height: 40.0)
        self.sendButton.frame = CGRect(x: fieldWidth - 36.0, y: fieldHeight - 36.0, width: 32.0, height: 32.0)

        var topInset = navigationHeight
        if !self.autoReplyBar.isHidden {
            let barFrame = CGRect(x: sideInset + 12.0, y: navigationHeight + 6.0, width: size.width - sideInset - layout.safeInsets.right - 24.0, height: 40.0)
            transition.updateFrame(view: self.autoReplyBar, frame: barFrame)
            let buttonWidth = self.autoReplyStopButton.sizeThatFits(CGSize(width: 200.0, height: 40.0)).width + 24.0
            self.autoReplyStopButton.frame = CGRect(x: barFrame.width - buttonWidth, y: 0.0, width: buttonWidth, height: 40.0)
            self.autoReplyLabel.frame = CGRect(x: 14.0, y: 0.0, width: barFrame.width - buttonWidth - 14.0, height: 40.0)
            topInset = barFrame.maxY
        }

        let tableFrame = CGRect(x: 0.0, y: topInset, width: size.width, height: max(0.0, size.height - topInset))
        transition.updateFrame(view: self.tableView, frame: tableFrame)
        self.tableView.clipsToBounds = true
        self.tableView.contentInset = UIEdgeInsets(top: 8.0, left: 0.0, bottom: panelHeight + 8.0, right: 0.0)
        self.tableView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: panelHeight, right: 0.0)
        transition.updateFrame(view: self.emptyView, frame: CGRect(x: sideInset, y: navigationHeight, width: size.width - sideInset - layout.safeInsets.right, height: max(0.0, panelFrame.minY - navigationHeight)))
        if wasNearBottom {
            self.scrollToBottom(animated: false)
        }
    }
}
