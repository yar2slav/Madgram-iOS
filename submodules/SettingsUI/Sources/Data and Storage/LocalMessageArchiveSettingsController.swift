import AccountContext
import ComponentFlow
import Display
import Foundation
import ItemListUI
import PresentationDataUtils
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import UIKit

private final class LocalMessageArchiveControllerArguments {
    let toggleSaveDeletedMessages: (Bool) -> Void
    let toggleSaveEditedVersions: (Bool) -> Void
    let toggleSaveMessagesFromArchivedChats: (Bool) -> Void
    let updateDeletedMessageMarker: (String) -> Void
    let toggleKeepAcrossLaunches: (Bool) -> Void
    let selectMediaLimit: () -> Void
    let selectDisappearingMediaLimit: () -> Void
    let selectDeletedOpacity: () -> Void
    let toggleExclusion: (Int32, Bool) -> Void
    let clearMedia: () -> Void
    let clearArchive: () -> Void
    let showInfo: (String, UIView) -> Void

    init(
        toggleSaveDeletedMessages: @escaping (Bool) -> Void,
        toggleSaveEditedVersions: @escaping (Bool) -> Void,
        toggleSaveMessagesFromArchivedChats: @escaping (Bool) -> Void,
        updateDeletedMessageMarker: @escaping (String) -> Void,
        toggleKeepAcrossLaunches: @escaping (Bool) -> Void,
        selectMediaLimit: @escaping () -> Void,
        selectDisappearingMediaLimit: @escaping () -> Void,
        selectDeletedOpacity: @escaping () -> Void,
        toggleExclusion: @escaping (Int32, Bool) -> Void,
        clearMedia: @escaping () -> Void,
        clearArchive: @escaping () -> Void,
        showInfo: @escaping (String, UIView) -> Void
    ) {
        self.toggleSaveDeletedMessages = toggleSaveDeletedMessages
        self.toggleSaveEditedVersions = toggleSaveEditedVersions
        self.toggleSaveMessagesFromArchivedChats = toggleSaveMessagesFromArchivedChats
        self.updateDeletedMessageMarker = updateDeletedMessageMarker
        self.toggleKeepAcrossLaunches = toggleKeepAcrossLaunches
        self.selectMediaLimit = selectMediaLimit
        self.selectDisappearingMediaLimit = selectDisappearingMediaLimit
        self.selectDeletedOpacity = selectDeletedOpacity
        self.toggleExclusion = toggleExclusion
        self.clearMedia = clearMedia
        self.clearArchive = clearArchive
        self.showInfo = showInfo
    }
}

private enum LocalMessageArchiveSection: Int32 {
    case settings
    case exclusions
    case marker
    case storage
}

private enum LocalMessageArchiveEntry: ItemListNodeEntry {
    case saveHeader(String)
    case saveDeletedMessages(Bool)
    case saveEditedVersions(Bool)
    case saveMessagesFromArchivedChats(Bool)
    case keepAcrossLaunches(Bool, Bool)
    case exclusionsHeader(String)
    case exclusion(Int32, String, Bool, Bool)
    case exclusionsInfo(String)
    case markerHeader(String)
    case marker(String)
    case deletedOpacity(String, String, String)
    case markerInfo(String)
    case storageHeader(String)
    case mediaLimit(String, Bool)
    case disappearingMediaLimit(String, Bool)
    case usage(String)
    case clearMedia
    case clearArchive
    case storageInfo(String)

    var section: ItemListSectionId {
        switch self {
        case .saveHeader, .saveDeletedMessages, .saveEditedVersions, .saveMessagesFromArchivedChats, .keepAcrossLaunches:
            return LocalMessageArchiveSection.settings.rawValue
        case .exclusionsHeader, .exclusion, .exclusionsInfo:
            return LocalMessageArchiveSection.exclusions.rawValue
        case .markerHeader, .marker, .deletedOpacity, .markerInfo:
            return LocalMessageArchiveSection.marker.rawValue
        case .storageHeader, .mediaLimit, .disappearingMediaLimit, .usage, .clearMedia, .clearArchive, .storageInfo:
            return LocalMessageArchiveSection.storage.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .saveHeader:
            return 0
        case .saveDeletedMessages:
            return 1
        case .saveEditedVersions:
            return 2
        case .saveMessagesFromArchivedChats:
            return 3
        case .keepAcrossLaunches:
            return 4
        case .exclusionsHeader:
            return 20
        case let .exclusion(rawValue, _, _, _):
            let order: [Int32] = [DeletedMessageArchiveExclusions.privateChats.rawValue, DeletedMessageArchiveExclusions.groups.rawValue, DeletedMessageArchiveExclusions.channels.rawValue, DeletedMessageArchiveExclusions.bots.rawValue, DeletedMessageArchiveExclusions.savedMessages.rawValue]
            return 21 + Int32(order.firstIndex(of: rawValue) ?? order.count)
        case .exclusionsInfo:
            return 40
        case .markerHeader:
            return 105
        case .marker:
            return 106
        case .deletedOpacity:
            return 107
        case .markerInfo:
            return 108
        case .storageHeader:
            return 109
        case .mediaLimit:
            return 110
        case .disappearingMediaLimit:
            return 111
        case .usage:
            return 112
        case .clearMedia:
            return 113
        case .clearArchive:
            return 114
        case .storageInfo:
            return 115
        }
    }

    static func == (lhs: LocalMessageArchiveEntry, rhs: LocalMessageArchiveEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.saveDeletedMessages(lhsValue), .saveDeletedMessages(rhsValue)):
            return lhsValue == rhsValue
        case let (.saveEditedVersions(lhsValue), .saveEditedVersions(rhsValue)):
            return lhsValue == rhsValue
        case let (.saveMessagesFromArchivedChats(lhsValue), .saveMessagesFromArchivedChats(rhsValue)):
            return lhsValue == rhsValue
        case let (.saveHeader(lhsText), .saveHeader(rhsText)), let (.markerHeader(lhsText), .markerHeader(rhsText)), let (.marker(lhsText), .marker(rhsText)), let (.markerInfo(lhsText), .markerInfo(rhsText)), let (.storageHeader(lhsText), .storageHeader(rhsText)), let (.storageInfo(lhsText), .storageInfo(rhsText)):
            return lhsText == rhsText
        case let (.keepAcrossLaunches(lhsValue, lhsEnabled), .keepAcrossLaunches(rhsValue, rhsEnabled)):
            return lhsValue == rhsValue && lhsEnabled == rhsEnabled
        case let (.mediaLimit(lhsText, lhsEnabled), .mediaLimit(rhsText, rhsEnabled)):
            return lhsText == rhsText && lhsEnabled == rhsEnabled
        case let (.disappearingMediaLimit(lhsText, lhsEnabled), .disappearingMediaLimit(rhsText, rhsEnabled)):
            return lhsText == rhsText && lhsEnabled == rhsEnabled
        case let (.deletedOpacity(lhsTitle, lhsInfo, lhsValue), .deletedOpacity(rhsTitle, rhsInfo, rhsValue)):
            return lhsTitle == rhsTitle && lhsInfo == rhsInfo && lhsValue == rhsValue
        case let (.exclusionsHeader(lhsText), .exclusionsHeader(rhsText)), let (.exclusionsInfo(lhsText), .exclusionsInfo(rhsText)):
            return lhsText == rhsText
        case let (.exclusion(lhsRaw, lhsTitle, lhsValue, lhsEnabled), .exclusion(rhsRaw, rhsTitle, rhsValue, rhsEnabled)):
            return lhsRaw == rhsRaw && lhsTitle == rhsTitle && lhsValue == rhsValue && lhsEnabled == rhsEnabled
        case let (.usage(lhsText), .usage(rhsText)):
            return lhsText == rhsText
        case (.clearMedia, .clearMedia), (.clearArchive, .clearArchive):
            return true
        default:
            return false
        }
    }

    static func < (lhs: LocalMessageArchiveEntry, rhs: LocalMessageArchiveEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! LocalMessageArchiveControllerArguments
        let strings = presentationData.strings.localFeatures.localMessageArchive
        switch self {
        case let .saveHeader(text), let .storageHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .storageInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .saveDeletedMessages(value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: strings.archiveDeletedMessages,
                titleBadgeComponent: featureInfoBadgeComponent(color: presentationData.theme.list.itemAccentColor),
                titleBadgeAction: { sourceView in
                    arguments.showInfo(strings.archiveDeletedMessagesInfo, sourceView)
                },
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: arguments.toggleSaveDeletedMessages
            )
        case let .saveEditedVersions(value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: strings.archiveEditedMessages,
                titleBadgeComponent: featureInfoBadgeComponent(color: presentationData.theme.list.itemAccentColor),
                titleBadgeAction: { sourceView in
                    arguments.showInfo(strings.archiveEditedMessagesInfo, sourceView)
                },
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: arguments.toggleSaveEditedVersions
            )
        case let .saveMessagesFromArchivedChats(value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: strings.archiveChats,
                titleBadgeComponent: featureInfoBadgeComponent(color: presentationData.theme.list.itemAccentColor),
                titleBadgeAction: { sourceView in
                    arguments.showInfo(strings.archiveChatsInfo, sourceView)
                },
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: arguments.toggleSaveMessagesFromArchivedChats
            )
        case let .exclusionsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .exclusion(rawValue, title, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleExclusion(rawValue, value)
            })
        case let .exclusionsInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .markerHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .marker(value):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                title: NSAttributedString(),
                text: value,
                placeholder: DeletedMessageArchiveSettings.defaultDeletedMessageMarker,
                type: .regular(capitalization: true, autocorrection: false),
                returnKeyType: .done,
                clearType: .always,
                maxLength: DeletedMessageArchiveSettings.deletedMessageMarkerLimit,
                sectionId: self.section,
                textUpdated: arguments.updateDeletedMessageMarker,
                action: {}
            )
        case let .deletedOpacity(title, info, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: title,
                titleIcon: featureInfoIcon(color: presentationData.theme.list.itemAccentColor),
                titleIconAction: { sourceView in
                    arguments.showInfo(info, sourceView)
                },
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: arguments.selectDeletedOpacity
            )
        case let .markerInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .keepAcrossLaunches(value, enabled):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: strings.keepBetweenLaunches,
                titleBadgeComponent: featureInfoBadgeComponent(color: presentationData.theme.list.itemAccentColor),
                titleBadgeAction: { sourceView in
                    arguments.showInfo(strings.keepBetweenLaunchesInfo, sourceView)
                },
                value: value,
                enabled: enabled,
                sectionId: self.section,
                style: .blocks,
                updated: arguments.toggleKeepAcrossLaunches
            )
        case let .mediaLimit(value, enabled):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: strings.mediaLimit,
                enabled: enabled,
                titleIcon: featureInfoIcon(color: presentationData.theme.list.itemAccentColor),
                titleIconAction: { sourceView in
                    arguments.showInfo(strings.mediaLimitInfo, sourceView)
                },
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: arguments.selectMediaLimit
            )
        case let .disappearingMediaLimit(value, enabled):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: strings.disappearingMediaLimit,
                enabled: enabled,
                titleIcon: featureInfoIcon(color: presentationData.theme.list.itemAccentColor),
                titleIconAction: { sourceView in
                    arguments.showInfo(strings.disappearingMediaLimitInfo, sourceView)
                },
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: arguments.selectDisappearingMediaLimit
            )
        case let .usage(value):
            return ItemListDisclosureItem(presentationData: presentationData, title: strings.archiveUsage, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case .clearMedia:
            return ItemListActionItem(presentationData: presentationData, title: strings.clearMedia, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.clearMedia)
        case .clearArchive:
            return ItemListActionItem(presentationData: presentationData, title: strings.clearArchive, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: arguments.clearArchive)
        }
    }
}

public func localMessageArchiveSettingsController(context: AccountContext) -> ViewController {
    var presentController: ((ViewController) -> Void)?
    var presentTooltip: ((String, UIView) -> Void)?
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let initialStrings = presentationData.strings.localFeatures.localMessageArchive

    let settings = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.deletedMessageArchiveSettings))
    |> map { entry -> DeletedMessageArchiveSettings in
        return entry?.get(DeletedMessageArchiveSettings.self) ?? .defaultSettings
    }
    let stats = Promise<DeletedMessageArchiveStats>()
    let refreshStats: () -> Void = {
        stats.set(context.engine.messages.deletedMessageArchiveStats())
    }
    refreshStats()

    let arguments = LocalMessageArchiveControllerArguments(
        toggleSaveDeletedMessages: { value in
            let _ = context.engine.messages.updateDeletedMessageArchiveSettingsInteractively({ current in
                var current = current
                current.saveDeletedMessages = value
                return current
            }).start()
        },
        toggleSaveEditedVersions: { value in
            let _ = context.engine.messages.updateDeletedMessageArchiveSettingsInteractively({ current in
                var current = current
                current.saveEditedVersions = value
                return current
            }).start()
        },
        toggleSaveMessagesFromArchivedChats: { value in
            let _ = context.engine.messages.updateDeletedMessageArchiveSettingsInteractively({ current in
                var current = current
                current.saveMessagesFromArchivedChats = value
                return current
            }).start()
        },
        updateDeletedMessageMarker: { value in
            let _ = context.engine.messages.updateDeletedMessageArchiveSettingsInteractively({ current in
                var current = current
                current.deletedMessageMarker = String(value.prefix(DeletedMessageArchiveSettings.deletedMessageMarkerLimit))
                return current
            }).start()
        },
        toggleKeepAcrossLaunches: { value in
            let _ = context.engine.messages.updateDeletedMessageArchiveSettingsInteractively({ current in
                var current = current
                current.keepAcrossLaunches = value
                return current
            }).start()
        },
        selectMediaLimit: {
            let sheet = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = DeletedMessageArchiveSettings.allowedMediaLimitGigabytes.map { value in
                return ActionSheetButtonItem(title: "\(value) \(initialStrings.gigabytesSuffix)", action: { [weak sheet] in
                    sheet?.dismissAnimated()
                    let _ = (context.engine.messages.updateDeletedMessageArchiveSettingsInteractively({ current in
                        var current = current
                        current.mediaLimitGigabytes = value
                        return current
                    })
                    |> then(context.engine.messages.refreshDeletedMessageArchiveMediaLimit())).start(completed: {
                        refreshStats()
                    })
                })
            }
            items.append(ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak sheet] in
                sheet?.dismissAnimated()
            }))
            sheet.setItemGroups([ActionSheetItemGroup(items: items)])
            presentController?(sheet)
        },
        selectDisappearingMediaLimit: {
            let sheet = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = DeletedMessageArchiveSettings.allowedDisappearingMediaLimitGigabytes.map { value in
                return ActionSheetButtonItem(title: "\(value) \(initialStrings.gigabytesSuffix)", action: { [weak sheet] in
                    sheet?.dismissAnimated()
                    let _ = (context.engine.messages.updateDeletedMessageArchiveSettingsInteractively({ current in
                        var current = current
                        current.disappearingMediaLimitGigabytes = value
                        return current
                    })
                    |> then(context.engine.messages.refreshDeletedMessageArchiveMediaLimit())).start(completed: {
                        refreshStats()
                    })
                })
            }
            items.append(ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak sheet] in
                sheet?.dismissAnimated()
            }))
            sheet.setItemGroups([ActionSheetItemGroup(items: items)])
            presentController?(sheet)
        },
        selectDeletedOpacity: {
            let sheet = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = DeletedMessageArchiveSettings.allowedDeletedMessageOpacities.map { value in
                return ActionSheetButtonItem(title: "\(Int((value * 100.0).rounded()))%", action: { [weak sheet] in
                    sheet?.dismissAnimated()
                    let _ = context.engine.messages.updateDeletedMessageArchiveSettingsInteractively({ current in
                        var current = current
                        current.deletedMessageOpacity = value
                        return current
                    }).start()
                })
            }
            items.append(ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak sheet] in
                sheet?.dismissAnimated()
            }))
            sheet.setItemGroups([ActionSheetItemGroup(items: items)])
            presentController?(sheet)
        },
        toggleExclusion: { rawValue, value in
            let _ = context.engine.messages.updateDeletedMessageArchiveSettingsInteractively({ current in
                var current = current
                if value {
                    current.exclusions.insert(DeletedMessageArchiveExclusions(rawValue: rawValue))
                } else {
                    current.exclusions.remove(DeletedMessageArchiveExclusions(rawValue: rawValue))
                }
                return current
            }).start()
        },
        clearMedia: {
            let _ = context.engine.messages.clearDeletedMessageArchiveMedia().start(completed: {
                refreshStats()
            })
        },
        clearArchive: {
            let _ = context.engine.messages.clearDeletedMessageArchive().start(completed: {
                refreshStats()
            })
        },
        showInfo: { text, sourceView in
            presentTooltip?(text, sourceView)
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, settings, stats.get())
    |> map { presentationData, settings, stats -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = presentationData.strings.localFeatures.localMessageArchive
        let usage = strings.usage(
            stats.messageCount,
            stats.versionCount,
            dataSizeString(stats.mediaSize, formatting: DataSizeStringFormatting(presentationData: presentationData))
        )
        let archiveEnabled = settings.isEnabled
        let extras = presentationData.strings.localFeatures.extras
        let entries: [LocalMessageArchiveEntry] = [
            .saveHeader(strings.saveSection),
            .saveDeletedMessages(settings.saveDeletedMessages),
            .saveEditedVersions(settings.saveEditedVersions),
            .saveMessagesFromArchivedChats(settings.saveMessagesFromArchivedChats),
            .keepAcrossLaunches(settings.keepAcrossLaunches, archiveEnabled),
            .exclusionsHeader(extras.archiveExcludeHeader.uppercased()),
            .exclusion(DeletedMessageArchiveExclusions.privateChats.rawValue, extras.archiveExcludePrivateChats, settings.exclusions.contains(.privateChats), archiveEnabled),
            .exclusion(DeletedMessageArchiveExclusions.groups.rawValue, extras.archiveExcludeGroups, settings.exclusions.contains(.groups), archiveEnabled),
            .exclusion(DeletedMessageArchiveExclusions.channels.rawValue, extras.archiveExcludeChannels, settings.exclusions.contains(.channels), archiveEnabled),
            .exclusion(DeletedMessageArchiveExclusions.bots.rawValue, extras.archiveExcludeBots, settings.exclusions.contains(.bots), archiveEnabled),
            .exclusion(DeletedMessageArchiveExclusions.savedMessages.rawValue, extras.archiveExcludeSavedMessages, settings.exclusions.contains(.savedMessages), archiveEnabled),
            .exclusionsInfo(extras.archiveExcludeInfo),
            .markerHeader(strings.deletedMessageMarker.uppercased()),
            .marker(settings.deletedMessageMarker),
            .deletedOpacity(presentationData.strings.localFeatures.extras.deletedOpacity, presentationData.strings.localFeatures.extras.deletedOpacityInfo, "\(Int((settings.deletedMessageOpacity * 100.0).rounded()))%"),
            .markerInfo(strings.deletedMessageMarkerInfo),
            .storageHeader(strings.storageSection),
            .mediaLimit("\(settings.mediaLimitGigabytes) \(strings.gigabytesSuffix)", archiveEnabled),
            .disappearingMediaLimit("\(settings.disappearingMediaLimitGigabytes) \(strings.gigabytesSuffix)", archiveEnabled),
            .usage(usage),
            .clearMedia,
            .clearArchive,
            .storageInfo(strings.clearActionsInfo)
        ]
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(strings.title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: true
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentController = { [weak controller] child in
        controller?.present(child, in: .window(.root))
    }
    var currentTooltipController: TooltipController?
    presentTooltip = { [weak controller] text, sourceView in
        guard let controller else {
            return
        }
        currentTooltipController?.dismiss()
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        currentTooltipController = presentFeatureInfoTooltip(
            text: text,
            sourceView: sourceView,
            presentationData: presentationData,
            controller: controller
        )
    }
    return controller
}
