import Foundation
import UIKit
import Display
import TelegramPresentationData
import AccountContext
import MadgramAgent

final class AgentHistoryController: ViewController, UITableViewDataSource, UITableViewDelegate {
    private let context: AccountContext
    private let strings: AgentStrings
    private var presentationData: PresentationData
    private let currentId: () -> String?
    private let open: (String) -> Bool
    private let deleted: (String) -> Void
    private let newChat: () -> Void
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()
    private var items: [AgentConversationInfo] = []
    private var observer: NSObjectProtocol?
    private let dateFormatter: DateFormatter

    init(context: AccountContext, strings: AgentStrings, currentId: @escaping () -> String?, open: @escaping (String) -> Bool, deleted: @escaping (String) -> Void, newChat: @escaping () -> Void) {
        self.context = context
        self.strings = strings
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.currentId = currentId
        self.open = open
        self.deleted = deleted
        self.newChat = newChat
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = Locale(identifier: self.presentationData.strings.baseLanguageCode)
        self.dateFormatter.doesRelativeDateFormatting = true
        self.dateFormatter.dateStyle = .short
        self.dateFormatter.timeStyle = .short
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = strings.chatHistory
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"), style: .plain, target: self, action: #selector(self.newPressed))
        self.observer = NotificationCenter.default.addObserver(forName: AgentConversations.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.reload()
        })
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func loadDisplayNode() {
        super.loadDisplayNode()
        let theme = self.presentationData.theme
        self.displayNode.backgroundColor = theme.list.blocksBackgroundColor
        self.tableView.backgroundColor = theme.list.blocksBackgroundColor
        self.tableView.separatorColor = theme.list.itemBlocksSeparatorColor
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        self.view.addSubview(self.tableView)
        self.emptyLabel.text = self.strings.chatHistoryEmpty
        self.emptyLabel.textColor = theme.list.freeTextColor
        self.emptyLabel.font = UIFont.systemFont(ofSize: 15.0)
        self.emptyLabel.textAlignment = .center
        self.view.addSubview(self.emptyLabel)
        self.reload()
    }

    private func reload() {
        self.items = AgentConversations.list(accountId: self.context.account.peerId.toInt64())
        self.emptyLabel.isHidden = !self.items.isEmpty
        if self.isViewLoaded {
            self.tableView.reloadData()
        }
    }

    @objc private func newPressed() {
        self.newChat()
        _ = (self.navigationController as? NavigationController)?.popViewController(animated: true)
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        self.tableView.frame = CGRect(x: 0.0, y: top, width: layout.size.width, height: layout.size.height - top)
        self.tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0)
        self.emptyLabel.frame = CGRect(x: 16.0, y: top + 40.0, width: layout.size.width - 32.0, height: 24.0)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let theme = self.presentationData.theme
        let item = self.items[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = theme.list.itemBlocksBackgroundColor
        let selected = UIView()
        selected.backgroundColor = theme.list.itemHighlightedBackgroundColor
        cell.selectedBackgroundView = selected
        cell.textLabel?.text = item.title.isEmpty ? self.strings.untitledChat : item.title
        cell.textLabel?.textColor = theme.list.itemPrimaryTextColor
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17.0)
        cell.detailTextLabel?.text = self.dateFormatter.string(from: item.updatedAt)
        cell.detailTextLabel?.textColor = theme.list.itemSecondaryTextColor
        cell.tintColor = theme.list.itemAccentColor
        cell.accessoryType = item.id == self.currentId() ? .checkmark : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = self.items[indexPath.row]
        if self.open(item.id) {
            _ = (self.navigationController as? NavigationController)?.popViewController(animated: true)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = self.items[indexPath.row]
        let action = UIContextualAction(style: .destructive, title: self.strings.deleteChat, handler: { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            AgentConversations.delete(accountId: self.context.account.peerId.toInt64(), id: item.id)
            self.deleted(item.id)
            completion(true)
        })
        return UISwipeActionsConfiguration(actions: [action])
    }
}
