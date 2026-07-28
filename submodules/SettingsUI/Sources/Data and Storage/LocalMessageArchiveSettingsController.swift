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
    let updateDeletedMessageMarker: (String) -> Void
    let toggleKeepAcrossLaunches: (Bool) -> Void
    let selectMediaLimit: () -> Void
    let selectDisappearingMediaLimit: () -> Void
    let clearMedia: () -> Void
    let clearArchive: () -> Void
    let showInfo: (String, UIView) -> Void

    init(
        toggleSaveDeletedMessages: @escaping (Bool) -> Void,
        toggleSaveEditedVersions: @escaping (Bool) -> Void,
        updateDeletedMessageMarker: @escaping (String) -> Void,
        toggleKeepAcrossLaunches: @escaping (Bool) -> Void,
        selectMediaLimit: @escaping () -> Void,
        selectDisappearingMediaLimit: @escaping () -> Void,
        clearMedia: @escaping () -> Void,
        clearArchive: @escaping () -> Void,
        showInfo: @escaping (String, UIView) -> Void
    ) {
        self.toggleSaveDeletedMessages = toggleSaveDeletedMessages
        self.toggleSaveEditedVersions = toggleSaveEditedVersions
        self.updateDeletedMessageMarker = updateDeletedMessageMarker
        self.toggleKeepAcrossLaunches = toggleKeepAcrossLaunches
        self.selectMediaLimit = selectMediaLimit
        self.selectDisappearingMediaLimit = selectDisappearingMediaLimit
        self.clearMedia = clearMedia
        self.clearArchive = clearArchive
        self.showInfo = showInfo
    }
}

private enum LocalMessageArchiveSection: Int32 {
    case settings
    case marker
    case storage
}

private enum LocalMessageArchiveEntry: ItemListNodeEntry {
    case saveDeletedMessages(Bool)
    case saveEditedVersions(Bool)
    case markerHeader(String)
    case marker(String)
    case markerInfo(String)
    case keepAcrossLaunches(Bool, Bool)
    case mediaLimit(String, Bool)
    case disappearingMediaLimit(String, Bool)
    case usage(String)
    case clearMedia
    case clearArchive

    var section: ItemListSectionId {
        switch self {
        case .saveDeletedMessages, .saveEditedVersions:
            return LocalMessageArchiveSection.settings.rawValue
        case .markerHeader, .marker, .markerInfo:
            return LocalMessageArchiveSection.marker.rawValue
        case .mediaLimit, .disappearingMediaLimit, .usage, .clearMedia, .clearArchive:
            return LocalMessageArchiveSection.storage.rawValue
        case .keepAcrossLaunches:
            return LocalMessageArchiveSection.settings.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .saveDeletedMessages:
            return 0
        case .saveEditedVersions:
            return 1
        case .markerHeader:
            return 2
        case .marker:
            return 3
        case .markerInfo:
            return 4
        case .keepAcrossLaunches:
            return 5
        case .mediaLimit:
            return 6
        case .disappearingMediaLimit:
            return 7
        case .usage:
            return 8
        case .clearMedia:
            return 9
        case .clearArchive:
            return 10
        }
    }

    static func == (lhs: LocalMessageArchiveEntry, rhs: LocalMessageArchiveEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.saveDeletedMessages(lhsValue), .saveDeletedMessages(rhsValue)):
            return lhsValue == rhsValue
        case let (.saveEditedVersions(lhsValue), .saveEditedVersions(rhsValue)):
            return lhsValue == rhsValue
        case let (.markerHeader(lhsText), .markerHeader(rhsText)), let (.marker(lhsText), .marker(rhsText)), let (.markerInfo(lhsText), .markerInfo(rhsText)):
            return lhsText == rhsText
        case let (.keepAcrossLaunches(lhsValue, lhsEnabled), .keepAcrossLaunches(rhsValue, rhsEnabled)):
            return lhsValue == rhsValue && lhsEnabled == rhsEnabled
        case let (.mediaLimit(lhsText, lhsEnabled), .mediaLimit(rhsText, rhsEnabled)):
            return lhsText == rhsText && lhsEnabled == rhsEnabled
        case let (.disappearingMediaLimit(lhsText, lhsEnabled), .disappearingMediaLimit(rhsText, rhsEnabled)):
            return lhsText == rhsText && lhsEnabled == rhsEnabled
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
            return ItemListDisclosureItem(presentationData: presentationData, title: strings.archiveUsage, label: value, sectionId: self.section, style: .blocks, action: nil)
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

    let settings = context.account.postbox.preferencesView(keys: [PreferencesKeys.deletedMessageArchiveSettings])
    |> map { view -> DeletedMessageArchiveSettings in
        return view.values[PreferencesKeys.deletedMessageArchiveSettings]?.get(DeletedMessageArchiveSettings.self) ?? .defaultSettings
    }
    let stats = Promise<DeletedMessageArchiveStats>()
    let refreshStats: () -> Void = {
        stats.set(context.engine.messages.deletedMessageArchiveStats())
    }
    refreshStats()

    let arguments = LocalMessageArchiveControllerArguments(
        toggleSaveDeletedMessages: { value in
            let _ = updateDeletedMessageArchiveSettingsInteractively(postbox: context.account.postbox, { current in
                var current = current
                current.saveDeletedMessages = value
                return current
            }).start()
        },
        toggleSaveEditedVersions: { value in
            let _ = updateDeletedMessageArchiveSettingsInteractively(postbox: context.account.postbox, { current in
                var current = current
                current.saveEditedVersions = value
                return current
            }).start()
        },
        updateDeletedMessageMarker: { value in
            let _ = updateDeletedMessageArchiveSettingsInteractively(postbox: context.account.postbox, { current in
                var current = current
                current.deletedMessageMarker = String(value.prefix(DeletedMessageArchiveSettings.deletedMessageMarkerLimit))
                return current
            }).start()
        },
        toggleKeepAcrossLaunches: { value in
            let _ = updateDeletedMessageArchiveSettingsInteractively(postbox: context.account.postbox, { current in
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
                    let _ = (updateDeletedMessageArchiveSettingsInteractively(postbox: context.account.postbox, { current in
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
                    let _ = (updateDeletedMessageArchiveSettingsInteractively(postbox: context.account.postbox, { current in
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
        let entries: [LocalMessageArchiveEntry] = [
            .saveDeletedMessages(settings.saveDeletedMessages),
            .saveEditedVersions(settings.saveEditedVersions),
            .markerHeader(strings.deletedMessageMarker.uppercased()),
            .marker(settings.deletedMessageMarker),
            .markerInfo(strings.deletedMessageMarkerInfo),
            .keepAcrossLaunches(settings.keepAcrossLaunches, archiveEnabled),
            .mediaLimit("\(settings.mediaLimitGigabytes) \(strings.gigabytesSuffix)", archiveEnabled),
            .disappearingMediaLimit("\(settings.disappearingMediaLimitGigabytes) \(strings.gigabytesSuffix)", archiveEnabled),
            .usage(usage),
            .clearMedia,
            .clearArchive
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
