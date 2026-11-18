import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import UndoUI
import MadgramText
import MadLockUI
import MadgramAgent
import UniformTypeIdentifiers

private final class MadSimpleArguments {
    let action: (Int32) -> Void
    let updateText: (String) -> Void
    let toggle: (Int32, Bool) -> Void

    init(action: @escaping (Int32) -> Void, updateText: @escaping (String) -> Void = { _ in }, toggle: @escaping (Int32, Bool) -> Void = { _, _ in }) {
        self.action = action
        self.updateText = updateText
        self.toggle = toggle
    }
}

private enum MadSimpleEntry: ItemListNodeEntry {
    case header(Int32, Int32, String)
    case input(Int32, Int32, String, String, Int)
    case info(Int32, Int32, String)
    case action(Int32, Int32, String, String, Bool)
    case toggle(Int32, Int32, String, Bool)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .input(_, section, _, _, _), let .info(_, section, _), let .action(_, section, _, _, _), let .toggle(_, section, _, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .input(id, _, _, _, _), let .info(id, _, _), let .action(id, _, _, _, _), let .toggle(id, _, _, _):
            return id
        }
    }

    static func <(lhs: MadSimpleEntry, rhs: MadSimpleEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    static func ==(lhs: MadSimpleEntry, rhs: MadSimpleEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.header(a, b, c), .header(d, e, f)), let (.info(a, b, c), .info(d, e, f)):
            return a == d && b == e && c == f
        case let (.input(a, b, c, _, g), .input(d, e, f, _, h)):
            return a == d && b == e && c == f && g == h
        case let (.action(a, b, c, x, y), .action(d, e, f, z, w)):
            return a == d && b == e && c == f && x == z && y == w
        case let (.toggle(a, b, c, x), .toggle(d, e, f, z)):
            return a == d && b == e && c == f && x == z
        default:
            return false
        }
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MadSimpleArguments
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .input(_, _, placeholder, text, _):
            return ItemListMultilineInputItem(presentationData: presentationData, text: text, placeholder: placeholder, maxLength: nil, sectionId: self.section, style: .blocks, capitalization: false, autocorrection: false, minimalHeight: 160.0, textUpdated: { value in
                arguments.updateText(value)
            })
        case let .info(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .action(id, _, title, label, destructive):
            if destructive {
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.action(id)
                })
            }
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.action(id)
            })
        case let .toggle(id, _, title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(id, value)
            })
        }
    }
}

private func madSimpleController(context: AccountContext, title: @escaping (MadgramMoreFeatureStrings) -> String, arguments: MadSimpleArguments, entries: Signal<[MadSimpleEntry], NoError>) -> ItemListController {
    let signal = combineLatest(context.sharedContext.presentationData, entries)
    |> map { presentationData, entries -> (ItemListControllerState, (ItemListNodeState, Any)) in
        return (
            ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text(title(presentationData.strings.localFeatures.more)),
                leftNavigationButton: nil,
                rightNavigationButton: nil,
                backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
                animateChanges: true
            ),
            (
                ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks),
                arguments
            )
        )
    }
    return ItemListController(context: context, state: signal)
}

func madHiddenRulesController(context: AccountContext) -> ViewController {
    let initialText = ChatContentFilterSettingsStore.shared.current.hiddenRulesSource
    let arguments = MadSimpleArguments(action: { _ in }, updateText: { text in
        ChatContentFilterSettingsStore.shared.update { current in
            var current = current
            current.hiddenRulesSource = text
            return current
        }
    })
    let entries = combineLatest(context.sharedContext.presentationData, chatContentFilterSettingsSignal())
    |> map { presentationData, settings -> [MadSimpleEntry] in
        let more = presentationData.strings.localFeatures.more
        var info = more.hiddenRulesInfo
        let errors = MadHideRuleSet(source: settings.hiddenRulesSource).errors
        if !errors.isEmpty {
            info = errors.map { more.hiddenRulesError($0.line, $0.message) }.joined(separator: "\n") + "\n\n" + info
        }
        return [
            .input(0, 0, more.hiddenRulesPlaceholder, initialText, 0),
            .info(1, 0, info)
        ]
    }
    return madSimpleController(context: context, title: { $0.hiddenRules }, arguments: arguments, entries: entries)
}

enum MadPeerListKind {
    case aliases
    case lockedChats
    case presence
}

func madPeerListController(context: AccountContext, kind: MadPeerListKind) -> ViewController {
    let store: MadJSONStore<Set<Int64>>?
    switch kind {
    case .aliases:
        store = nil
    case .lockedChats:
        store = MadStores.lockedChats
    case .presence:
        store = MadStores.presenceWatched
    }
    let ids: Signal<[Int64], NoError>
    if let store {
        ids = store.signal() |> map { Array($0).sorted() }
    } else {
        ids = MadStores.peerAliases.signal() |> map { Array($0.keys).sorted() }
    }
    var presentController: ((ViewController) -> Void)?
    let remove: (Int64) -> Void = { id in
        switch kind {
        case .aliases:
            MadStores.peerAliases.update { value in
                var value = value
                value.removeValue(forKey: id)
                return value
            }
        case .lockedChats:
            MadLock.requireUnlock(strings: context.sharedContext.currentPresentationData.with { $0 }.strings, completion: { success in
                if success {
                    MadStores.lockedChats.update { value in
                        var value = value
                        value.remove(id)
                        return value
                    }
                }
            })
        case .presence:
            MadStores.presenceWatched.update { value in
                var value = value
                value.remove(id)
                return value
            }
        }
    }
    let arguments = MadSimpleArguments(action: { index in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let _ = (ids |> take(1) |> deliverOnMainQueue).start(next: { list in
            let position = Int(index) - 10
            guard position >= 0 && position < list.count else {
                return
            }
            let peerId = list[position]
            let sheet = ActionSheetController(presentationData: presentationData)
            sheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.localFeatures.more.remove, color: .destructive, action: { [weak sheet] in
                        sheet?.dismissAnimated()
                        remove(peerId)
                    })
                ]),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { [weak sheet] in
                        sheet?.dismissAnimated()
                    })
                ])
            ])
            presentController?(sheet)
        })
    })
    let entries = combineLatest(context.sharedContext.presentationData, ids
    |> mapToSignal { list -> Signal<([Int64], [EnginePeer.Id: EnginePeer]), NoError> in
        return context.engine.data.get(EngineDataMap(list.map { TelegramEngine.EngineData.Item.Peer.Peer(id: EnginePeer.Id($0)) }))
        |> map { peers -> ([Int64], [EnginePeer.Id: EnginePeer]) in
            var result: [EnginePeer.Id: EnginePeer] = [:]
            for (key, value) in peers {
                if let value {
                    result[key] = value
                }
            }
            return (list, result)
        }
    })
    |> map { presentationData, data -> [MadSimpleEntry] in
        let more = presentationData.strings.localFeatures.more
        let (list, peers) = data
        var entries: [MadSimpleEntry] = []
        let aliases = MadStores.peerAliases.current
        for (index, id) in list.enumerated() {
            let peerId = EnginePeer.Id(id)
            var name = "\(id)"
            if let peer = peers[peerId] {
                switch peer {
                case let .user(user):
                    name = [user.firstName, user.lastName].compactMap { $0 }.joined(separator: " ")
                    if name.isEmpty, let username = user.addressName {
                        name = "@" + username
                    }
                case let .channel(channel):
                    name = channel.title
                case let .legacyGroup(group):
                    name = group.title
                default:
                    name = peer.compactDisplayTitle
                }
            }
            let label = kind == .aliases ? (aliases[id] ?? "") : ""
            entries.append(.action(Int32(10 + index), 0, name, label, false))
        }
        let empty: String
        let info: String
        switch kind {
        case .aliases:
            empty = more.localNamesEmpty
            info = more.localNamesInfo
        case .lockedChats:
            empty = more.lockedChatsEmpty
            info = more.localPasswordInfo
        case .presence:
            empty = more.presenceWatchedEmpty
            info = more.presenceWatchedInfo
        }
        if list.isEmpty {
            entries.append(.info(5, 0, empty))
        }
        entries.append(.info(100000, 0, info))
        return entries
    }
    let controller = madSimpleController(context: context, title: { more in
        switch kind {
        case .aliases:
            return more.localNames
        case .lockedChats:
            return more.lockedChats
        case .presence:
            return more.presenceWatched
        }
    }, arguments: arguments, entries: entries)
    presentController = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

func madLocalPasswordController(context: AccountContext) -> ViewController {
    let version = ValuePromise<Int>(0, ignoreRepeated: false)
    var counter = 0
    let bump = {
        counter += 1
        version.set(counter)
    }
    let strings = { context.sharedContext.currentPresentationData.with { $0 }.strings }
    let arguments = MadSimpleArguments(action: { id in
        switch id {
        case 1:
            MadLock.presentSetup(strings: strings(), completion: { _ in
                bump()
            })
        case 3:
            MadLock.removePassword(strings: strings(), completion: { _ in
                bump()
            })
        default:
            break
        }
    }, toggle: { id, value in
        if id == 2 {
            MadLock.setBiometricsEnabled(value)
            bump()
        }
    })
    let entries = combineLatest(context.sharedContext.presentationData, version.get())
    |> map { presentationData, _ -> [MadSimpleEntry] in
        let more = presentationData.strings.localFeatures.more
        var entries: [MadSimpleEntry] = []
        if MadLock.hasPassword {
            let kindTitle: String
            switch MadLock.kind {
            case .password:
                kindTitle = more.lockTypePassword
            case .pattern:
                kindTitle = more.lockTypePattern
            default:
                kindTitle = more.lockTypePin
            }
            entries.append(.action(1, 0, more.localPasswordChange, kindTitle, false))
            if MadLock.biometricsAvailable {
                entries.append(.toggle(2, 0, more.lockUseBiometrics, MadLock.biometricsEnabled))
            }
            entries.append(.action(3, 1, more.localPasswordRemove, "", true))
        } else {
            entries.append(.action(1, 0, more.localPasswordSet, "", false))
        }
        entries.append(.info(4, 1, more.localPasswordInfo))
        return entries
    }
    return madSimpleController(context: context, title: { $0.localPassword }, arguments: arguments, entries: entries)
}

func madTopViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first(where: { $0.rootViewController != nil })
    var top = window?.rootViewController
    while let presented = top?.presentedViewController, !presented.isBeingDismissed {
        top = presented
    }
    return top
}

enum MadSettingsBackup {
    static func exportFileURL() -> URL? {
        var settings: [String: Any] = [:]
        for key in MadStores.backupKeys {
            if let data = UserDefaults.standard.data(forKey: key), let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                settings[key] = object
            }
        }
        let root: [String: Any] = ["mad": 1, "settings": settings]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mad-settings-\(formatter.string(from: Date())).json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func importData(_ data: Data) -> Bool {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let settings = root["settings"] as? [String: Any] else {
            return false
        }
        var imported = false
        for key in MadStores.backupKeys {
            guard let object = settings[key], let value = try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed]) else {
                continue
            }
            UserDefaults.standard.set(value, forKey: key)
            imported = true
        }
        guard imported else {
            return false
        }
        let decoder = JSONDecoder()
        InterfaceTuningSettingsStore.shared.update { $0 }
        if let data = UserDefaults.standard.data(forKey: "chatContentFilterSettings.v1"), let value = try? decoder.decode(ChatContentFilterSettings.self, from: data) {
            ChatContentFilterSettingsStore.shared.update { _ in value }
        }
        let _ = MessageFilterSettingsStore.shared.update { $0 }
        let _ = LocalPremiumSettingsStore.shared.update { $0 }
        if let data = UserDefaults.standard.data(forKey: "madgram.agent.settings.v1"), let value = try? decoder.decode(AgentSettings.self, from: data) {
            AgentSettingsStore.shared.update { $0 = value }
        }
        MadStores.peerAliases.reload()
        MadStores.lockedChats.reload()
        MadStores.presenceWatched.reload()
        return true
    }
}

final class MadDocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    static var current: MadDocumentPickerDelegate?
    let completion: (URL?) -> Void

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.completion(urls.first)
        MadDocumentPickerDelegate.current = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.completion(nil)
        MadDocumentPickerDelegate.current = nil
    }
}

func madExportSettings() {
    guard let url = MadSettingsBackup.exportFileURL(), let top = madTopViewController() else {
        return
    }
    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    activity.popoverPresentationController?.sourceView = top.view
    activity.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1.0, height: 1.0)
    top.present(activity, animated: true)
}

func madImportSettings(completion: @escaping (Bool) -> Void) {
    guard let top = madTopViewController() else {
        return
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .plainText, .data])
    let delegate = MadDocumentPickerDelegate(completion: { url in
        guard let url else {
            return
        }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url) else {
            completion(false)
            return
        }
        completion(MadSettingsBackup.importData(data))
    })
    MadDocumentPickerDelegate.current = delegate
    picker.delegate = delegate
    top.present(picker, animated: true)
}

func madPresentOptions(context: AccountContext, present: (ViewController) -> Void, title: String, options: [(String, Bool)], selected: @escaping (Int) -> Void) {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let sheet = ActionSheetController(presentationData: presentationData)
    var items: [ActionSheetItem] = [ActionSheetTextItem(title: title)]
    for (index, option) in options.enumerated() {
        items.append(ActionSheetButtonItem(title: option.1 ? "✓ " + option.0 : option.0, action: { [weak sheet] in
            sheet?.dismissAnimated()
            selected(index)
        }))
    }
    sheet.setItemGroups([
        ActionSheetItemGroup(items: items),
        ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { [weak sheet] in
                sheet?.dismissAnimated()
            })
        ])
    ])
    present(sheet)
}
