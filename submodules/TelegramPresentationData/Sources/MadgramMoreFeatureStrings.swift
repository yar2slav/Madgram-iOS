import Foundation

public struct MadgramMoreFeatureStrings {
    public let hideVoiceRecordButton: String
    public let hidePinnedMessageBar: String
    public let forceViewOnceVoice: String
    public let forceViewOnceVoiceInfo: String
    public let hideGiftInputButton: String
    public let hideSimilarChannels: String
    public let hideBirthdays: String
    public let hideBirthdaysInfo: String
    public let disableTelegramAI: String
    public let disableTelegramAIInfo: String
    public let disableTonWallet: String
    public let disableTonWalletInfo: String
    public let showOnlineCountAlways: String
    public let showOnlineCountAlwaysInfo: String
    public let hideProxySponsor: String
    public let staticAnimatedAvatars: String
    public let sendInlineWithoutVia: String
    public let sendInlineWithoutViaInfo: String
    public let showNameInsteadOfPhone: String
    public let showNameInsteadOfPhoneInfo: String
    public let hidePhoneEverywhere: String
    public let showMutualContactInHeader: String
    public let mutualContactShort: String
    public let showJoinDates: String
    public let showJoinDatesInfo: String
    public let youJoined: String
    public let memberSince: String
    public let showInvisibleChars: String
    public let showInvisibleCharsInfo: String
    public let cleanSentLinks: String
    public let cleanOpenedLinks: String
    public let cleanLinksInfo: String
    public let hideForeignAgentLabels: String
    public let hideForeignAgentLabelsInfo: String
    public let hiddenRules: String
    public let hiddenRulesInfo: String
    public let hiddenRulesPlaceholder: String
    public let hiddenRulesError: (Int, String) -> String
    public let hiddenRulesCount: (Int) -> String
    public let showMediaInfoInViewer: String
    public let showMediaInfoInViewerInfo: String
    public let mediaUploaded: String
    public let freeTranslation: String
    public let freeTranslationInfo: String
    public let freeTranscription: String
    public let freeTranscriptionInfo: String
    public let cameraSection: String
    public let cameraResolution: String
    public let cameraFrameRate: String
    public let cameraInfo: String
    public let roundVideoQuality: String
    public let roundVideoQualityStandard: String
    public let roundVideoQualityHigh: String
    public let roundVideoQualityMax: String
    public let roundVideoUltraWide: String
    public let roundVideoUltraWideInfo: String
    public let localName: String
    public let localNamePlaceholder: String
    public let localNameInfo: String
    public let localNameRemove: String
    public let localNames: String
    public let localNamesInfo: String
    public let localNamesEmpty: String
    public let lockChat: String
    public let unlockChat: String
    public let lockedChats: String
    public let lockedChatsEmpty: String
    public let lockedChatPreview: String
    public let localPassword: String
    public let localPasswordInfo: String
    public let localPasswordSet: String
    public let localPasswordChange: String
    public let localPasswordRemove: String
    public let localPasswordNotSet: String
    public let lockTypePin: String
    public let lockTypePassword: String
    public let lockTypePattern: String
    public let lockUseBiometrics: String
    public let enterCode: String
    public let enterPassword: String
    public let drawPattern: String
    public let newCode: String
    public let newPassword: String
    public let newPattern: String
    public let repeatCode: String
    public let repeatPattern: String
    public let lockMismatch: String
    public let lockWrong: String
    public let lockPatternTooShort: String
    public let lockNeedPasswordFirst: String
    public let lockUnlockReason: String
    public let lockDone: String
    public let lockCancel: String
    public let skipFor: String
    public let skipNone: String
    public let skip15m: String
    public let skip1h: String
    public let skip1d: String
    public let skipUntilRestart: String
    public let spendLock: String
    public let spendLockInfo: String
    public let spendReactions: String
    public let spendMessages: String
    public let spendGifts: String
    public let spendTransfer: String
    public let spendPayments: String
    public let spendReason: String
    public let notifyPresence: String
    public let notifyPresenceOn: String
    public let notifyPresenceOff: String
    public let userCameOnline: (String) -> String
    public let reactionNotification: (String, String) -> String
    public let changelogMute: String
    public let exactViewCounts: String
    public let exactViewCountsInfo: String
    public let changelogUnmute: String
    public let changelogHide: String
    public let changelogHidden: String
    public let changelogShow: String
    public let changelogStatus: String
    public let madRepository: String
    public let madReleasesChannel: String
    public let changelogRestored: String
    public let reactionNotificationTitle: String
    public let reactionNotificationMessage: String
    public let userWentOffline: (String) -> String
    public let presenceWatched: String
    public let presenceWatchedInfo: String
    public let presenceWatchedEmpty: String
    public let loginAsBot: String
    public let botTokenTitle: String
    public let botTokenText: String
    public let botTokenPlaceholder: String
    public let botTokenInvalid: String
    public let backupSection: String
    public let exportSettings: String
    public let importSettings: String
    public let backupInfo: String
    public let settingsImported: String
    public let settingsImportFailed: String
    public let whatsNewTitle: String
    public let whatsNewDone: String
    public let whatsNewSettings: String
    public let remove: String
    public let categoryHiding: String
    public let hidingTextSection: String
    public let whereChatList: String
    public let whereChats: String
    public let whereProfile: String
    public let whereMessages: String
    public let whereNotifications: String
    public let similarInChat: String
    public let similarInProfile: String
    public let similarBots: String
    public let aiInput: String
    public let aiSummaries: String
    public let joinDateMine: String
    public let joinDateMembers: String
    public let voiceMessages: String
    public let roundMessages: String
    public let phoneOthers: String
    public let phoneMine: String
    public let linksSection: String
    public let accounts: MadAccountsStrings

    public init(languageCode: String) {
        func t(_ ru: String, _ en: String) -> String {
            return languageCode == "ru" ? ru : en
        }
        let ru = languageCode == "ru"

        self.hideVoiceRecordButton = t("Скрыть кнопку записи", "Hide record button")
        self.hidePinnedMessageBar = t("Скрыть плашку закрепа", "Hide pinned message bar")
        self.forceViewOnceVoice = t("Гс и кружки одноразовые", "View-once voice and round videos")
        self.forceViewOnceVoiceInfo = t("Голосовые и кружки уходят с одним просмотром. Только в личке с людьми, не в отложенных и не в платных.", "Voice and round video messages are sent as view-once. Private chats with people only, not scheduled or paid.")
        self.hideGiftInputButton = t("Скрыть подарок в поле ввода", "Hide gift button in input")
        self.hideSimilarChannels = t("Скрыть похожие каналы", "Hide similar channels")
        self.hideBirthdays = t("Скрыть дни рождения", "Hide birthdays")
        self.hideBirthdaysInfo = t("Баннер в списке чатов, подсказка в чате и конфетти в профиле.", "The chat list banner, the in-chat hint and profile confetti.")
        self.disableTelegramAI = t("Выключить ИИ Telegram", "Disable Telegram AI")
        self.disableTelegramAIInfo = t("Кнопка ИИ в поле ввода и пересказ длинных сообщений.", "The AI button in the input field and message summaries.")
        self.disableTonWallet = t("Выключить TON-кошелёк", "Disable TON wallet")
        self.disableTonWalletInfo = t("Прячет кошелёк, TON-баланс и TON Connect. Полностью применится после перезапуска.", "Hides the wallet, TON balance and TON Connect. Fully applies after a restart.")
        self.showOnlineCountAlways = t("Онлайн в шапке групп всегда", "Always show online in groups")
        self.showOnlineCountAlwaysInfo = t("«В сети» в шапке группы показывается даже когда онлайн один человек.", "Show the online count in the group header even when only one member is online.")
        self.hideProxySponsor = t("Скрыть спонсорский канал прокси", "Hide proxy sponsor channel")
        self.staticAnimatedAvatars = t("Статичные аватарки", "Static avatars")
        self.sendInlineWithoutVia = t("Инлайн без «via @bot»", "Inline without \"via @bot\"")
        self.sendInlineWithoutViaInfo = t("Результат инлайн-бота уходит как обычное сообщение от тебя.", "Inline bot results are sent as your own regular message.")
        self.showNameInsteadOfPhone = t("Имя вместо номера в шапке", "Name instead of number in header")
        self.showNameInsteadOfPhoneInfo = t("У людей не из контактов в шапке чата имя, а не номер.", "Chats with non-contacts show the name in the header instead of the number.")
        self.hidePhoneEverywhere = t("Скрыть номер во всех профилях", "Hide phone in all profiles")
        self.showMutualContactInHeader = t("Взаимный контакт в шапке", "Mutual contact in header")
        self.mutualContactShort = t("взаимный контакт", "mutual contact")
        self.showJoinDates = t("Даты вступления", "Join dates")
        self.showJoinDatesInfo = t("В профиле группы видно, когда ты вступил, а в профиле человека, открытом из группы, когда вступил он.", "Group profiles show when you joined; a person's profile opened from a group shows when they joined.")
        self.youJoined = t("Вы вступили", "You joined")
        self.memberSince = t("В группе с", "In group since")
        self.showInvisibleChars = t("Невидимые символы в именах", "Invisible characters in names")
        self.showInvisibleCharsInfo = t("Если имя целиком из невидимых символов, в профиле вместо пустоты будут их коды.", "If a name is made only of invisible characters, the profile shows their codes instead of a blank.")
        self.cleanSentLinks = t("Чистить ссылки при отправке", "Clean links when sending")
        self.cleanOpenedLinks = t("Чистить ссылки при открытии", "Clean links when opening")
        self.cleanLinksInfo = t("Убирает utm, fbclid, si и прочую слежку из ссылок. Ссылки t.me не трогаются.", "Strips utm, fbclid, si and other tracking from links. t.me links are left alone.")
        self.hideForeignAgentLabels = t("Скрывать плашки иноагентов", "Hide foreign agent labels")
        self.hideForeignAgentLabelsInfo = t("Убирает «НАСТОЯЩИЙ МАТЕРИАЛ… ИНОСТРАННЫМ АГЕНТОМ», сноски про Минюст и «18+» из текста сообщений.", "Removes Russian foreign agent disclaimers, Ministry of Justice footnotes and \"18+\" from message text.")
        self.hiddenRules = t("Скрытие по словам", "Hide by words")
        self.hiddenRulesInfo = t("По одному на строку. /regex/ или /regex/i — регулярка, иначе поиск подстроки без учёта регистра. Свои сообщения не скрываются.", "One per line. /regex/ or /regex/i is a regular expression, anything else is a case-insensitive substring. Your own messages are never hidden.")
        self.hiddenRulesPlaceholder = t("слово или /регулярка/", "word or /regex/")
        self.hiddenRulesError = { line, message in
            return ru ? "Строка \(line): \(message)" : "Line \(line): \(message)"
        }
        self.hiddenRulesCount = { count in
            if count == 0 {
                return ru ? "Нет" : "None"
            }
            return "\(count)"
        }
        self.showMediaInfoInViewer = t("DC и дата загрузки медиа", "Media DC and upload date")
        self.showMediaInfoInViewerInfo = t("В просмотрщике фото и видео рядом с датой видно дата-центр файла и когда он был загружен.", "The media viewer shows the file's data center and upload date next to the message date.")
        self.mediaUploaded = t("загружено", "uploaded")
        self.freeTranslation = t("Бесплатный перевод", "Free translation")
        self.freeTranslationInfo = t("Перевод сообщений и чатов через Google вместо платного перевода Telegram.", "Translates messages and chats with Google instead of Telegram's paid translation.")
        self.freeTranscription = t("Расшифровка без премиума", "Transcription without Premium")
        self.freeTranscriptionInfo = t("Голосовые и кружки расшифровываются на устройстве системным распознаванием речи.", "Voice and round video messages are transcribed on device with system speech recognition.")
        self.cameraSection = t("Камера", "Camera")
        self.cameraResolution = t("Разрешение видео", "Video resolution")
        self.cameraFrameRate = t("Частота кадров", "Frame rate")
        self.cameraInfo = t("Для камеры историй и вложений. 4K и 60 кадров работают, если камера телефона их тянет.", "For the story and attachment camera. 4K and 60 fps work when the phone's camera supports them.")
        self.roundVideoQuality = t("Качество кружков", "Round video quality")
        self.roundVideoQualityStandard = t("Обычное", "Standard")
        self.roundVideoQualityHigh = t("Высокое", "High")
        self.roundVideoQualityMax = t("Максимальное", "Maximum")
        self.roundVideoUltraWide = t("Кружки на 0.5x", "Round videos at 0.5x")
        self.roundVideoUltraWideInfo = t("Задняя камера пишет кружки на ультраширике. У фронталки ультраширика нет.", "The rear camera records round videos with the ultra-wide lens. Front cameras have no ultra-wide lens.")
        self.localName = t("Локальное имя", "Local name")
        self.localNamePlaceholder = t("Имя", "Name")
        self.localNameInfo = t("Это имя видишь только ты: в списке чатов, шапке и сообщениях.", "Only you see this name: in the chat list, header and messages.")
        self.localNameRemove = t("Убрать локальное имя", "Remove local name")
        self.localNames = t("Локальные имена", "Local names")
        self.localNamesInfo = t("Задаются через «…» в профиле.", "Set them from the profile's \"…\" menu.")
        self.localNamesEmpty = t("Локальных имён нет", "No local names")
        self.lockChat = t("Заблокировать чат", "Lock chat")
        self.unlockChat = t("Снять блокировку", "Remove lock")
        self.lockedChats = t("Заблокированные чаты", "Locked chats")
        self.lockedChatsEmpty = t("Заблокированных чатов нет", "No locked chats")
        self.lockedChatPreview = t("Чат заблокирован", "Chat is locked")
        self.localPassword = t("Локальный пароль", "Local password")
        self.localPasswordInfo = t("Пароль mad для заблокированных чатов и трат звёзд. Хранится только на этом устройстве, к паролю Telegram отношения не имеет.", "mad's password for locked chats and spending stars. Stored only on this device, separate from your Telegram passcode.")
        self.localPasswordSet = t("Задать пароль", "Set password")
        self.localPasswordChange = t("Сменить пароль", "Change password")
        self.localPasswordRemove = t("Убрать пароль", "Remove password")
        self.localPasswordNotSet = t("Не задан", "Not set")
        self.lockTypePin = t("Пин-код", "PIN")
        self.lockTypePassword = t("Пароль", "Password")
        self.lockTypePattern = t("Графический ключ", "Pattern")
        self.lockUseBiometrics = t("Разблокировка по биометрии", "Unlock with biometrics")
        self.enterCode = t("Введи код", "Enter code")
        self.enterPassword = t("Введи пароль", "Enter password")
        self.drawPattern = t("Нарисуй ключ", "Draw pattern")
        self.newCode = t("Придумай код", "Create a code")
        self.newPassword = t("Придумай пароль", "Create a password")
        self.newPattern = t("Нарисуй новый ключ", "Draw a new pattern")
        self.repeatCode = t("Повтори", "Repeat")
        self.repeatPattern = t("Нарисуй ещё раз", "Draw it again")
        self.lockMismatch = t("Не совпадает, давай заново", "Doesn't match, try again")
        self.lockWrong = t("Неверно", "Wrong")
        self.lockPatternTooShort = t("Соедини хотя бы 4 точки", "Connect at least 4 dots")
        self.lockNeedPasswordFirst = t("Сначала задай локальный пароль в настройках mad → Приватность.", "Set a local password first in mad settings → Privacy.")
        self.lockUnlockReason = t("Разблокировать", "Unlock")
        self.lockDone = t("Готово", "Done")
        self.lockCancel = t("Отмена", "Cancel")
        self.skipFor = t("Не спрашивать", "Don't ask")
        self.skipNone = t("каждый раз", "every time")
        self.skip15m = t("15 минут", "15 minutes")
        self.skip1h = t("1 час", "1 hour")
        self.skip1d = t("сутки", "1 day")
        self.skipUntilRestart = t("до перезапуска", "until restart")
        self.spendLock = t("Пароль на траты", "Password for spending")
        self.spendLockInfo = t("Перед тратой звёзд спрашивать локальный пароль. В окне пароля можно отключить вопрос на время.", "Ask for the local password before spending stars. The prompt can turn itself off for a while.")
        self.spendReactions = t("Платные реакции", "Paid reactions")
        self.spendMessages = t("Платные сообщения", "Paid messages")
        self.spendGifts = t("Подарки", "Gifts")
        self.spendTransfer = t("Передача и продажа NFT", "NFT transfer and sale")
        self.spendPayments = t("Оплата ботам и подписки", "Bot payments and subscriptions")
        self.spendReason = t("Подтверди трату звёзд", "Confirm spending stars")
        self.notifyPresence = t("Уведомлять об онлайне", "Notify when online")
        self.notifyPresenceOn = t("Слежка за онлайном включена", "Online alerts on")
        self.notifyPresenceOff = t("Слежка за онлайном выключена", "Online alerts off")
        self.reactionNotification = { reaction, text in
            return ru ? "\(reaction) на «\(text)»" : "\(reaction) to “\(text)”"
        }
        self.exactViewCounts = ru ? "Точное число просмотров" : "Exact view counts"
        self.exactViewCountsInfo = ru ? "5\u{202F}214 вместо 5,2K под постами в каналах." : "5\u{202F}214 instead of 5.2K under channel posts."
        self.changelogMute = ru ? "Без уведомлений о версиях" : "No update notifications"
        self.changelogUnmute = ru ? "Уведомлять о новых версиях" : "Notify about new versions"
        self.changelogHide = ru ? "Больше не показывать" : "Never show again"
        self.madRepository = ru ? "исходный код" : "source code"
        self.madReleasesChannel = ru ? "канал с релизами" : "releases channel"
        self.changelogStatus = ru ? "новости и фишки клиента" : "client news and tips"
        self.changelogShow = ru ? "Показать чат «что нового»" : "Show the what's new chat"
        self.changelogRestored = ru ? "Чат «что нового» снова в списке чатов" : "The what's new chat is back in the chat list"
        self.changelogHidden = ru ? "Чат «что нового» больше не появится. Вернуть можно в mad → прочее" : "The what's new chat won't appear again. Bring it back in mad → other"
        self.reactionNotificationTitle = ru ? "Новая реакция" : "New reaction"
        self.reactionNotificationMessage = ru ? "твоё сообщение" : "your message"
        self.userCameOnline = { name in
            return ru ? "\(name) в сети" : "\(name) is online"
        }
        self.userWentOffline = { name in
            return ru ? "\(name) вышел(а) из сети" : "\(name) went offline"
        }
        self.presenceWatched = t("Слежка за онлайном", "Online alerts")
        self.presenceWatchedInfo = t("Уведомление, когда человек заходит в сеть и выходит. Включается через «…» в профиле. Работает, пока mad запущен.", "A notification when a person comes online or goes offline. Turn it on from the profile's \"…\" menu. Works while mad is running.")
        self.presenceWatchedEmpty = t("Никого", "Nobody")
        self.loginAsBot = t("Войти как бот", "Log in as bot")
        self.botTokenTitle = t("Токен бота", "Bot token")
        self.botTokenText = t("Токен из @BotFather. Многое в клиенте под ботом работать не будет.", "The token from @BotFather. Much of the app won't work for a bot account.")
        self.botTokenPlaceholder = "123456:ABC-DEF"
        self.botTokenInvalid = t("Токен не подошёл", "Invalid token")
        self.backupSection = t("Резервная копия", "Backup")
        self.exportSettings = t("Экспорт настроек", "Export settings")
        self.importSettings = t("Импорт настроек", "Import settings")
        self.backupInfo = t("Все настройки mad в одном файле. Ключи ИИ-агента и пароли не выгружаются.", "All mad settings in one file. AI agent keys and passwords are not included.")
        self.settingsImported = t("Настройки загружены", "Settings imported")
        self.settingsImportFailed = t("Не удалось прочитать файл", "Could not read the file")
        self.whatsNewTitle = t("Что нового в mad", "What's new in mad")
        self.whatsNewDone = t("Круто", "Got it")
        self.whatsNewSettings = t("Новое можно включить прямо тут:", "Turn the new stuff on right here:")
        self.remove = t("Убрать", "Remove")
        self.categoryHiding = t("Скрытие", "Hiding")
        self.hidingTextSection = t("Текст сообщений", "Message text")
        self.whereChatList = t("в списке чатов", "in the chat list")
        self.whereChats = t("в чатах", "in chats")
        self.whereProfile = t("в профиле", "in profiles")
        self.whereMessages = t("в сообщениях", "in messages")
        self.whereNotifications = t("в уведомлениях", "in notifications")
        self.similarInChat = t("подборка в канале после вступления", "carousel after joining a channel")
        self.similarInProfile = t("вкладка в профиле канала", "tab in channel profile")
        self.similarBots = t("похожие боты", "similar bots")
        self.aiInput = t("кнопка ИИ в поле ввода", "AI button in the input field")
        self.aiSummaries = t("пересказ сообщений", "message summaries")
        self.joinDateMine = t("когда вступил я", "when I joined")
        self.joinDateMembers = t("когда вступили участники", "when members joined")
        self.voiceMessages = t("голосовые", "voice messages")
        self.roundMessages = t("кружки", "round videos")
        self.phoneOthers = t("в чужих профилях", "in other profiles")
        self.phoneMine = t("в своём профиле", "in my profile")
        self.linksSection = t("ссылки", "links")
        self.accounts = MadAccountsStrings(languageCode: languageCode)
    }
}

public struct MadAccountsStrings {
    public let title: String
    public let edit: String
    public let allAccounts: (Int) -> String
    public let verified: String
    public let designSection: String
    public let designRow: String
    public let designList: String
    public let designInfo: String
    public let mySection: String
    public let empty: String
    public let add: String
    public let reorder: String
    public let done: String
    public let hidden: String
    public let info: String
    public let addTitle: String
    public let addHeadline: String
    public let addSubtitle: String
    public let filterAll: String
    public let filterSocial: String
    public let filterGames: String
    public let filterMusic: String
    public let filterWork: String
    public let statusAdded: String
    public let statusLogin: String
    public let statusSoon: String
    public let addFooter: String
    public let linked: (String) -> String
    public let linkFailed: String
    public let unavailable: String
    public let clientIdTitle: (String) -> String
    public let clientIdText: (String) -> String
    public let clientIdInvalid: String
    public let clientIdContinue: String
    public let clientIdCancel: String
    public let clientIdCopyRedirect: String
    public let domainTitle: String
    public let domainText: String
    public let domainInvalid: String
    public let domainVerifyTitle: String
    public let domainVerifyText: (String, String) -> String
    public let domainCopy: String
    public let domainCheck: String
    public let domainNotFound: String
    public let domainDraftDelete: String
    public let iconSection: String
    public let iconGlobe: String
    public let iconFavicon: String
    public let iconFaviconInfo: String
    public let domainLater: String
    public let domainDraftStatus: String
    public let draftsSection: String
    public let showInProfile: String
    public let showInProfileInfo: String
    public let openProfile: String
    public let refresh: String
    public let refreshed: String
    public let labelSection: String
    public let labelHandle: (String) -> String
    public let labelName: String
    public let inProfileSection: String
    public let disconnect: String
    public let disconnectConfirm: (String) -> String
    public let disconnectAction: String
    public let loadFailed: String
    public let retry: String
    public let serviceUnavailable: String
    public let searchKeywords: [String]

    public init(languageCode: String) {
        func t(_ ru: String, _ en: String) -> String {
            return languageCode == "ru" ? ru : en
        }
        let ru = languageCode == "ru"

        self.title = t("Аккаунты", "Accounts")
        self.edit = t("Изменить", "Edit")
        self.allAccounts = { count in
            return ru ? "Все аккаунты · \(count)" : "All accounts · \(count)"
        }
        self.verified = t("Владение подтверждено", "Ownership verified")
        self.designSection = t("Вид в профиле", "Profile layout")
        self.designRow = t("В строчку", "Row")
        self.designList = t("Список", "List")
        self.designInfo = t("Так блок увидят все пользователи mad.", "Every mad user sees the block this way.")
        self.mySection = t("Мои аккаунты", "My accounts")
        self.empty = t("Пока ничего не привязано", "Nothing linked yet")
        self.add = t("Добавить аккаунт", "Add account")
        self.reorder = t("Порядок", "Reorder")
        self.done = t("Готово", "Done")
        self.hidden = t("скрыт", "hidden")
        self.info = t("Аккаунты видят только пользователи mad. Каждая площадка подтверждается входом.", "Only mad users see your accounts. Every platform is verified by signing in.")
        self.addTitle = t("Добавить аккаунт", "Add account")
        self.addHeadline = t("Твои площадки", "Your platforms")
        self.addSubtitle = t("Собери свои аккаунты в одном профиле.", "Collect your accounts in one profile.")
        self.filterAll = t("Все", "All")
        self.filterSocial = t("Соцсети", "Social")
        self.filterGames = t("Игры", "Games")
        self.filterMusic = t("Музыка", "Music")
        self.filterWork = t("Работа", "Work")
        self.statusAdded = t("Добавлен", "Added")
        self.statusLogin = t("Через вход", "Sign in")
        self.statusSoon = t("Скоро", "Soon")
        self.addFooter = t("Вход на площадку подтверждает, что аккаунт твой. Пароли mad не видит.", "Signing in proves the account is yours. mad never sees your passwords.")
        self.linked = { name in
            return ru ? "\(name) привязан" : "\(name) linked"
        }
        self.linkFailed = t("Не получилось привязать аккаунт", "Couldn't link the account")
        self.unavailable = t("Эта площадка пока недоступна", "This platform isn't available yet")
        self.clientIdTitle = { name in
            return ru ? "Client ID для \(name)" : "\(name) Client ID"
        }
        self.clientIdText = { redirect in
            return ru ? "Создай своё приложение на developer.spotify.com, в Redirect URIs добавь\n\(redirect)\nи вставь сюда его Client ID. Секрет не нужен." : "Create your own app on developer.spotify.com, add\n\(redirect)\nto its Redirect URIs and paste its Client ID here. No secret is needed."
        }
        self.clientIdInvalid = t("Client ID — это 32 символа из цифр и букв a–f", "A Client ID is 32 characters of digits and letters a–f")
        self.clientIdContinue = t("Продолжить", "Continue")
        self.clientIdCancel = t("Отмена", "Cancel")
        self.domainTitle = t("Свой домен", "Your domain")
        self.domainText = t("Введи домен, например example.com. Подтвердим его через DNS.", "Enter a domain like example.com. We'll verify it through DNS.")
        self.domainInvalid = t("Это не похоже на домен", "That doesn't look like a domain")
        self.domainVerifyTitle = t("Подтверди домен", "Verify the domain")
        self.domainVerifyText = { name, value in
            return ru ? "Добавь в DNS домена TXT-запись\n\nимя: \(name)\nзначение: \(value)\n\nПодойдёт и такая же запись на самом домене. DNS иногда обновляется до часа." : "Add a TXT record to the domain's DNS\n\nname: \(name)\nvalue: \(value)\n\nThe same record on the domain itself works too. DNS can take up to an hour to update."
        }
        self.domainCopy = t("Скопировать значение", "Copy value")
        self.domainCheck = t("Проверить", "Verify")
        self.iconSection = t("Иконка", "Icon")
        self.iconGlobe = t("Глобус", "Globe")
        self.iconFavicon = t("Favicon сайта", "Site favicon")
        self.iconFaviconInfo = t("Favicon подгружается через DuckDuckGo, сам сайт не узнаёт, кто смотрит профиль.", "The favicon is loaded through DuckDuckGo, so the site doesn't learn who views the profile.")
        self.domainDraftDelete = t("Удалить черновик", "Delete draft")
        self.domainLater = t("Позже", "Later")
        self.domainDraftStatus = t("ждём TXT-запись", "waiting for the TXT record")
        self.draftsSection = t("В процессе", "In progress")
        self.domainNotFound = t("Запись пока не видна. Подожди немного и проверь ещё раз", "The record isn't visible yet. Wait a bit and verify again")
        self.clientIdCopyRedirect = t("Скопировать Redirect URI", "Copy Redirect URI")
        self.showInProfile = t("Показывать в профиле", "Show in profile")
        self.showInProfileInfo = t("В профиле будут видны площадка, имя аккаунта и ссылка.", "Your profile shows the platform, the account name and a link.")
        self.openProfile = t("Открыть профиль", "Open profile")
        self.refresh = t("Обновить данные", "Refresh details")
        self.refreshed = t("Данные обновлены", "Details updated")
        self.labelSection = t("Подпись в профиле", "Shown in profile as")
        self.labelHandle = { platform in
            if platform == "steam" {
                return ru ? "Адрес профиля" : "Profile URL"
            }
            return ru ? "Логин" : "Username"
        }
        self.labelName = t("Ник", "Display name")
        self.inProfileSection = t("В профиле", "In profile")
        self.disconnect = t("Отключить аккаунт", "Disconnect account")
        self.disconnectConfirm = { name in
            return ru ? "Отключить \(name)? Аккаунт пропадёт из профиля." : "Disconnect \(name)? It will disappear from your profile."
        }
        self.disconnectAction = t("Отключить", "Disconnect")
        self.loadFailed = t("Не получилось загрузить", "Couldn't load")
        self.retry = t("Повторить", "Retry")
        self.serviceUnavailable = t("Сервис аккаунтов пока недоступен", "The accounts service isn't available yet")
        self.searchKeywords = ["Steam", "GitHub", "GitLab", "Spotify", "SoundCloud", "Last.fm", "Twitch", "Discord", "Reddit", t("площадки", "platforms")]
    }
}
