import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData

final class MadSettingsSearchController: ViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let items: [SettingsSearchableItem]
    private var results: [SettingsSearchableItem] = []
    private let searchBar = UISearchBar()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var seen = Set<String>()
        self.items = madgramSearchableItems(context: context).filter { item in
            guard !item.title.isEmpty, !seen.contains(item.title) else {
                return false
            }
            seen.insert(item.title)
            return true
        }.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })
        self.results = self.items
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = self.presentationData.strings.Common_Search
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        super.loadDisplayNode()
        let theme = self.presentationData.theme
        self.displayNode.backgroundColor = theme.list.blocksBackgroundColor
        self.searchBar.searchBarStyle = .minimal
        self.searchBar.placeholder = self.presentationData.strings.Common_Search
        self.searchBar.delegate = self
        self.searchBar.autocapitalizationType = .none
        self.searchBar.searchTextField.textColor = theme.list.itemPrimaryTextColor
        self.searchBar.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.view.addSubview(self.searchBar)
        self.tableView.backgroundColor = theme.list.blocksBackgroundColor
        self.tableView.separatorColor = theme.list.itemBlocksSeparatorColor
        self.tableView.keyboardDismissMode = .onDrag
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.view.addSubview(self.tableView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.searchBar.text?.isEmpty ?? true {
            self.searchBar.becomeFirstResponder()
        }
    }

    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        self.searchBar.frame = CGRect(x: layout.safeInsets.left + 8.0, y: top, width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - 16.0, height: 52.0)
        let tableTop = top + 52.0
        self.tableView.frame = CGRect(x: 0.0, y: tableTop, width: layout.size.width, height: layout.size.height - tableTop)
        self.tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(layout.intrinsicInsets.bottom, layout.inputHeight ?? 0.0), right: 0.0)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            self.results = self.items
        } else {
            let words = query.split(separator: " ").map(String.init)
            self.results = self.items.filter { item in
                let haystack = ([item.title] + item.alternate + item.breadcrumbs).joined(separator: " ").lowercased()
                return words.allSatisfy { haystack.contains($0) }
            }
        }
        self.tableView.reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let theme = self.presentationData.theme
        let item = self.results[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = theme.list.itemBlocksBackgroundColor
        let selected = UIView()
        selected.backgroundColor = theme.list.itemHighlightedBackgroundColor
        cell.selectedBackgroundView = selected
        cell.textLabel?.text = item.title
        cell.textLabel?.textColor = theme.list.itemPrimaryTextColor
        cell.textLabel?.numberOfLines = 2
        cell.detailTextLabel?.text = item.breadcrumbs.joined(separator: " → ")
        cell.detailTextLabel?.textColor = theme.list.itemSecondaryTextColor
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.searchBar.resignFirstResponder()
        let item = self.results[indexPath.row]
        let navigationController = self.navigationController as? NavigationController
        item.present(self.context, navigationController, { [weak self] presentation, controller in
            guard let self, let controller else {
                return
            }
            switch presentation {
            case .push:
                navigationController?.pushViewController(controller)
            case .modal:
                self.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            case .immediate:
                self.present(controller, in: .window(.root))
            case .dismiss:
                break
            }
        })
    }
}
