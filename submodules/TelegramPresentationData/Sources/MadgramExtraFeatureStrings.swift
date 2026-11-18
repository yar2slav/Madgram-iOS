import Foundation

public struct MadgramExtraFeatureStrings {
    public let contentSection: String
    public let contentInfo: String
    public let hidePromotedPosts: String
    public let hidePromotedPostsInfo: String
    public let promotedKeywords: String
    public let promotedKeywordsInfo: String
    public let promotedKeywordsPlaceholder: String
    public let promotedKeywordsReset: String
    public let hideSponsoredMessages: String
    public let hideSponsoredMessagesInfo: String
    public let revealTextSpoilers: String
    public let revealMediaSpoilers: String
    public let revealSpoilersInfo: String
    public let spoilersPrivate: String
    public let spoilersGroups: String
    public let spoilersChannels: String
    public let spoilersSaved: String
    public let spoilersProfileMedia: String

    public let showOnlineInGroups: String
    public let showOnlineInGroupsInfo: String

    public let deletedOpacity: String
    public let deletedOpacityInfo: String

    public let ghostInChat: String
    public let ghostInChatDefault: String
    public let ghostInChatOn: String
    public let ghostInChatOff: String
    public let ghostExceptions: String
    public let ghostExceptionsInfo: String
    public let ghostExceptionsEmpty: String
    public let ghostExceptionOn: String
    public let ghostExceptionOff: String
    public let ghostExceptionRemove: String

    public let exportChat: String
    public let exportFormatTitle: String
    public let exportFormatText: String
    public let exportFormatJson: String
    public let exportFormatHtml: String
    public let exportProgress: (Int) -> String
    public let exportPreparing: String
    public let exportKeepOpen: String
    public let exportFailed: String
    public let exportEmpty: String
    public let exportLabelDeleted: String
    public let exportLabelEdited: String
    public let exportLabelEditHistory: String
    public let exportLabelMedia: String
    public let exportLabelReply: String
    public let exportLabelForwarded: String


    public let localPremiumInfo: String
    public let localEmojiStatusSaved: String

    public let timeSeconds: String
    public let timeSecondsInfo: String
    public let secondsInMessages: String
    public let secondsInLastSeen: String

    public let archiveExcludeHeader: String
    public let archiveExcludeBots: String
    public let archiveExcludeSavedMessages: String
    public let archiveExcludeChannels: String
    public let archiveExcludeGroups: String
    public let archiveExcludePrivateChats: String
    public let archiveExcludeInfo: String

    public let copyEmojiId: String
    public let emojiIdCopied: String
    public let copyPackOwnerId: String
    public let packOwnerIdCopied: String

    public let chatCompanion: String
    public let chatCompanionInfo: String
    public let companionSettings: String
    public let aiAgent: String
    public let aiAgentNotConfigured: String
    public let categoriesHeader: String
    public let categoryInterface: String
    public let categoryChats: String
    public let categoryMessages: String
    public let categoryNotifications: String
    public let categoryPrivacy: String
    public let categoryOther: String

    public init(languageCode: String) {
        func t(_ ru: String, _ uk: String, _ en: String) -> String {
            switch languageCode {
            case "ru":
                return ru
            case "uk":
                return uk
            default:
                return en
            }
        }

        self.contentSection = t("Каналы и контент", "Канали та контент", "Channels and content")
        self.contentInfo = t("Скрытое не удаляется, его просто не видно.", "Приховане не видаляється, його просто не видно.", "Hidden content isn't deleted, it's just not shown.")
        self.hidePromotedPosts = t("Скрывать рекламные посты", "Приховувати рекламні пости", "Hide promoted posts")
        self.hidePromotedPostsInfo = t("Прячет посты каналов с маркировкой рекламы: erid, ИНН рекламодателя, #реклама и ключевые слова из списка. Только в каналах.", "Ховає пости каналів із маркуванням реклами: erid, ІПН рекламодавця, #реклама та ключові слова зі списку. Лише в каналах.", "Hides channel posts marked as ads: erid, advertiser tax ID, #реклама and the keywords from the list. Channels only.")
        self.promotedKeywords = t("Ключевые слова рекламы", "Ключові слова реклами", "Ad keywords")
        self.promotedKeywordsInfo = t("По одному на строку, регистр не важен. erid, ИНН и #реклама ловятся всегда.", "По одному в рядку, регістр не важливий. erid, ІПН і #реклама ловляться завжди.", "One per line, case-insensitive. erid, tax IDs and #реклама are always caught.")
        self.promotedKeywordsPlaceholder = t("#реклама", "#реклама", "#ad")
        self.promotedKeywordsReset = t("Сбросить по умолчанию", "Скинути до типових", "Reset to Default")
        self.hideSponsoredMessages = t("Скрывать спонсорские сообщения", "Приховувати спонсорські повідомлення", "Hide sponsored messages")
        self.hideSponsoredMessagesInfo = t("Официальная реклама Telegram внизу каналов.", "Офіційна реклама Telegram унизу каналів.", "Telegram's own ads at the bottom of channels.")
        self.revealTextSpoilers = t("Показывать текст под спойлером", "Показувати текст під спойлером", "Show text under spoilers")
        self.revealMediaSpoilers = t("Показывать медиа под спойлером", "Показувати медіа під спойлером", "Show media under spoilers")
        self.spoilersPrivate = t("В личных чатах", "В особистих чатах", "In private chats")
        self.spoilersGroups = t("В группах", "У групах", "In groups")
        self.spoilersChannels = t("В каналах", "У каналах", "In channels")
        self.spoilersSaved = t("В избранном", "В обраному", "In Saved Messages")
        self.spoilersProfileMedia = t("Медиа во вкладке профиля", "Медіа у вкладці профілю", "Media in the profile tab")
        self.revealSpoilersInfo = t("Ниже можно выбрать, где снимать спойлеры. В избранном по умолчанию не снимаются.", "Нижче можна вибрати, де знімати спойлери. В обраному за замовчуванням не знімаються.", "Choose below where spoilers are removed. Saved Messages are left alone by default.")

        self.showOnlineInGroups = t("Онлайн у аватарок в группах", "Онлайн біля аватарок у групах", "Online dot on group avatars")
        self.showOnlineInGroupsInfo = t("Зелёная точка у аватарки участника рядом с его сообщениями, пока он в сети.", "Зелена крапка біля аватарки учасника поруч із його повідомленнями, поки він у мережі.", "A green dot on a member's avatar next to their messages while they are online.")

        self.deletedOpacity = t("Прозрачность удалённых", "Прозорість видалених", "Deleted message opacity")
        self.deletedOpacityInfo = t("Насколько видны сохранённые удалённые сообщения в чате.", "Наскільки видно збережені видалені повідомлення в чаті.", "How visible saved deleted messages are in the chat.")

        self.ghostInChat = t("Призрак в этом чате", "Привид у цьому чаті", "Ghost Mode in This Chat")
        self.ghostInChatDefault = t("Как везде", "Як скрізь", "Default")
        self.ghostInChatOn = t("Включён", "Увімкнено", "On")
        self.ghostInChatOff = t("Выключен", "Вимкнено", "Off")
        self.ghostExceptions = t("Исключения по чатам", "Винятки для чатів", "Chat Exceptions")
        self.ghostExceptionsInfo = t("В отдельном чате можно включить или выключить призрака через «…» в профиле. Статус «В сети» общий для аккаунта и в чате не настраивается.", "В окремому чаті привида можна ввімкнути чи вимкнути через «…» у профілі. Статус «У мережі» спільний для акаунта й у чаті не налаштовується.", "Ghost Mode can be turned on or off for one chat from the profile's \"…\" menu. Online status is per account and cannot be set per chat.")
        self.ghostExceptionsEmpty = t("Исключений нет", "Винятків немає", "No exceptions")
        self.ghostExceptionOn = t("призрак вкл.", "привид увімк.", "ghost on")
        self.ghostExceptionOff = t("призрак выкл.", "привид вимк.", "ghost off")
        self.ghostExceptionRemove = t("Убрать", "Прибрати", "Remove")

        self.exportChat = t("Экспорт чата", "Експорт чату", "Export Chat")
        self.exportFormatTitle = t("Только текст, медиа не выгружается. Удалённые и правки из архива попадут в экспорт.", "Лише текст, медіа не вивантажуються. Видалені й правки з архіву потраплять в експорт.", "Text only, media is not exported. Deleted messages and edits from the archive are included.")
        self.exportFormatText = t("Текст (TXT)", "Текст (TXT)", "Text (TXT)")
        self.exportFormatJson = "JSON"
        self.exportFormatHtml = "HTML"
        self.exportProgress = { count in
            switch languageCode {
            case "ru":
                return "Выгружено сообщений: \(count)"
            case "uk":
                return "Вивантажено повідомлень: \(count)"
            default:
                return "Messages exported: \(count)"
            }
        }
        self.exportPreparing = t("Готовлю экспорт…", "Готую експорт…", "Preparing export…")
        self.exportKeepOpen = t("Не закрывай это окно, пока идёт экспорт сообщений.", "Не закривай це вікно, поки триває експорт повідомлень.", "Keep this window open until the messages are exported.")
        self.exportFailed = t("Не удалось выгрузить чат.", "Не вдалося вивантажити чат.", "Could not export the chat.")
        self.exportEmpty = t("В этом чате нет сообщений.", "У цьому чаті немає повідомлень.", "This chat has no messages.")
        self.exportLabelDeleted = t("удалено", "видалено", "deleted")
        self.exportLabelEdited = t("изменено", "змінено", "edited")
        self.exportLabelEditHistory = t("раньше", "раніше", "before")
        self.exportLabelMedia = t("медиа", "медіа", "media")
        self.exportLabelReply = t("ответ на", "відповідь на", "reply to")
        self.exportLabelForwarded = t("переслано от", "переслано від", "forwarded from")


        self.localPremiumInfo = t("Аккаунт выглядит как Premium: звезда, эмодзи-статус, премиум-иконки, больше папок и закрепов, без рекламы Premium. Это видите только вы, поэтому премиум-реакции, большие файлы, расшифровка голосовых и папки сверх обычного лимита не заработают.", "Акаунт виглядає як Premium: зірка, емодзі-статус, преміум-іконки, більше папок і закріплень, без реклами Premium. Це бачите лише ви, тому преміум-реакції, великі файли, розшифрування голосових і папки понад звичайний ліміт не запрацюють.", "Your account looks like Premium: the star, an emoji status, premium icons, more folders and pins, no Premium ads. Only you see it, so premium reactions, large files, voice transcription and folders above the usual limit won't work.")
        self.localEmojiStatusSaved = t("Этот статус видите только вы.", "Цей статус бачите лише ви.", "Only you can see this status.")
        self.timeSeconds = t("Секунды во времени", "Секунди в часі", "Seconds in Time")
        self.timeSecondsInfo = t("Добавляет секунды ко времени сообщений и статуса «был(а) в сети». В открытом чате изменения появятся после повторного входа.", "Додає секунди до часу повідомлень і статусу «був(ла) у мережі». У відкритому чаті зміни з'являться після повторного входу.", "Adds seconds to message times and to \"last seen\". An open chat updates after you reopen it.")
        self.secondsInMessages = t("В сообщениях", "У повідомленнях", "In Messages")
        self.secondsInLastSeen = t("В «был(а) в сети»", "У «був(ла) у мережі»", "In Last Seen")

        self.archiveExcludeHeader = t("Не сохранять", "Не зберігати", "Don't Save")
        self.archiveExcludeBots = t("Чаты с ботами", "Чати з ботами", "Bot Chats")
        self.archiveExcludeSavedMessages = t("Избранное", "Збережене", "Saved Messages")
        self.archiveExcludeChannels = t("Каналы", "Канали", "Channels")
        self.archiveExcludeGroups = t("Группы", "Групи", "Groups")
        self.archiveExcludePrivateChats = t("Личные чаты", "Особисті чати", "Private Chats")
        self.archiveExcludeInfo = t("В отмеченных чатах удалённые и изменённые сообщения не сохраняются.", "У позначених чатах видалені та змінені повідомлення не зберігаються.", "Deleted and edited messages aren't saved in the selected chats.")

        self.copyEmojiId = t("Скопировать ID эмодзи", "Скопіювати ID емодзі", "Copy Emoji ID")
        self.emojiIdCopied = t("ID эмодзи скопирован", "ID емодзі скопійовано", "Emoji ID copied")
        self.copyPackOwnerId = t("Скопировать ID владельца", "Скопіювати ID власника", "Copy Owner ID")
        self.packOwnerIdCopied = t("ID владельца скопирован", "ID власника скопійовано", "Owner ID copied")

        self.chatCompanion = t("Компаньон в личных чатах", "Компаньйон в особистих чатах", "Companion in private chats")
        self.chatCompanionInfo = t("3D-уточка над полем ввода в переписках с людьми. Её можно покрутить пальцем.", "3D-качечка над полем введення в переписках з людьми. Її можна покрутити пальцем.", "A 3D duck above the input field in chats with people. Drag to spin it.")
        self.companionSettings = t("Настроить компаньона", "Налаштувати компаньйона", "Customize Companion")
        self.aiAgent = t("ИИ-агент", "ШІ-агент", "AI Agent")
        self.aiAgentNotConfigured = t("Не настроен", "Не налаштований", "Not set up")
        self.categoriesHeader = t("КАТЕГОРИИ", "КАТЕГОРІЇ", "CATEGORIES")
        self.categoryInterface = t("Интерфейс", "Інтерфейс", "Interface")
        self.categoryChats = t("Чаты и каналы", "Чати та канали", "Chats and Channels")
        self.categoryMessages = t("Сообщения", "Повідомлення", "Messages")
        self.categoryNotifications = t("Уведомления", "Сповіщення", "Notifications")
        self.categoryPrivacy = t("Приватность", "Приватність", "Privacy")
        self.categoryOther = t("Прочее", "Інше", "Other")
    }
}
