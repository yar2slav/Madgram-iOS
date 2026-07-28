import AccountContext
import Display
import Foundation
import ItemListUI
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import UIKit

private final class MadgramControllerArguments {
    let openGhostMode: () -> Void
    let openMessageFilters: () -> Void
    let openLocalMessageArchive: () -> Void
    let openInterfaceTuning: () -> Void
    let setLocalPremium: (Bool) -> Void
    let setPowerSaving: (Bool) -> Void
    let showInfo: (String, UIView) -> Void

    init(
        openGhostMode: @escaping () -> Void,
        openMessageFilters: @escaping () -> Void,
        openLocalMessageArchive: @escaping () -> Void,
        openInterfaceTuning: @escaping () -> Void,
        setLocalPremium: @escaping (Bool) -> Void,
        setPowerSaving: @escaping (Bool) -> Void,
        showInfo: @escaping (String, UIView) -> Void
    ) {
        self.openGhostMode = openGhostMode
        self.openMessageFilters = openMessageFilters
        self.openLocalMessageArchive = openLocalMessageArchive
        self.openInterfaceTuning = openInterfaceTuning
        self.setLocalPremium = setLocalPremium
        self.setPowerSaving = setPowerSaving
        self.showInfo = showInfo
    }
}

private enum MadgramSection: Int32 {
    case features
    case power
    case premium
}

private enum MadgramEntry: ItemListNodeEntry {
    case featuresHeader(String)
    case ghostMode(String, String)
    case messageFilters(String)
    case localMessageArchive(String)
    case interfaceTuning(String)
    case featuresInfo(String)
    case powerHeader(String)
    case powerSaving(String, String, Bool)
    case powerInfo(String)
    case premiumHeader(String)
    case localPremium(String, String, Bool)
    case premiumInfo(String)

    var section: ItemListSectionId {
        switch self {
        case .featuresHeader, .ghostMode, .messageFilters, .localMessageArchive, .interfaceTuning, .featuresInfo:
            return MadgramSection.features.rawValue
        case .powerHeader, .powerSaving, .powerInfo:
            return MadgramSection.power.rawValue
        case .premiumHeader, .localPremium, .premiumInfo:
            return MadgramSection.premium.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .featuresHeader: return 0
        case .ghostMode: return 1
        case .messageFilters: return 2
        case .localMessageArchive: return 3
        case .interfaceTuning: return 4
        case .featuresInfo: return 5
        case .powerHeader: return 6
        case .powerSaving: return 7
        case .powerInfo: return 8
        case .premiumHeader: return 10
        case .localPremium: return 11
        case .premiumInfo: return 12
        }
    }

    static func ==(lhs: MadgramEntry, rhs: MadgramEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.featuresHeader(lhsText), .featuresHeader(rhsText)),
             let (.messageFilters(lhsText), .messageFilters(rhsText)),
             let (.localMessageArchive(lhsText), .localMessageArchive(rhsText)),
             let (.interfaceTuning(lhsText), .interfaceTuning(rhsText)),
             let (.featuresInfo(lhsText), .featuresInfo(rhsText)),
             let (.powerHeader(lhsText), .powerHeader(rhsText)),
             let (.powerInfo(lhsText), .powerInfo(rhsText)),
             let (.premiumHeader(lhsText), .premiumHeader(rhsText)),
             let (.premiumInfo(lhsText), .premiumInfo(rhsText)):
            return lhsText == rhsText
        case let (.ghostMode(lhsText, lhsValue), .ghostMode(rhsText, rhsValue)):
            return lhsText == rhsText && lhsValue == rhsValue
        case let (.localPremium(lhsText, lhsInfo, lhsValue), .localPremium(rhsText, rhsInfo, rhsValue)),
             let (.powerSaving(lhsText, lhsInfo, lhsValue), .powerSaving(rhsText, rhsInfo, rhsValue)):
            return lhsText == rhsText && lhsInfo == rhsInfo && lhsValue == rhsValue
        default:
            return false
        }
    }

    static func <(lhs: MadgramEntry, rhs: MadgramEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MadgramControllerArguments
        switch self {
        case let .featuresHeader(text), let .premiumHeader(text), let .powerHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .featuresInfo(text), let .premiumInfo(text), let .powerInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .ghostMode(text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: arguments.openGhostMode)
        case let .messageFilters(text):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: arguments.openMessageFilters)
        case let .localMessageArchive(text):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: arguments.openLocalMessageArchive)
        case let .interfaceTuning(text):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: "", sectionId: self.section, style: .blocks, action: arguments.openInterfaceTuning)
        case let .powerSaving(text, info, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: text,
                titleBadgeComponent: featureInfoBadgeComponent(color: presentationData.theme.list.itemAccentColor),
                titleBadgeAction: { sourceView in
                    arguments.showInfo(info, sourceView)
                },
                value: value,
                maximumNumberOfLines: 2,
                sectionId: self.section,
                style: .blocks,
                updated: arguments.setPowerSaving
            )
        case let .localPremium(text, info, value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                title: text,
                titleBadgeComponent: featureInfoBadgeComponent(color: presentationData.theme.list.itemAccentColor),
                titleBadgeAction: { sourceView in
                    arguments.showInfo(info, sourceView)
                },
                value: value,
                maximumNumberOfLines: 2,
                sectionId: self.section,
                style: .blocks,
                updated: arguments.setLocalPremium
            )
        }
    }
}

public func madgramSettingsController(context: AccountContext) -> ViewController {
    var presentTooltip: ((String, UIView) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?

    let localPremiumValue = Atomic(value: LocalPremiumSettingsStore.shared.current)
    let localPremiumPromise = ValuePromise(localPremiumValue.with { $0 }, ignoreRepeated: true)

    let arguments = MadgramControllerArguments(
        openGhostMode: {
            pushControllerImpl?(ghostModeSettingsController(context: context))
        },
        openMessageFilters: {
            pushControllerImpl?(messageFilterSettingsController(context: context))
        },
        openLocalMessageArchive: {
            pushControllerImpl?(localMessageArchiveSettingsController(context: context))
        },
        openInterfaceTuning: {
            pushControllerImpl?(interfaceTuningSettingsController(context: context))
        },
        setLocalPremium: { value in
            let updated = LocalPremiumSettingsStore.shared.update { current in
                var current = current
                current.isEnabled = value
                return current
            }
            let _ = localPremiumValue.swap(updated)
            localPremiumPromise.set(updated)
        },
        setPowerSaving: { value in
            let _ = updateMediaDownloadSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var settings = settings
                if value {
                    settings.energyUsageSettings = EnergyUsageSettings.powerSavingDefault
                    settings.energyUsageSettings.activationThreshold = 96
                } else {
                    settings.energyUsageSettings = EnergyUsageSettings.default
                }
                return settings
            }).start()
            let _ = updatePresentationThemeSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
                var settings = settings
                settings.reduceMotion = value
                return settings
            }).start()
        },
        showInfo: { text, sourceView in
            presentTooltip?(text, sourceView)
        }
    )

    let ghostModeSettings = context.account.postbox.preferencesView(keys: [PreferencesKeys.ghostModeSettings])
    |> map { view -> GhostModeSettings in
        return view.values[PreferencesKeys.ghostModeSettings]?.get(GhostModeSettings.self) ?? .defaultSettings
    }

    let sharedData = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings, ApplicationSpecificSharedDataKeys.presentationThemeSettings])
    |> map { sharedData -> Bool in
        let downloadSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]?.get(MediaAutoDownloadSettings.self) ?? .defaultSettings
        let themeSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationThemeSettings]?.get(PresentationThemeSettings.self) ?? PresentationThemeSettings.defaultSettings
        let energy = downloadSettings.energyUsageSettings
        return energy.activationThreshold >= 96
            && !energy.autoplayVideo
            && !energy.autoplayGif
            && !energy.loopStickers
            && !energy.loopEmoji
            && !energy.fullTranslucency
            && !energy.extendBackgroundWork
            && !energy.autodownloadInBackground
            && themeSettings.reduceMotion
    }
    |> distinctUntilChanged

    let signal = combineLatest(context.sharedContext.presentationData, ghostModeSettings, localPremiumPromise.get(), sharedData)
    |> map { presentationData, ghostModeSettings, localPremiumSettings, isPowerSavingEnabled -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = presentationData.strings.localFeatures
        let entries: [MadgramEntry] = [
            .featuresHeader(strings.madgram.featuresSection),
            .ghostMode(strings.ghostMode.title, ghostModeSettings.isEnabled ? strings.ghostMode.on : strings.ghostMode.off),
            .messageFilters(strings.messageFilter.title),
            .localMessageArchive(strings.localMessageArchive.title),
            .interfaceTuning(strings.interfaceTuning.title),
            .featuresInfo(strings.madgram.info),

            .powerHeader(strings.madgram.powerSection),
            .powerSaving(strings.madgram.powerSaving, strings.madgram.powerSavingInfo, isPowerSavingEnabled),
            .powerInfo(strings.madgram.powerSavingInfo),

            .premiumHeader(strings.localPremium.section),
            .localPremium(strings.localPremium.title, strings.localPremium.info, localPremiumSettings.isEnabled),
            .premiumInfo(strings.localPremium.info)
        ]
        return (
            ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text(strings.madgram.title),
                leftNavigationButton: nil,
                rightNavigationButton: nil,
                backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
                animateChanges: true
            ),
            (
                ItemListNodeState(
                    presentationData: ItemListPresentationData(presentationData),
                    entries: entries,
                    style: .blocks
                ),
                arguments
            )
        )
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    var currentTooltipController: TooltipController?
    presentTooltip = { [weak controller] text, sourceView in
        guard let controller else {
            return
        }
        currentTooltipController?.dismiss()
        currentTooltipController = presentFeatureInfoTooltip(
            text: text,
            sourceView: sourceView,
            presentationData: context.sharedContext.currentPresentationData.with { $0 },
            controller: controller
        )
    }
    return controller
}
