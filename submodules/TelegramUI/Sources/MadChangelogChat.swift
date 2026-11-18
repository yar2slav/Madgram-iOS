import Foundation
import UIKit
import UserNotifications
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramUIPreferences
import SettingsUI
import MadgramAgent
import AppBundle

enum MadChangelogToggle {
    case agentTab
    case agentNotifications
    case revealText
    case revealMedia
    case spoilersSaved
    case silent
    case hide
}

private struct MadChangelogPage {
    var blocks: [InstantPageBlock] = []
    var toggles: [[Int]: MadChangelogToggle] = [:]

    mutating func add(_ block: InstantPageBlock) {
        self.blocks.append(block)
    }

    mutating func checklist(_ items: [(RichText, MadChangelogToggle)], state: (MadChangelogToggle) -> Bool) {
        let index = self.blocks.count
        var listItems: [InstantPageListItem] = []
        for (itemIndex, item) in items.enumerated() {
            listItems.append(.text(item.0, nil, state(item.1)))
            self.toggles[[index, itemIndex]] = item.1
        }
        self.blocks.append(.list(items: listItems, ordered: false))
    }
}

private let platformEmoji: [String: (Int64, String)] = [
    "steam": (5373144051690258848, "🎮"),
    "discord": (5325612636467903082, "💬"),
    "reddit": (5330321861949539755, "👽"),
    "twitch": (5334678011054669335, "📺"),
    "spotify": (5346074681004801565, "🎧"),
    "soundcloud": (5345844509412444249, "☁️"),
    "github": (5346181118884331907, "🐙"),
    "gitlab": (5346308584923740680, "🦊")
]

private func plain(_ text: String) -> RichText {
    return .plain(text)
}

private func concat(_ parts: RichText...) -> RichText {
    return .concat(parts)
}

private func note(_ number: String) -> RichText {
    return .superscript(.plain(number))
}

private func bullets(_ items: [RichText]) -> InstantPageBlock {
    return .list(items: items.map { .text($0, nil, nil) }, ordered: false)
}

private func platform(_ id: String, _ name: String) -> RichText {
    guard let emoji = platformEmoji[id] else {
        return .bold(plain(name))
    }
    return concat(.textCustomEmoji(fileId: emoji.0, alt: emoji.1), plain(" "), .bold(plain(name)))
}

private func tableRow(_ cells: [RichText], header: Bool = false) -> InstantPageTableRow {
    return InstantPageTableRow(cells: cells.enumerated().map { index, text in
        InstantPageTableCell(text: text, header: header, alignment: index == 0 ? .left : .center, verticalAlignment: .middle, colspan: 1, rowspan: 1)
    })
}

private func buildChangelog(ru: Bool, state: (MadChangelogToggle) -> Bool) -> [MadChangelogPage] {
    func t(_ ruText: String, _ enText: String) -> String {
        return ru ? ruText : enText
    }
    func p(_ ruText: String, _ enText: String) -> RichText {
        return plain(t(ruText, enText))
    }
    func l(_ ruText: String, _ enText: String, _ path: String) -> RichText {
        return .url(text: p(ruText, enText), url: "mad://" + path, webpageId: nil)
    }
    var page = MadChangelogPage()

    page.add(.heading(text: p("что нового в mad 13.2", "what's new in mad 13.2"), level: 1))
    page.add(.paragraph(concat(
        p("это ченджлог свежего обновления клиента 👋 тут всё, что появилось в mad. ссылки ведут прямо в нужную настройку, а ", "this is the changelog of the fresh client update 👋 here's everything new in mad. links lead straight to the right setting, and "),
        .bold(p("галочки живые", "the checkboxes are live")),
        p(": тапнул, и функция сразу включилась или выключилась.", ": tap one and the feature turns on or off right away.")
    )))

    page.add(.heading(text: p("✨ ии-агент", "✨ ai agent"), level: 2))
    page.add(.paragraph(concat(
        p("свой ии прямо в телеге, ", "your own ai right inside telegram, "),
        l("на отдельной вкладке", "on its own tab", "agent"),
        p(". работает на твоём ключе: anthropic, openai или любой совместимый сервер, модель и характер выбираешь сам.", ". it runs on your key: anthropic, openai or any compatible server, with the model and persona of your choice.")
    )))
    page.add(.heading(text: p("что умеет", "what it can do"), level: 3))
    page.add(bullets([
        p("читает переписки и пересказывает главное: кто что сказал, о чём договорились, что ждёт ответа", "reads chats and sums them up: who said what, what was agreed, what needs a reply"),
        p("ищет по чатам и сообщениям, читает переписку за нужный период", "searches chats and messages, reads a chat over a given period"),
        p("пишет и отправляет сообщения от твоего имени: с подтверждением или сразу, как настроишь", "writes and sends messages as you, with a confirmation or right away, your call"),
        p("готовит черновик ответа прямо в поле ввода", "drafts a reply right in the input field"),
        p("пересылает сообщения и наводит порядок: прочитать, замьютить, архивировать, закрепить", "forwards messages and tidies chats: mark read, mute, archive, pin"),
        p("откладывает сообщения и ставит напоминания", "schedules messages and sets reminders"),
        p("смотрит фотки, расшифровывает голосовые и ищет в интернете", "looks at photos, transcribes voice messages and searches the web")
    ]))
    page.add(.heading(text: p("автоответчик", "auto-responder"), level: 3))
    page.add(.paragraph(concat(
        l("скажи агенту", "tell the agent", "agent"),
        p(" ", " "),
        .italic(p("«будь моим автоответчиком с …»", "\"be my auto-responder with …\"")),
        p(", и он сам отвечает этому человеку по твоему сценарию.", " and it answers that person on its own, following your script.")
    )))
    page.add(bullets([
        p("в чате видно, что он делает: думает, ищет, пишет", "the chat shows what it's doing: thinking, searching, typing"),
        p("лимит ответов в час и стоп-фразы, после которых он замолкает и зовёт тебя", "a replies-per-hour limit and stop phrases that make it go quiet and call you"),
        p("видит только эту переписку и не выполняет просьбы собеседника", "sees only that chat and ignores the other person's requests"),
        p("важное присылает тебе заметкой в чат агента, срочное громким уведомлением", "sends you important things as notes in the agent chat, urgent ones as a loud notification")
    ]))
    page.add(.heading(text: p("удобство", "comfort"), level: 3))
    page.add(bullets([
        concat(p("несколько диалогов с историей: ", "several chats with history: "), l("«⋯» → «история диалогов»", "\"⋯\" → \"chat history\"", "agent")),
        p("на вкладке ии счётчик новых заметок", "the ai tab shows a counter of new notes"),
        concat(l("уточка-компаньон", "a companion duck", "companion"), p(" над полем ввода в личных чатах, взята из беты telegram 13.2. её можно покрутить пальцем", " above the input in private chats, taken from the telegram 13.2 beta. you can spin it with a finger"))
    ]))
    page.checklist([
        (p("вкладка ии внизу", "ai tab at the bottom"), .agentTab),
        (p("уведомления от агента", "notifications from the agent"), .agentNotifications)
    ], state: state)

    page.add(.heading(text: p("🧑‍🚀 профиль", "🧑‍🚀 profile"), level: 2))
    page.add(.paragraph(concat(
        l("привяжи аккаунты", "link accounts", "accounts"),
        p(" с других площадок и свой домен. каждый подтверждается входом", " from other platforms and your own domain. each one is verified"),
        note("1"),
        p(", а видят их только пользователи mad. блок показывается в строчку или списком, как выберешь.", ", and only mad users can see them. the block shows as a row or a list, your choice.")
    )))
    let website = p("вход через сайт", "website sign-in")
    page.add(.table(title: .empty, rows: [
        tableRow([p("площадка", "platform"), p("как подключается", "how it connects")], header: true),
        tableRow([platform("steam", "steam"), p("вход через steam", "steam sign-in")]),
        tableRow([platform("github", "github"), website]),
        tableRow([platform("gitlab", "gitlab"), website]),
        tableRow([platform("discord", "discord"), website]),
        tableRow([platform("reddit", "reddit"), website]),
        tableRow([platform("twitch", "twitch"), website]),
        tableRow([platform("spotify", "spotify"), concat(p("свой client id", "your own client id"), note("2"))]),
        tableRow([platform("soundcloud", "soundcloud"), website]),
        tableRow([platform("lastfm", "last.fm"), website]),
        tableRow([concat(plain("🌐 "), .bold(p("свой домен", "your domain"))), p("TXT-запись в DNS", "a DNS TXT record")])
    ], bordered: true, striped: true, compact: true))
    page.add(.paragraph(p("ещё в профилях появились бейджи mad и цветные ники с эффектами: перелив, радуга, блик и пульс.", "profiles also got mad badges and coloured names with effects: flow, rainbow, shimmer and pulse.")))

    page.add(.heading(text: p("🔒 приватность", "🔒 privacy"), level: 2))
    page.add(bullets([
        concat(l("блокировка чатов", "chat lock", "locked"), p(" пин-кодом, паролем, графическим ключом или face id", " with a pin, password, pattern or face id")),
        concat(l("локальный пароль", "a local password", "password"), p(" на траты звёзд, подарки и передачу nft", " for spending stars, gifts and nft transfers")),
        concat(l("призрак", "ghost mode", "ghost"), p(" для отдельного чата: читаешь, а собеседник не видит", " per chat: you read, they don't see it")),
        concat(l("одноразовые медиа не сгорают", "view-once media doesn't burn", "ghost"), p(": пересматривай сколько угодно, отправитель увидит просмотр, только когда нажмёшь «сжечь»", ": rewatch as much as you like, the sender sees it opened only when you tap burn")),
        concat(l("архив удалённых сообщений", "an archive of deleted messages", "archive"), p(" и истории правок, с исключениями", " and edit history, with exceptions")),
        concat(l("номер можно скрыть", "your number can be hidden", "hiding"), p(" везде, даже от себя в настройках", " everywhere, even in your own settings"))
    ]))

    page.add(.heading(text: p("🧹 чистая лента", "🧹 a clean feed"), level: 2))
    page.add(bullets([
        concat(l("реклама в каналах", "channel ads", "hiding"), p(" и спонсорские сообщения скрываются", " and sponsored messages are hidden")),
        concat(l("свои правила скрытия", "your own hiding rules", "hidden-rules"), p(" по словам и регуляркам", " by words and regular expressions")),
        concat(l("плашки иноагентов", "foreign agent disclaimers", "hiding"), p(" вырезаются из текста", " are cut from the text")),
        concat(l("utm, fbclid и прочие метки", "utm, fbclid and other trackers", "chats"), p(" чистятся из ссылок", " are stripped from links")),
        concat(l("спойлеры снимаются сами", "spoilers come off by themselves", "chats"), p(", а где именно, решаешь ты: личные, группы, каналы, избранное, медиа в профиле", ", and you decide where: private chats, groups, channels, saved messages, profile media"))
    ]))
    page.checklist([
        (p("снимать спойлеры с текста", "remove spoilers from text"), .revealText),
        (p("снимать спойлеры с медиа", "remove spoilers from media"), .revealMedia)
    ], state: state)

    page.add(.heading(text: p("🔔 уведомления", "🔔 notifications"), level: 2))
    page.add(bullets([
        concat(l("баннеры с именем и текстом", "banners with the name and text", "notifications"), p(", пока mad живёт в фоне", " while mad stays alive in the background"), note("3")),
        concat(l("кто из выбранных людей", "when chosen people", "presence"), p(" зашёл в сеть или вышел из неё", " come online or go offline")),
        concat(l("реакции на твои сообщения", "reactions to your messages", "reactions"), p(", даже в группах", ", even in groups"))
    ]))

    page.add(.heading(text: p("💬 сообщения и медиа", "💬 messages and media"), level: 2))
    page.add(bullets([
        p("экспорт чата в txt, json или html вместе с удалёнными и историей правок, с прогрессом в процентах. в профиле чата → «⋯»", "chat export to txt, json or html with deleted messages and edit history, with progress in percent. in the chat profile → \"⋯\""),
        concat(l("точное число просмотров", "exact view counts", "chats"), p(" под постами вместо 5,2K", " under posts instead of 5.2K")),
        concat(l("бесплатный перевод и расшифровка", "free translation and transcription", "messages"), p(" голосовых без премиума", " of voice messages without premium")),
        concat(l("камера в 4k и 60 кадров", "4k 60 fps camera", "interface"), p(", кружки на 0.5x и в лучшем качестве", ", round videos at 0.5x and in better quality")),
        p("wav играет как музыка и отправляется с длительностью", "wav plays as music and is sent with its duration"),
        concat(l("локальные имена", "local names", "names"), p(" для людей и чатов, видишь их только ты", " for people and chats, only you see them")),
        concat(l("секунды во времени, онлайн-точка в группах", "seconds in timestamps, an online dot in groups", "interface"), p(", полупрозрачные удалённые", ", faded deleted messages")),
        concat(l("даты вступления", "join dates", "chats"), p(", невидимые символы в именах, id эмодзи и владельца пака", ", invisible characters in names, emoji ids and pack owners"))
    ]))

    page.add(.details(title: p("🛠 прочее", "🛠 other"), blocks: [
        bullets([
            p("«открыть в mad» для ссылок t.me из других приложений", "\"open in mad\" for t.me links from other apps"),
            p("вход по токену бота", "sign in with a bot token"),
            concat(l("экспорт и импорт настроек", "settings export and import", "other"), p(", поиск по настройкам mad", ", search in mad settings"))
        ])
    ], expanded: false))

    page.add(.divider)
    page.add(.footer(concat(note("1"), p(" домен подтверждается TXT-записью mad-verify в его DNS.", " a domain is verified by a mad-verify TXT record in its DNS."))))
    page.add(.footer(concat(note("2"), p(" spotify пускает только по своему client id, поэтому его вводишь ты. подсказка появится при подключении.", " spotify only lets in apps by their own client id, so you enter yours. a hint shows up when you connect."))))
    page.add(.footer(concat(note("3"), p(" mad держится в фоне на беззвучном звуке, пока включены локальные уведомления.", " mad stays alive in the background on silent audio while local notifications are on."))))

    page.add(.pullQuote(text: p("нашёл баг или есть идея? пиши, всё читаем 🖤", "found a bug or have an idea? write us, we read everything 🖤"), caption: .url(text: p("команда mad", "the mad team"), url: "https://t.me/yar2slav", webpageId: nil)))
    page.add(.heading(text: p("этот чат", "this chat"), level: 3))
    page.checklist([
        (p("без уведомления о новых версиях", "no notification about new versions"), .silent),
        (p("больше не показывать этот чат", "never show this chat again"), .hide)
    ], state: state)

    return [page]
}

final class MadChangelogChat {
    private static var observers: [Int64: [NSObjectProtocol]] = [:]

    private static func isRussian(_ context: AccountContext) -> Bool {
        let code = context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
        return code == "ru" || code == "uk"
    }

    private static func state(_ toggle: MadChangelogToggle, accountId: Int64) -> Bool {
        switch toggle {
        case .agentTab:
            return InterfaceTuningSettingsStore.shared.current.showAgentTab
        case .agentNotifications:
            return AgentSettingsStore.shared.current.agentNotifications
        case .revealText:
            return ChatContentFilterSettingsStore.shared.current.revealTextSpoilers
        case .revealMedia:
            return ChatContentFilterSettingsStore.shared.current.revealMediaSpoilers
        case .spoilersSaved:
            return InterfaceTuningSettingsStore.shared.current.sub(.spoilersSaved)
        case .silent:
            return MadChangelogPreferences.isSilent(accountId: accountId)
        case .hide:
            return false
        }
    }

    private static func sections(context: AccountContext) -> [MadChangelogPage] {
        let accountId = context.account.peerId.toInt64()
        return buildChangelog(ru: self.isRussian(context), state: { self.state($0, accountId: accountId) })
    }

    private static func attribute(_ page: MadChangelogPage) -> RichTextMessageAttribute {
        return RichTextMessageAttribute(instantPage: InstantPage(blocks: page.blocks, media: [:], isComplete: true, rtl: false, url: "", views: nil), fullInstantPage: nil)
    }

    private static func storedMessageIds(accountId: Int64) -> [EngineMessage.Id] {
        return MadChangelogPreferences.messageIds(accountId: accountId).map { EngineMessage.Id(peerId: MadLocalChat.peerId, namespace: $0.namespace, id: $0.id) }
    }

    static func attach(context: AccountContext) {
        let accountId = context.account.peerId.toInt64()
        if self.observers[accountId] == nil {
            var observers: [NSObjectProtocol] = []
            observers.append(NotificationCenter.default.addObserver(forName: MadChangelogPreferences.didChangeNotification, object: nil, queue: .main, using: { [weak context] _ in
                if let context {
                    self.sync(context: context)
                }
            }))
            for name in [InterfaceTuningSettingsStore.didChangeNotification, ChatContentFilterSettingsStore.didChangeNotification, AgentSettingsStore.didChangeNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main, using: { [weak context] _ in
                    if let context {
                        self.refresh(context: context)
                    }
                }))
            }
            self.observers[accountId] = observers
        }
        self.sync(context: context)
    }

    static func sync(context: AccountContext) {
        let accountId = context.account.peerId.toInt64()
        guard !MadChangelogPreferences.isHidden(accountId: accountId) else {
            return
        }
        var avatarData: Data?
        if let image = UIImage(bundleImageName: "Mad/ChangelogAvatar") {
            avatarData = image.jpegData(compressionQuality: 0.9)
        }
        let version = MadWhatsNew.version
        let engine = context.engine
        let _ = (engine.messages.madLocalChatPrepare(name: "mad", avatarJpeg: avatarData, avatarSide: 640)
        |> then(Signal<Never, NoError>.complete())
        |> deliverOnMainQueue).startStandalone(completed: {
            let attributes = self.sections(context: context).map(self.attribute)
            let post: (Bool) -> Void = { isNewVersion in
                let _ = (engine.messages.madLocalChatPost(richTexts: attributes, replacing: true)
                |> deliverOnMainQueue).startStandalone(next: { messageIds in
                    guard messageIds.count == attributes.count else {
                        return
                    }
                    MadChangelogPreferences.setPosted(version: version, messageIds: messageIds.map { ($0.namespace, $0.id) }, accountId: accountId)
                    if isNewVersion && !MadChangelogPreferences.isSilent(accountId: accountId) {
                        self.notify(ru: self.isRussian(context))
                    }
                })
            }
            let stored = self.storedMessageIds(accountId: accountId)
            if MadChangelogPreferences.postedVersion(accountId: accountId) == version, stored.count == attributes.count {
                let _ = (engine.messages.madLocalChatUpdate(messageIds: stored, richTexts: attributes)
                |> deliverOnMainQueue).startStandalone(next: { updated in
                    if !updated {
                        post(false)
                    }
                })
                return
            }
            post(true)
        })
    }

    static func refresh(context: AccountContext) {
        let accountId = context.account.peerId.toInt64()
        let stored = self.storedMessageIds(accountId: accountId)
        let attributes = self.sections(context: context).map(self.attribute)
        guard !MadChangelogPreferences.isHidden(accountId: accountId), MadChangelogPreferences.postedVersion(accountId: accountId) == MadWhatsNew.version, stored.count == attributes.count else {
            return
        }
        let _ = context.engine.messages.madLocalChatUpdate(messageIds: stored, richTexts: attributes).startStandalone()
    }

    private static func notify(ru: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "mad"
        content.body = ru ? "что нового в mad 13.2: аккаунты и домен в профиле, история диалогов агента, спойлеры по местам" : "what's new in mad 13.2: profile accounts and domains, agent chat history, per-place spoilers"
        content.sound = .default
        content.threadIdentifier = "mad-changelog"
        content.userInfo = ["madAgentNote": true, "peerId": MadLocalChat.peerId.toInt64()]
        let request = UNNotificationRequest(identifier: "mad-changelog-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func toggle(context: AccountContext, messageId: EngineMessage.Id, path: [Int], value: Bool, hidden: @escaping () -> Void) {
        let accountId = context.account.peerId.toInt64()
        let sections = self.sections(context: context)
        guard let sectionIndex = self.storedMessageIds(accountId: accountId).firstIndex(of: messageId), sectionIndex < sections.count, let toggle = sections[sectionIndex].toggles[path] else {
            return
        }
        switch toggle {
        case .agentTab:
            let _ = InterfaceTuningSettingsStore.shared.update { current in
                var current = current
                current.showAgentTab = value
                return current
            }
        case .agentNotifications:
            AgentSettingsStore.shared.update { $0.agentNotifications = value }
        case .revealText:
            ChatContentFilterSettingsStore.shared.update { current in
                var current = current
                current.revealTextSpoilers = value
                return current
            }
        case .revealMedia:
            ChatContentFilterSettingsStore.shared.update { current in
                var current = current
                current.revealMediaSpoilers = value
                return current
            }
        case .spoilersSaved:
            let _ = InterfaceTuningSettingsStore.shared.update { current in
                var current = current
                current.subToggles[MadSubToggle.spoilersSaved.rawValue] = value
                return current
            }
        case .silent:
            MadChangelogPreferences.setSilent(value, accountId: accountId)
        case .hide:
            guard value else {
                return
            }
            MadChangelogPreferences.setHidden(true, accountId: accountId)
            let _ = context.engine.peers.removePeerChat(peerId: MadLocalChat.peerId, reportChatSpam: false).startStandalone()
            hidden()
            return
        }
        self.refresh(context: context)
    }
}
