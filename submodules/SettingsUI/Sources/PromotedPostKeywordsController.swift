import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext

private final class PromotedPostKeywordsArguments {
    let updateText: (String) -> Void
    let reset: () -> Void

    init(updateText: @escaping (String) -> Void, reset: @escaping () -> Void) {
        self.updateText = updateText
        self.reset = reset
    }
}

private enum PromotedPostKeywordsSection: Int32 {
    case keywords
    case reset
}

private enum PromotedPostKeywordsEntry: ItemListNodeEntry {
    case input(String, String, Int)
    case info(String)
    case reset(String)

    var section: ItemListSectionId {
        switch self {
        case .input, .info:
            return PromotedPostKeywordsSection.keywords.rawValue
        case .reset:
            return PromotedPostKeywordsSection.reset.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .input:
            return 0
        case .info:
            return 1
        case .reset:
            return 2
        }
    }

    static func <(lhs: PromotedPostKeywordsEntry, rhs: PromotedPostKeywordsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    static func ==(lhs: PromotedPostKeywordsEntry, rhs: PromotedPostKeywordsEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.input(lhsPlaceholder, _, lhsVersion), .input(rhsPlaceholder, _, rhsVersion)):
            return lhsPlaceholder == rhsPlaceholder && lhsVersion == rhsVersion
        case let (.info(lhsText), .info(rhsText)), let (.reset(lhsText), .reset(rhsText)):
            return lhsText == rhsText
        default:
            return false
        }
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PromotedPostKeywordsArguments
        switch self {
        case let .input(placeholder, text, _):
            return ItemListMultilineInputItem(presentationData: presentationData, text: text, placeholder: placeholder, maxLength: nil, sectionId: self.section, style: .blocks, capitalization: false, autocorrection: false, minimalHeight: 160.0, textUpdated: { value in
                arguments.updateText(value)
            })
        case let .info(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .reset(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.reset()
            })
        }
    }
}

private func parsedKeywords(_ text: String) -> [String] {
    var result: [String] = []
    for line in text.components(separatedBy: .newlines) {
        let keyword = line.trimmingCharacters(in: .whitespaces)
        if !keyword.isEmpty && !result.contains(where: { $0.lowercased() == keyword.lowercased() }) {
            result.append(keyword)
        }
    }
    return result
}

public func promotedPostKeywordsController(context: AccountContext) -> ViewController {
    let initialText = ChatContentFilterSettingsStore.shared.current.promotedPostKeywords.joined(separator: "\n")
    let textValue = Atomic<(String, Int)>(value: (initialText, 0))
    let versionPromise = ValuePromise<Int>(0, ignoreRepeated: false)

    let arguments = PromotedPostKeywordsArguments(
        updateText: { text in
            let _ = textValue.modify { current in
                return (text, current.1)
            }
            ChatContentFilterSettingsStore.shared.update { current in
                var current = current
                current.promotedPostKeywords = parsedKeywords(text)
                return current
            }
        },
        reset: {
            let text = ChatContentFilterSettings.defaultPromotedPostKeywords.joined(separator: "\n")
            let updated = textValue.modify { current in
                return (text, current.1 + 1)
            }
            ChatContentFilterSettingsStore.shared.update { current in
                var current = current
                current.promotedPostKeywords = ChatContentFilterSettings.defaultPromotedPostKeywords
                return current
            }
            versionPromise.set(updated.1)
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, versionPromise.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = presentationData.strings.localFeatures.extras
        let (text, version) = textValue.with { $0 }
        let entries: [PromotedPostKeywordsEntry] = [
            .input(strings.promotedKeywordsPlaceholder, text, version),
            .info(strings.promotedKeywordsInfo),
            .reset(strings.promotedKeywordsReset)
        ]
        return (
            ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text(strings.promotedKeywords),
                leftNavigationButton: nil,
                rightNavigationButton: nil,
                backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
            ),
            (
                ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks),
                arguments
            )
        )
    }

    return ItemListController(context: context, state: signal)
}
