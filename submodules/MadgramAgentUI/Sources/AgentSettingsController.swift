import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import PresentationDataUtils
import UndoUI
import MadgramAgent
import TelegramUIPreferences

private final class AgentSettingsArguments {
    let selectProvider: (AgentProviderKind) -> Void
    let updateBaseUrl: (String) -> Void
    let updateApiKey: (String) -> Void
    let openModels: () -> Void
    let updatePersona: (String) -> Void
    let resetPersona: () -> Void
    let setAllowRead: (Bool) -> Void
    let setAllowSend: (Bool) -> Void
    let setSendWithoutConfirmation: (Bool) -> Void
    let setFlag: (WritableKeyPath<AgentSettings, Bool>, Bool) -> Void
    let setAutoReplyEnabled: (Int64, Bool) -> Void
    let clearAutoReplies: () -> Void
    let setAgentTab: (Bool) -> Void
    let clearHistory: () -> Void

    init(selectProvider: @escaping (AgentProviderKind) -> Void, updateBaseUrl: @escaping (String) -> Void, updateApiKey: @escaping (String) -> Void, openModels: @escaping () -> Void, updatePersona: @escaping (String) -> Void, resetPersona: @escaping () -> Void, setAllowRead: @escaping (Bool) -> Void, setAllowSend: @escaping (Bool) -> Void, setSendWithoutConfirmation: @escaping (Bool) -> Void, setAutoReplyEnabled: @escaping (Int64, Bool) -> Void, clearAutoReplies: @escaping () -> Void, setAgentTab: @escaping (Bool) -> Void, clearHistory: @escaping () -> Void) {
        self.setSendWithoutConfirmation = setSendWithoutConfirmation
        self.setFlag = { keyPath, value in
            AgentSettingsStore.shared.update { settings in
                settings[keyPath: keyPath] = value
            }
        }
        self.setAutoReplyEnabled = setAutoReplyEnabled
        self.clearAutoReplies = clearAutoReplies
        self.setAgentTab = setAgentTab
        self.selectProvider = selectProvider
        self.updateBaseUrl = updateBaseUrl
        self.updateApiKey = updateApiKey
        self.openModels = openModels
        self.updatePersona = updatePersona
        self.resetPersona = resetPersona
        self.setAllowRead = setAllowRead
        self.setAllowSend = setAllowSend
        self.clearHistory = clearHistory
    }
}

private enum AgentSettingsSection: Int32 {
    case tab
    case provider
    case connection
    case persona
    case access
    case extra
    case autoReply
    case history
}

private enum AgentSettingsEntry: ItemListNodeEntry {
    case providerHeader(String)
    case provider(Int32, AgentProviderKind, String, Bool)
    case providerInfo(String)
    case baseUrl(String, String, Int)
    case apiKey(String, String, Int)
    case model(String, String)
    case connectionInfo(String)
    case personaHeader(String)
    case persona(String, String, Int)
    case personaInfo(String)
    case personaReset(String)
    case accessHeader(String)
    case allowRead(String, Bool)
    case allowSend(String, Bool)
    case sendWithoutConfirmation(String, Bool)
    case accessInfo(String)
    case allowChatActions(String, Bool)
    case allowForwarding(String, Bool)
    case allowWebSearch(String, Bool)
    case autoReplyWebSearch(String, Bool)
    case autoReplyLiveStatus(String, Bool)
    case agentNotifications(String, Bool)
    case extraAccessInfo(String)
    case autoReplyHeader(String)
    case autoReply(Int32, Int64, String, String, Bool)
    case autoReplyEmpty(String)
    case autoReplyClear(String)
    case autoReplyInfo(String)
    case agentTab(String, Bool)
    case agentTabInfo(String)
    case clearHistory(String)

    var section: ItemListSectionId {
        switch self {
        case .providerHeader, .provider, .providerInfo:
            return AgentSettingsSection.provider.rawValue
        case .baseUrl, .apiKey, .model, .connectionInfo:
            return AgentSettingsSection.connection.rawValue
        case .personaHeader, .persona, .personaInfo, .personaReset:
            return AgentSettingsSection.persona.rawValue
        case .accessHeader, .allowRead, .allowSend, .sendWithoutConfirmation, .accessInfo:
            return AgentSettingsSection.access.rawValue
        case .allowChatActions, .allowForwarding, .allowWebSearch, .extraAccessInfo:
            return AgentSettingsSection.extra.rawValue
        case .autoReplyHeader, .autoReply, .autoReplyEmpty, .autoReplyClear, .autoReplyInfo, .autoReplyWebSearch, .autoReplyLiveStatus, .agentNotifications:
            return AgentSettingsSection.autoReply.rawValue
        case .agentTab, .agentTabInfo:
            return AgentSettingsSection.tab.rawValue
        case .clearHistory:
            return AgentSettingsSection.history.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .providerHeader:
            return 0
        case let .provider(index, _, _, _):
            return 1 + index
        case .providerInfo:
            return 9
        case .baseUrl:
            return 10
        case .apiKey:
            return 11
        case .model:
            return 12
        case .connectionInfo:
            return 13
        case .personaHeader:
            return 20
        case .persona:
            return 21
        case .personaInfo:
            return 22
        case .personaReset:
            return 23
        case .accessHeader:
            return 30
        case .allowRead:
            return 31
        case .allowSend:
            return 32
        case .sendWithoutConfirmation:
            return 33
        case .accessInfo:
            return 34
        case .allowChatActions:
            return 35
        case .allowForwarding:
            return 36
        case .allowWebSearch:
            return 37
        case .extraAccessInfo:
            return 38
        case .autoReplyHeader:
            return 40
        case let .autoReply(index, _, _, _, _):
            return 41 + index
        case .autoReplyEmpty:
            return 500
        case .autoReplyWebSearch:
            return 502
        case .autoReplyLiveStatus:
            return 503
        case .autoReplyClear:
            return 501
        case .agentNotifications:
            return 504
        case .autoReplyInfo:
            return 505
        case .agentTab:
            return -2
        case .agentTabInfo:
            return -1
        case .clearHistory:
            return 700
        }
    }

    static func <(lhs: AgentSettingsEntry, rhs: AgentSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    static func ==(lhs: AgentSettingsEntry, rhs: AgentSettingsEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.providerHeader(l), .providerHeader(r)), let (.providerInfo(l), .providerInfo(r)), let (.connectionInfo(l), .connectionInfo(r)), let (.personaHeader(l), .personaHeader(r)), let (.personaInfo(l), .personaInfo(r)), let (.personaReset(l), .personaReset(r)), let (.accessHeader(l), .accessHeader(r)), let (.accessInfo(l), .accessInfo(r)), let (.clearHistory(l), .clearHistory(r)), let (.autoReplyHeader(l), .autoReplyHeader(r)), let (.autoReplyEmpty(l), .autoReplyEmpty(r)), let (.autoReplyClear(l), .autoReplyClear(r)), let (.autoReplyInfo(l), .autoReplyInfo(r)), let (.agentTabInfo(l), .agentTabInfo(r)), let (.extraAccessInfo(l), .extraAccessInfo(r)):
            return l == r
        case let (.provider(li, lp, lt, lv), .provider(ri, rp, rt, rv)):
            return li == ri && lp == rp && lt == rt && lv == rv
        case let (.baseUrl(lt, _, lv), .baseUrl(rt, _, rv)), let (.apiKey(lt, _, lv), .apiKey(rt, _, rv)), let (.persona(lt, _, lv), .persona(rt, _, rv)):
            return lt == rt && lv == rv
        case let (.model(lt, ll), .model(rt, rl)):
            return lt == rt && ll == rl
        case let (.allowRead(lt, lv), .allowRead(rt, rv)), let (.allowSend(lt, lv), .allowSend(rt, rv)), let (.sendWithoutConfirmation(lt, lv), .sendWithoutConfirmation(rt, rv)), let (.agentTab(lt, lv), .agentTab(rt, rv)), let (.allowChatActions(lt, lv), .allowChatActions(rt, rv)), let (.allowForwarding(lt, lv), .allowForwarding(rt, rv)), let (.allowWebSearch(lt, lv), .allowWebSearch(rt, rv)), let (.autoReplyWebSearch(lt, lv), .autoReplyWebSearch(rt, rv)), let (.autoReplyLiveStatus(lt, lv), .autoReplyLiveStatus(rt, rv)), let (.agentNotifications(lt, lv), .agentNotifications(rt, rv)):
            return lt == rt && lv == rv
        case let (.autoReply(li, lp, lt, ls, lv), .autoReply(ri, rp, rt, rs, rv)):
            return li == ri && lp == rp && lt == rt && ls == rs && lv == rv
        default:
            return false
        }
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AgentSettingsArguments
        switch self {
        case let .providerHeader(text), let .accessHeader(text), let .personaHeader(text), let .autoReplyHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .provider(_, provider, title, value):
            return ItemListCheckboxItem(presentationData: presentationData, title: title, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectProvider(provider)
            })
        case let .providerInfo(text), let .connectionInfo(text), let .personaInfo(text), let .accessInfo(text), let .autoReplyInfo(text), let .agentTabInfo(text), let .autoReplyEmpty(text), let .extraAccessInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .baseUrl(placeholder, text, _):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), clearType: .always, sectionId: self.section, textUpdated: { value in
                arguments.updateBaseUrl(value)
            }, action: {})
        case let .apiKey(placeholder, text, _):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: text, placeholder: placeholder, type: .password, clearType: .always, sectionId: self.section, textUpdated: { value in
                arguments.updateApiKey(value)
            }, action: {})
        case let .model(title, label):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openModels()
            })
        case let .persona(placeholder, text, _):
            return ItemListMultilineInputItem(presentationData: presentationData, text: text, placeholder: placeholder, maxLength: nil, sectionId: self.section, style: .blocks, capitalization: true, autocorrection: true, minimalHeight: 120.0, textUpdated: { value in
                arguments.updatePersona(value)
            })
        case let .personaReset(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.resetPersona()
            })
        case let .allowRead(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.setAllowRead(value)
            })
        case let .allowSend(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.setAllowSend(value)
            })
        case let .sendWithoutConfirmation(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.setSendWithoutConfirmation(value)
            })
        case let .allowChatActions(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.setFlag(\.allowChatActions, value)
            })
        case let .allowForwarding(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.setFlag(\.allowForwarding, value)
            })
        case let .allowWebSearch(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.setFlag(\.allowWebSearch, value)
            })
        case let .autoReplyLiveStatus(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.setFlag(\.autoReplyLiveStatus, value)
            })
        case let .agentNotifications(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.setFlag(\.agentNotifications, value)
            })
        case let .autoReplyWebSearch(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.setFlag(\.autoReplyWebSearch, value)
            })
        case let .autoReply(_, peerId, title, scenario, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: scenario, value: value, maximumNumberOfLines: 2, sectionId: self.section, style: .blocks, updated: { value in
                arguments.setAutoReplyEnabled(peerId, value)
            })
        case let .autoReplyClear(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearAutoReplies()
            })
        case let .agentTab(title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.setAgentTab(value)
            })
        case let .clearHistory(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearHistory()
            })
        }
    }
}

private final class AgentSettingsState {
    var apiKeyText: String
    var baseUrlText: String
    var personaText: String
    var version = 0

    init(settings: AgentSettings) {
        self.apiKeyText = AgentKeychain.apiKey(for: settings.provider) ?? ""
        self.baseUrlText = settings.customBaseUrls[settings.provider.rawValue] ?? ""
        self.personaText = settings.persona
    }
}

func agentSettingsController(context: AccountContext, clearHistory: @escaping () -> Void) -> ViewController {
    let settingsPromise = ValuePromise<AgentSettings>(AgentSettingsStore.shared.current, ignoreRepeated: false)
    let versionPromise = ValuePromise<Int>(0, ignoreRepeated: false)
    let state = AgentSettingsState(settings: AgentSettingsStore.shared.current)

    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let observer = NotificationCenter.default.addObserver(forName: AgentSettingsStore.didChangeNotification, object: nil, queue: .main, using: { _ in
        settingsPromise.set(AgentSettingsStore.shared.current)
    })

    let bumpVersion = {
        state.version += 1
        versionPromise.set(state.version)
    }

    let arguments = AgentSettingsArguments(
        selectProvider: { provider in
            AgentSettingsStore.shared.update { settings in
                settings.provider = provider
            }
            let settings = AgentSettingsStore.shared.current
            state.apiKeyText = AgentKeychain.apiKey(for: provider) ?? ""
            state.baseUrlText = settings.customBaseUrls[provider.rawValue] ?? ""
            bumpVersion()
        },
        updateBaseUrl: { value in
            state.baseUrlText = value
            AgentSettingsStore.shared.update { settings in
                settings.customBaseUrls[settings.provider.rawValue] = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        },
        updateApiKey: { value in
            state.apiKeyText = value
            AgentKeychain.setApiKey(value, for: AgentSettingsStore.shared.current.provider)
        },
        openModels: {
            pushControllerImpl?(agentModelPickerController(context: context))
        },
        updatePersona: { value in
            state.personaText = value
            AgentSettingsStore.shared.update { settings in
                settings.persona = value
            }
        },
        resetPersona: {
            state.personaText = AgentSettings.defaultPersona
            AgentSettingsStore.shared.update { settings in
                settings.persona = AgentSettings.defaultPersona
            }
            bumpVersion()
        },
        setAllowRead: { value in
            AgentSettingsStore.shared.update { settings in
                settings.allowReadChats = value
            }
        },
        setAllowSend: { value in
            AgentSettingsStore.shared.update { settings in
                settings.allowSendMessages = value
            }
        },
        setSendWithoutConfirmation: { value in
            AgentSettingsStore.shared.update { settings in
                settings.sendWithoutConfirmation = value
            }
        },
        setAutoReplyEnabled: { peerId, value in
            AgentSettingsStore.shared.update { settings in
                if var entry = settings.autoReply(peerId: peerId) {
                    entry.isEnabled = value
                    settings.setAutoReply(entry)
                }
            }
        },
        clearAutoReplies: {
            AgentSettingsStore.shared.update { settings in
                settings.autoReplies = []
            }
        },
        setAgentTab: { value in
            InterfaceTuningSettingsStore.shared.update { current in
                var current = current
                current.showAgentTab = value
                return current
            }
            bumpVersion()
        },
        clearHistory: {
            clearHistory()
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let strings = AgentStrings(languageCode: presentationData.strings.baseLanguageCode)
            presentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: strings.clearHistoryDone, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }))
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, settingsPromise.get(), versionPromise.get())
    |> map { presentationData, settings, version -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = AgentStrings(languageCode: presentationData.strings.baseLanguageCode)
        var entries: [AgentSettingsEntry] = []
        entries.append(.agentTab(strings.agentTab, InterfaceTuningSettingsStore.shared.current.showAgentTab))
        entries.append(.agentTabInfo(strings.agentTabInfo))
        entries.append(.providerHeader(strings.providerSection))
        for (index, provider) in AgentProviderKind.allCases.enumerated() {
            entries.append(.provider(Int32(index), provider, strings.providerTitle(provider), settings.provider == provider))
        }
        entries.append(.providerInfo(strings.providerInfo))
        if settings.provider.isCustom {
            entries.append(.baseUrl(strings.baseUrlPlaceholder, state.baseUrlText, version))
        }
        entries.append(.apiKey(strings.apiKeyPlaceholder, state.apiKeyText, version))
        let model = settings.currentModel
        entries.append(.model(strings.model, model.isEmpty ? strings.modelNotSelected : model))
        entries.append(.connectionInfo(strings.apiKeyInfo))
        entries.append(.personaHeader(strings.personaSection))
        entries.append(.persona(strings.personaPlaceholder, state.personaText, version))
        entries.append(.personaInfo(strings.personaInfo))
        entries.append(.personaReset(strings.personaReset))
        entries.append(.accessHeader(strings.accessSection))
        entries.append(.allowRead(strings.allowRead, settings.allowReadChats))
        entries.append(.allowSend(strings.allowSend, settings.allowSendMessages))
        entries.append(.sendWithoutConfirmation(strings.sendWithoutConfirmation, settings.sendWithoutConfirmation))
        entries.append(.accessInfo(settings.sendWithoutConfirmation ? strings.sendWithoutConfirmationInfo : strings.accessInfo))
        entries.append(.allowChatActions(strings.allowChatActions, settings.allowChatActions))
        entries.append(.allowForwarding(strings.allowForwarding, settings.allowForwarding))
        entries.append(.allowWebSearch(strings.allowWebSearch, settings.allowWebSearch))
        entries.append(.extraAccessInfo(strings.extraAccessInfo))
        entries.append(.autoReplyHeader(strings.autoReplySection))
        if settings.autoReplies.isEmpty {
            entries.append(.autoReplyEmpty(strings.autoReplyEmpty))
        } else {
            for (index, entry) in settings.autoReplies.enumerated() {
                entries.append(.autoReply(Int32(index), entry.peerId, entry.title, entry.scenario, entry.isEnabled))
            }
            entries.append(.autoReplyClear(strings.autoReplyClear))
        }
        entries.append(.autoReplyWebSearch(strings.autoReplyWebSearch, settings.autoReplyWebSearch))
        entries.append(.autoReplyLiveStatus(strings.autoReplyLiveStatus, settings.autoReplyLiveStatus))
        entries.append(.agentNotifications(strings.agentNotifications, settings.agentNotifications))
        entries.append(.autoReplyInfo(strings.autoReplyInfo))
        entries.append(.clearHistory(strings.clearHistory))

        return (
            ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.settingsTitle), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)),
            (ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, animateChanges: false), arguments)
        )
    }
    |> afterDisposed {
        NotificationCenter.default.removeObserver(observer)
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .current)
    }
    return controller
}

private enum AgentModelsState: Equatable {
    case loading
    case loaded([AgentModelInfo])
    case failed(String)
    case needKey
}

private final class AgentModelArguments {
    let select: (String) -> Void
    let updateManual: (String) -> Void

    init(select: @escaping (String) -> Void, updateManual: @escaping (String) -> Void) {
        self.select = select
        self.updateManual = updateManual
    }
}

private enum AgentModelEntry: ItemListNodeEntry {
    case manualHeader(String)
    case manual(String, String, Int)
    case manualInfo(String)
    case modelsHeader(String)
    case status(String)
    case model(Int32, String, String?, Bool)

    var section: ItemListSectionId {
        switch self {
        case .manualHeader, .manual, .manualInfo:
            return 0
        case .modelsHeader, .status, .model:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case .manualHeader:
            return 0
        case .manual:
            return 1
        case .manualInfo:
            return 2
        case .modelsHeader:
            return 3
        case .status:
            return 4
        case let .model(index, _, _, _):
            return 10 + index
        }
    }

    static func <(lhs: AgentModelEntry, rhs: AgentModelEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    static func ==(lhs: AgentModelEntry, rhs: AgentModelEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.manualHeader(l), .manualHeader(r)), let (.manualInfo(l), .manualInfo(r)), let (.modelsHeader(l), .modelsHeader(r)), let (.status(l), .status(r)):
            return l == r
        case let (.manual(lp, _, lv), .manual(rp, _, rv)):
            return lp == rp && lv == rv
        case let (.model(li, lid, ln, lv), .model(ri, rid, rn, rv)):
            return li == ri && lid == rid && ln == rn && lv == rv
        default:
            return false
        }
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AgentModelArguments
        switch self {
        case let .manualHeader(text), let .modelsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .manual(placeholder, text, _):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), clearType: .always, sectionId: self.section, textUpdated: { value in
                arguments.updateManual(value)
            }, action: {})
        case let .manualInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .status(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .model(_, id, name, selected):
            return ItemListCheckboxItem(presentationData: presentationData, title: id, subtitle: (name != nil && name != id) ? name : nil, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.select(id)
            })
        }
    }
}

private func agentModelPickerController(context: AccountContext) -> ViewController {
    let settings = AgentSettingsStore.shared.current
    let statePromise = ValuePromise<AgentModelsState>(.loading, ignoreRepeated: true)
    let selectedPromise = ValuePromise<String>(settings.currentModel, ignoreRepeated: true)
    let versionPromise = ValuePromise<Int>(0, ignoreRepeated: false)
    let manualText = Atomic<String>(value: settings.currentModel)
    let version = Atomic<Int>(value: 0)

    let setModel: (String) -> Void = { model in
        AgentSettingsStore.shared.update { settings in
            settings.models[settings.provider.rawValue] = model
        }
        selectedPromise.set(model)
    }

    let arguments = AgentModelArguments(
        select: { model in
            setModel(model)
            let _ = manualText.swap(model)
            versionPromise.set(version.modify { $0 + 1 })
        },
        updateManual: { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let _ = manualText.swap(trimmed)
            setModel(trimmed)
        }
    )

    if let apiKey = AgentKeychain.apiKey(for: settings.provider) {
        Task { @MainActor in
            do {
                let client = try makeAgentClient(settings: settings, apiKey: apiKey)
                let models = try await client.listModels()
                statePromise.set(.loaded(models))
            } catch {
                statePromise.set(.failed(error.localizedDescription))
            }
        }
    } else {
        statePromise.set(.needKey)
    }

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), selectedPromise.get(), versionPromise.get())
    |> map { presentationData, modelsState, selected, currentVersion -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = AgentStrings(languageCode: presentationData.strings.baseLanguageCode)
        var entries: [AgentModelEntry] = []
        entries.append(.manualHeader(strings.modelManual))
        entries.append(.manual(strings.modelManualPlaceholder, manualText.with { $0 }, currentVersion))
        entries.append(.manualInfo(strings.modelManualInfo))
        entries.append(.modelsHeader(strings.modelsSection))
        switch modelsState {
        case .loading:
            entries.append(.status(strings.modelsLoading))
        case .needKey:
            entries.append(.status(strings.modelsNeedKey))
        case let .failed(error):
            entries.append(.status(strings.modelsFailed(error)))
        case let .loaded(models):
            for (index, model) in models.prefix(400).enumerated() {
                entries.append(.model(Int32(index), model.id, model.displayName, model.id == selected))
            }
        }
        return (
            ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.modelsTitle), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)),
            (ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, animateChanges: false), arguments)
        )
    }

    return ItemListController(context: context, state: signal)
}
