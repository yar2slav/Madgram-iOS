import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext

public enum MadWhatsNew {
    public static let version = "13.2-mad.10"
    private static let key = "madgram.lastSeenVersion"

    public static func shouldPresent() -> Bool {
        let defaults = UserDefaults.standard
        guard let lastSeen = defaults.string(forKey: key) else {
            defaults.set(version, forKey: key)
            return false
        }
        return lastSeen != version
    }

    public static func markSeen() {
        UserDefaults.standard.set(version, forKey: key)
    }

    static func features(languageCode: String) -> [String] {
        if languageCode == "ru" {
            return [
                "Точное число просмотров под постами вместо 5,2K",
                "Одноразовые медиа можно не сжигать и без включённого призрака",
                "Свой домен в профиле: подтверждается TXT-записью в DNS",
                "Локальный чат «что нового» от mad с живыми тумблерами функций прямо в сообщении",
                "Уведомления о реакциях на твои сообщения, настраиваются в «Уведомления и звуки» → «Реакции»",
                "У ИИ-агента несколько диалогов: новый диалог, история, переключение и удаление",
                "Заметки ИИ-агента приходят в его чат, на вкладке ИИ появляется счётчик, уведомления от агента можно выключить",
                "Экспорт сообщений показывает прогресс в процентах, как очистка кеша",
                "Снятие спойлеров настраивается по местам: личные, группы, каналы, избранное, медиа в профиле",
                "Кнопка «Обновить данные» у привязанного аккаунта и выбор, что показывать в профиле: адрес или ник",
                "Аккаунты в профиле: Steam, GitHub, Spotify, Discord и другие, каждый подтверждается входом. Их видят только пользователи mad",
                "Блокировка чатов пин-кодом, паролем, графическим ключом или Face ID",
                "Локальный пароль на траты звёзд, подарки и передачу NFT",
                "Скрытие сообщений по словам и регуляркам",
                "Плашки иноагентов убираются из текста",
                "Чистка utm, fbclid и si из ссылок",
                "Локальные имена для людей и чатов",
                "Уведомления, когда человек заходит в сеть и выходит",
                "Бесплатный перевод через Google и расшифровка без премиума",
                "Камера в 4K и 60 кадров, кружки на 0.5x и в лучшем качестве",
                "ИИ-агент оформляет сообщения: жирный, код, цитаты",
                "Вход по токену бота, экспорт и импорт настроек, поиск по настройкам mad"
            ]
        }
        return [
            "Exact view counts under posts instead of 5.2K",
            "View-once media can be kept without turning on Ghost Mode",
            "Your own domain in the profile, verified by a DNS TXT record",
            "A local what's new chat from mad with live feature toggles right in the message",
            "Notifications about reactions to your messages, set up in Notifications and Sounds → Reactions",
            "The AI agent keeps several chats: new chat, history, switching and deleting",
            "Notes from the AI agent arrive in its chat, the AI tab shows a counter, agent notifications can be turned off",
            "Message export shows its progress in percent, like clearing the cache",
            "Spoiler removal can be set per place: private chats, groups, channels, Saved Messages, profile media",
            "A Refresh details button for linked accounts and a choice of showing the address or the display name in your profile",
            "Accounts in your profile: Steam, GitHub, Spotify, Discord and more, each verified by signing in. Only mad users see them",
            "Lock chats with a PIN, password, pattern or Face ID",
            "A local password for spending stars, gifts and NFT transfers",
            "Hide messages by words and regular expressions",
            "Foreign agent disclaimers are removed from text",
            "utm, fbclid and si are stripped from links",
            "Local names for people and chats",
            "Notifications when a person comes online or goes offline",
            "Free Google translation and transcription without Premium",
            "4K and 60 fps camera, round videos at 0.5x and in better quality",
            "The AI agent formats messages: bold, code, quotes",
            "Bot token login, settings export and import, search in mad settings"
        ]
    }
}

private enum MadWhatsNewEntry: ItemListNodeEntry {
    case feature(Int32, String)
    case header(String)
    case toggle(Int32, String, Bool, WritableKeyPath<InterfaceTuningSettings, Bool>)

    var section: ItemListSectionId {
        switch self {
        case .feature:
            return 0
        case .header, .toggle:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case let .feature(index, _):
            return index
        case .header:
            return 1000
        case let .toggle(index, _, _, _):
            return 1001 + index
        }
    }

    static func <(lhs: MadWhatsNewEntry, rhs: MadWhatsNewEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    static func ==(lhs: MadWhatsNewEntry, rhs: MadWhatsNewEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.feature(a, b), .feature(c, d)):
            return a == c && b == d
        case let (.header(a), .header(b)):
            return a == b
        case let (.toggle(a, b, c, d), .toggle(e, f, g, h)):
            return a == e && b == f && c == g && d == h
        default:
            return false
        }
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .feature(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain("• " + text), sectionId: self.section)
        case let .header(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(_, title, value, keyPath):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                InterfaceTuningSettingsStore.shared.update { current in
                    var current = current
                    current[keyPath: keyPath] = value
                    return current
                }
            })
        }
    }
}

public func madWhatsNewController(context: AccountContext) -> ViewController {
    var dismissImpl: (() -> Void)?
    let signal = combineLatest(context.sharedContext.presentationData, interfaceTuningSettingsSignal())
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let more = presentationData.strings.localFeatures.more
        var entries: [MadWhatsNewEntry] = []
        for (index, text) in MadWhatsNew.features(languageCode: presentationData.strings.baseLanguageCode).enumerated() {
            entries.append(.feature(Int32(index), text))
        }
        entries.append(.header(more.whatsNewSettings.uppercased()))
        let toggles: [(String, WritableKeyPath<InterfaceTuningSettings, Bool>)] = [
            (more.hideForeignAgentLabels, \.hideForeignAgentLabels),
            (more.cleanSentLinks, \.cleanSentLinks),
            (more.cleanOpenedLinks, \.cleanOpenedLinks),
            (more.freeTranslation, \.freeTranslation),
            (more.freeTranscription, \.freeTranscription),
            (more.hideProxySponsor, \.hideProxySponsor)
        ]
        for (index, toggle) in toggles.enumerated() {
            entries.append(.toggle(Int32(index), toggle.0, settings[keyPath: toggle.1], toggle.1))
        }
        return (
            ItemListControllerState(
                presentationData: ItemListPresentationData(presentationData),
                title: .text(more.whatsNewTitle),
                leftNavigationButton: nil,
                rightNavigationButton: ItemListNavigationButton(content: .text(more.whatsNewDone), style: .bold, enabled: true, action: {
                    dismissImpl?()
                }),
                backNavigationButton: nil
            ),
            (
                ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks),
                Void()
            )
        )
    }
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    dismissImpl = { [weak controller] in
        MadWhatsNew.markSeen()
        controller?.dismiss()
    }
    return controller
}
