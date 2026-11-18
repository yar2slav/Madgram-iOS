import Foundation

public struct GhostModeFeatureStrings {
    public let title: String
    public let on: String
    public let off: String
    public let masterInfo: String
    public let suppressMessageReadReceipts: String
    public let suppressMessageReadReceiptsInfo: String
    public let suppressStoryReadReceipts: String
    public let suppressStoryReadReceiptsInfo: String
    public let suppressOnlineStatus: String
    public let suppressOnlineStatusInfo: String
    public let suppressTypingStatus: String
    public let suppressTypingStatusInfo: String
    public let revealOnInteractions: String
    public let revealOnInteractionsInfo: String
    public let goOfflineAutomatically: String
    public let goOfflineAutomaticallyInfo: String
    public let markViewedMessagesAsRead: String
    public let readReceiptFailed: String
    public let keepViewOnceMedia: String
    public let keepViewOnceMediaInfo: String
    public let burnViewOnceMedia: String
    public let activeIndicator: String
    public let readAllLocally: String
    public let readAllOnServer: String
    public let readAllChats: String
    public let readAllArchive: String
    public let readAllEverything: String
    public let hideSection: String
    public let behaviorSection: String
}

public struct LocalMessageArchiveFeatureStrings {
    public let title: String
    public let archiveDeletedMessages: String
    public let archiveDeletedMessagesInfo: String
    public let archiveEditedMessages: String
    public let archiveEditedMessagesInfo: String
    public let archiveChats: String
    public let archiveChatsInfo: String
    public let deletedMessageMarker: String
    public let deletedMessageMarkerInfo: String
    public let keepBetweenLaunches: String
    public let keepBetweenLaunchesInfo: String
    public let mediaLimit: String
    public let mediaLimitInfo: String
    public let archiveUsage: String
    public let clearMedia: String
    public let clearArchive: String
    public let clearActionsInfo: String
    public let history: String
    public let deleted: String
    public let deleteForMe: String
    public let deletedMessageSavedLocally: String
    public let richMessage: String
    public let emptyMessage: String
    public let mediaMessageTapToOpen: String
    public let gigabytesSuffix: String
    public let historyTitle: String
    public let disappearingMediaLimit: String
    public let disappearingMediaLimitInfo: String
    public let saveSection: String
    public let storageSection: String

    public let usage: (Int, Int, String) -> String
    public let versionCount: (Int) -> String
}

public struct MadgramFeatureStrings {
    public let title: String
    public let privacySection: String
    public let privacyInfo: String
    public let messagesSection: String
    public let messagesInfo: String
    public let interfaceSection: String
    public let classicDesign: String
    public let classicDesignInfo: String
    public let otherSection: String
    public let forwardWithoutAuthor: String
    public let powerSaving: String
    public let powerSavingInfo: String
}

public struct LocalPremiumFeatureStrings {
    public let title: String
    public let info: String
}

public struct MessageFilterFeatureStrings {
    public let title: String
    public let hideBlockedUsers: String
    public let hideBlockedUsersInfo: String
    public let hiddenPeersSection: String
    public let hiddenPeersInfo: String
    public let hiddenPeersEmpty: String
    public let hideMessages: String
    public let showMessages: String
    public let hiddenMessagePlaceholder: String
    public let messagesHidden: String
    public let messagesShown: String
    public let show: String
    public let shareLinkWarningTitle: String
    public let shareLinkWarningText: String
    public let shareLinkWarningOpen: String
}

public struct MessageShotFeatureStrings {
    public let title: String
    public let action: String
    public let contentSection: String
    public let showWallpaper: String
    public let darkTheme: String
    public let showAvatar: String
    public let showTime: String
    public let showReactions: String
    public let revealSpoilers: String
    public let share: String
    public let saveToPhotos: String
    public let copy: String
    public let savedToPhotos: String
    public let copied: String
    public let saveFailed: String

    public let selectionLimit: (Int) -> String
}

public struct DeleteOwnMessagesFeatureStrings {
    public let menuItem: String
    public let confirmTitle: String
    public let confirmText: String
    public let confirmAction: String
    public let preparing: String
    public let progress: (Int, Int) -> String
    public let completed: (Int) -> String
    public let empty: String
}

public struct InterfaceTuningFeatureStrings {
    public let title: String
    public let tabsSection: String
    public let profilesSection: String
    public let storiesSection: String
    public let chatsSection: String
    public let cameraSection: String

    public let concealBottomBar: String
    public let concealBottomBarInfo: String
    public let showContactsShortcut: String
    public let showContactsShortcutInfo: String
    public let showCallsShortcut: String
    public let showCallsShortcutInfo: String
    public let showTabLabels: String
    public let showTabLabelsInfo: String
    public let showSearchShortcut: String
    public let showSearchShortcutInfo: String
    public let stretchBottomBar: String
    public let stretchBottomBarInfo: String

    public let showProfileIdentifiers: String
    public let showProfileIdentifiersInfo: String
    public let showDataCenter: String
    public let showDataCenterInfo: String
    public let showRegistrationDate: String
    public let showRegistrationDateInfo: String
    public let showChatCreationDate: String
    public let showChatCreationDateInfo: String
    public let profileIdentifierLabel: String
    public let mutualContact: String
    public let dataCenterLabel: String
    public let registrationDateLabel: String
    public let chatCreationDateLabel: String

    public let showCallbackData: String
    public let showCallbackDataInfo: String
    public let callbackDataTitle: String

    public let hideStoryStrip: String
    public let hideStoryStripInfo: String
    public let showAppBadge: String
    public let showAppBadgeInfo: String
    public let disableStoryCameraSwipe: String
    public let disableStoryCameraSwipeInfo: String
    public let confirmStoryOpen: String
    public let confirmStoryOpenInfo: String
    public let allowStoryRepost: String
    public let allowStoryRepostInfo: String

    public let startRoundVideoWithRearCamera: String
    public let startRoundVideoWithRearCameraInfo: String
    public let hideGalleryCamera: String
    public let hideGalleryCameraInfo: String
    public let hidePhoneInSettings: String
    public let hidePhoneInSettingsInfo: String
    public let hideBusinessBotPanel: String
    public let hideBusinessBotPanelInfo: String
    public let businessBotPanelExceptions: String
    public let businessBotPanelExceptionsInfo: String
    public let businessBotPanelAddException: String
    public let businessBotPanelNotManaged: String
    public let businessBotPanelShow: String
    public let businessBotPanelHideInChat: String

    public let restartNotice: String
    public let storyConfirmationTitle: String
    public let storyConfirmationText: String
    public let storyConfirmationAction: String
}

public struct LocalNotificationFeatureStrings {
    public let title: String
    public let info: String
}

public struct LocalFeatureStrings {
    public let localNotifications: LocalNotificationFeatureStrings
    public let ghostMode: GhostModeFeatureStrings
    public let localMessageArchive: LocalMessageArchiveFeatureStrings
    public let interfaceTuning: InterfaceTuningFeatureStrings
    public let madgram: MadgramFeatureStrings
    public let localPremium: LocalPremiumFeatureStrings
    public let messageFilter: MessageFilterFeatureStrings
    public let messageShot: MessageShotFeatureStrings
    public let deleteOwnMessages: DeleteOwnMessagesFeatureStrings
    public let extras: MadgramExtraFeatureStrings
    public let more: MadgramMoreFeatureStrings

    public init(strings: PresentationStrings) {
        let languageCode = strings.baseLanguageCode
            .lowercased()
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map(String.init) ?? "en"
        self.extras = MadgramExtraFeatureStrings(languageCode: languageCode)
        self.more = MadgramMoreFeatureStrings(languageCode: languageCode)

        switch languageCode {
        case "ru":
            self.localNotifications = LocalNotificationFeatureStrings(
                title: "Локальные уведомления",
                info: "Показывает уведомления о новых сообщениях, пока приложение свёрнуто. Если закрыть приложение или iOS выгрузит его из памяти, уведомления перестанут приходить."
            )
            self.ghostMode = GhostModeFeatureStrings(
                title: "Режим призрака",
                on: "Вкл.",
                off: "Выкл.",
                masterInfo: "Читайте сообщения и истории незаметно: собеседники не увидят прочтений, статуса «В сети» и набора текста. Секретные чаты работают как обычно.",
                suppressMessageReadReceipts: "Не отмечать сообщения прочитанными",
                suppressMessageReadReceiptsInfo: "Для собеседника сообщения остаются непрочитанными, пока вы не отметите их прочитанными или не ответите.",
                suppressStoryReadReceipts: "Не отмечать истории просмотренными",
                suppressStoryReadReceiptsInfo: "Автор не узнает, что вы посмотрели историю. Ответ или реакция выдадут просмотр.",
                suppressOnlineStatus: "Не показывать «В сети»",
                suppressOnlineStatusInfo: "Скрывает обычный статус «В сети». Отправка и некоторые действия могут временно раскрыть его.",
                suppressTypingStatus: "Не показывать набор текста",
                suppressTypingStatusInfo: "Скрывает набор текста, запись голоса и загрузку медиа в облачных чатах.",
                revealOnInteractions: "Раскрываться при действиях",
                revealOnInteractionsInfo: "Реакции, голосования и кнопки ботов подтверждают прочтение и временно показывают вас в сети.",
                goOfflineAutomatically: "Автоматически уходить офлайн",
                goOfflineAutomaticallyInfo: "Возвращает статус офлайн через 2 секунды после действия, которое показало вас в сети.",
                markViewedMessagesAsRead: "Отметить просмотренные сообщения прочитанными",
                readReceiptFailed: "Не удалось отправить отметку о прочтении.",
                keepViewOnceMedia: "Не сжигать одноразовые медиа",
                keepViewOnceMediaInfo: "Одноразовые фото, видео, голосовые и кружки можно пересматривать сколько угодно раз, включая секретные чаты. Отправитель видит их непросмотренными, пока вы не нажмёте «Сжечь». Работает и с выключенным призраком.",
                burnViewOnceMedia: "Сжечь",
                activeIndicator: "Режим призрака включён",
                readAllLocally: "Прочитать только у себя",
                readAllOnServer: "Прочитать для всех",
                readAllChats: "Прочитать чаты (без архива)",
                readAllArchive: "Прочитать архив",
                readAllEverything: "Прочитать всё",
                hideSection: "ЧТО СКРЫВАТЬ",
                behaviorSection: "ПОВЕДЕНИЕ"
            )
            self.localMessageArchive = LocalMessageArchiveFeatureStrings(
                title: "Удалённые и изменённые",
                archiveDeletedMessages: "Сохранять удалённые сообщения",
                archiveDeletedMessagesInfo: "Сохраняет удалённые облачные сообщения, включая исчезающие и одноразовые медиа. Секретные чаты не сохраняются.",
                archiveEditedMessages: "Сохранять версии изменений",
                archiveEditedMessagesInfo: "Сохраняет предыдущие версии отредактированных сообщений. Если сохранение удалённых выключено, версии удаляются вместе с исходным сообщением.",
                archiveChats: "Сохранять из архивных чатов",
                archiveChatsInfo: "Если выключить, новые удаления и версии изменений будут сохраняться только для чатов вне системного архива.",
                deletedMessageMarker: "Метка удалённого сообщения",
                deletedMessageMarkerInfo: "Текст или эмодзи рядом со временем удалённого сообщения. Пустое значение отображается как 🧹.",
                keepBetweenLaunches: "Сохранять между запусками",
                keepBetweenLaunchesInfo: "Сохраняет архив после полного закрытия приложения; иначе он очищается при следующем холодном запуске.",
                mediaLimit: "Лимит медиа",
                mediaLimitInfo: "Ограничивает сохранённые файлы. При переполнении первыми удаляются самые крупные медиа, а текст и версии остаются.",
                archiveUsage: "Размер архива",
                clearMedia: "Очистить медиа",
                clearArchive: "Очистить архив",
                clearActionsInfo: "«Очистить медиа» удаляет только сохранённые файлы. «Очистить архив» навсегда удаляет сохранённые сообщения, их прошлые версии и медиа.",
                history: "История",
                deleted: "Удалено",
                deleteForMe: "Удалить у себя",
                deletedMessageSavedLocally: "Удалённое сообщение сохранено только на этом iPhone.",
                richMessage: "(форматированное сообщение)",
                emptyMessage: "(пустое сообщение)",
                mediaMessageTapToOpen: "(медиа — нажмите, чтобы открыть)",
                gigabytesSuffix: "ГБ",
                historyTitle: "История изменений",
                disappearingMediaLimit: "Лимит для исчезающих",
                disappearingMediaLimitInfo: "Отдельный потолок для медиа из исчезающих и одноразовых сообщений. Они не смогут занять больше этого объёма, даже если общий лимит выше. При переполнении первыми удаляются самые крупные файлы.",
                saveSection: "ЧТО СОХРАНЯТЬ",
                storageSection: "ХРАНЕНИЕ",
                usage: { messageCount, versionCount, size in
                    return "Сообщений: \(messageCount) · версий: \(versionCount) · размер: \(size)"
                },
                versionCount: { count in
                    let remainder100 = count % 100
                    let remainder10 = count % 10
                    if remainder100 >= 11 && remainder100 <= 14 {
                        return "\(count) версий"
                    } else if remainder10 == 1 {
                        return "\(count) версия"
                    } else if remainder10 >= 2 && remainder10 <= 4 {
                        return "\(count) версии"
                    } else {
                        return "\(count) версий"
                    }
                }
            )
            self.interfaceTuning = InterfaceTuningFeatureStrings(
                title: "Вкладки, профили и истории",
                tabsSection: "НИЖНЯЯ ПАНЕЛЬ",
                profilesSection: "ПРОФИЛИ",
                storiesSection: "ИСТОРИИ",
                chatsSection: "ЧАТЫ",
                cameraSection: "КАМЕРА",
                concealBottomBar: "Скрывать нижнюю панель",
                concealBottomBarInfo: "Убирает нижнюю панель навигации. Изменение полностью применяется после перезапуска приложения.",
                showContactsShortcut: "Показывать «Контакты»",
                showContactsShortcutInfo: "Добавляет отдельную вкладку контактов на нижнюю панель.",
                showCallsShortcut: "Показывать «Звонки»",
                showCallsShortcutInfo: "Добавляет отдельную вкладку недавних звонков на нижнюю панель.",
                showTabLabels: "Подписи под вкладками",
                showTabLabelsInfo: "Показывает текстовые названия под значками вкладок.",
                showSearchShortcut: "Кнопка поиска",
                showSearchShortcutInfo: "Показывает отдельную кнопку поиска рядом с вкладками.",
                stretchBottomBar: "Растягивать панель",
                stretchBottomBarInfo: "Сохраняет полную ширину панели, даже если часть вкладок скрыта.",
                showProfileIdentifiers: "Показывать ID профиля",
                showProfileIdentifiersInfo: "Показывает технический идентификатор пользователя, группы или канала в профиле.",
                showDataCenter: "Показывать дата-центр",
                showDataCenterInfo: "Показывает номер дата-центра, определённый по фотографии профиля. Если фотографии нет, значение может быть недоступно.",
                showRegistrationDate: "Дата регистрации",
                showRegistrationDateInfo: "Показывает официальную дату Telegram, а если она недоступна — приблизительную оценку через сервис AyuGram.",
                showChatCreationDate: "Дата создания чата",
                showChatCreationDateInfo: "Показывает дату первого доступного сообщения или дату создания группы. Для некоторых чатов значение неизвестно.",
                profileIdentifierLabel: "User ID",
                mutualContact: "взаимный контакт",
                dataCenterLabel: "DC",
                registrationDateLabel: "Дата регистрации",
                chatCreationDateLabel: "Дата создания чата",
                showCallbackData: "Показывать callback data",
                showCallbackDataInfo: "Долгое нажатие на inline-кнопку показывает передаваемые боту данные и позволяет их скопировать. Обычное нажатие продолжает выполнять кнопку.",
                callbackDataTitle: "Callback data",
                hideStoryStrip: "Скрывать ленту историй",
                hideStoryStripInfo: "Убирает ленту историй сверху списка чатов. Сами истории никуда не пропадают.",
                showAppBadge: "Плашка mad в статус-баре",
                showAppBadgeInfo: "Показывает капсулу MADGRAM у выреза экрана. Выключите, чтобы её скрыть.",
                disableStoryCameraSwipe: "Отключить свайп к камере",
                disableStoryCameraSwipeInfo: "Не открывает камеру историй свайпом от списка чатов.",
                confirmStoryOpen: "Спрашивать перед просмотром",
                confirmStoryOpenInfo: "Показывает подтверждение перед началом просмотра истории.",
                allowStoryRepost: "Предлагать репост в историю",
                allowStoryRepostInfo: "Показывает действие репоста в историю в системном экране пересылки.",
                startRoundVideoWithRearCamera: "Начинать кружки с задней камеры",
                startRoundVideoWithRearCameraInfo: "Открывает запись круглого видео сразу на задней камере.",
                hideGalleryCamera: "Скрывать камеру в галерее",
                hideGalleryCameraInfo: "Убирает плитку камеры из галереи при выборе фотографий и видео. Обычная отправка файлов из медиатеки продолжает работать.",
                hidePhoneInSettings: "Скрывать номер в настройках",
                hidePhoneInSettingsInfo: "Скрывает ваш номер только на экране настроек этого приложения. Настройки видимости номера для других людей не меняются.",
                hideBusinessBotPanel: "Скрывать панель бизнес-бота",
                hideBusinessBotPanelInfo: "Скрывает верхнюю панель управления бизнес-ботом в личных чатах. Карточка внутри истории остаётся видимой.",
                businessBotPanelExceptions: "Исключения",
                businessBotPanelExceptionsInfo: "Для выбранных чатов можно задать поведение, отличающееся от глобальной настройки.",
                businessBotPanelAddException: "Добавить чат",
                businessBotPanelNotManaged: "Этот чат не управляется бизнес-ботом.",
                businessBotPanelShow: "Показывать панель",
                businessBotPanelHideInChat: "Скрыть в этом чате",
                restartNotice: "Некоторые параметры нижней панели применяются после перезапуска приложения.",
                storyConfirmationTitle: "Открыть историю?",
                storyConfirmationText: "Автор может увидеть ваш просмотр.",
                storyConfirmationAction: "Просмотреть"
            )
            self.madgram = MadgramFeatureStrings(
                title: "mad",
                privacySection: "ПРИВАТНОСТЬ",
                privacyInfo: "Скрытие номера применяется после перезапуска приложения.",
                messagesSection: "СООБЩЕНИЯ",
                messagesInfo: "Архив удалённых сообщений и фильтры хранятся только на этом устройстве.",
                interfaceSection: "ИНТЕРФЕЙС",
                classicDesign: "Классический дизайн",
                classicDesignInfo: "Возвращает оформление Telegram до Liquid Glass. Применяется после перезапуска приложения.",
                otherSection: "ПРОЧЕЕ",
                forwardWithoutAuthor: "Переслать без автора",
                powerSaving: "Щадящий режим",
                powerSavingInfo: "Постоянно, а не только при низком заряде: без автовоспроизведения видео и GIF, без зацикленных стикеров и эмодзи, без размытия, без фоновой загрузки и фоновых задач, с упрощёнными анимациями интерфейса. Все функции остаются доступны — видео и стикеры запускаются по нажатию."
            )
            self.localPremium = LocalPremiumFeatureStrings(
                title: "Локальный премиум",
                info: "Аккаунт выглядит как Premium: звезда, эмодзи-статус, премиум-иконки, больше папок и закрепов, без рекламы Premium. Это видите только вы, поэтому премиум-реакции, большие файлы, расшифровка голосовых и папки сверх обычного лимита не заработают."
            )
            self.messageFilter = MessageFilterFeatureStrings(
                title: "Фильтры сообщений",
                hideBlockedUsers: "Скрывать сообщения из чёрного списка",
                hideBlockedUsersInfo: "Не показывает сообщения людей, которых вы заблокировали. Они не удаляются, их просто не видно.",
                hiddenPeersSection: "СКРЫТЫЕ ОТПРАВИТЕЛИ",
                hiddenPeersInfo: "Теневой бан: человек не знает, что скрыт, и не попадает в чёрный список — вы просто не видите его сообщений.",
                hiddenPeersEmpty: "Пока никто не скрыт. Скрыть отправителя можно через контекстное меню его сообщения.",
                hideMessages: "Скрыть сообщения",
                showMessages: "Показывать сообщения",
                hiddenMessagePlaceholder: "Сообщение скрыто",
                messagesHidden: "Сообщения этого отправителя скрыты.",
                messagesShown: "Сообщения этого отправителя снова видны.",
                show: "Показывать",
                shareLinkWarningTitle: "Ссылка для отправки сообщения",
                shareLinkWarningText: "Эта ссылка предлагает разослать в чаты сообщение ниже. Такими ссылками распространяют спам: если его отправить, Telegram может ограничить или заблокировать ваш аккаунт.",
                shareLinkWarningOpen: "Всё равно открыть"
            )
            self.messageShot = MessageShotFeatureStrings(
                title: "Скриншот",
                action: "Скриншот",
                contentSection: "СОДЕРЖИМОЕ",
                showWallpaper: "Обои",
                darkTheme: "Тёмная тема",
                showAvatar: "Аватар и имя",
                showTime: "Время",
                showReactions: "Реакции",
                revealSpoilers: "Раскрывать спойлеры",
                share: "Поделиться",
                saveToPhotos: "Сохранить в «Фото»",
                copy: "Копировать",
                savedToPhotos: "Сохранено в «Фото».",
                copied: "Изображение скопировано.",
                saveFailed: "Не удалось сохранить изображение.",
                selectionLimit: { count in
                    return "На скриншот попадут первые \(count) сообщений."
                }
            )
            self.deleteOwnMessages = DeleteOwnMessagesFeatureStrings(
                menuItem: "Удалить все мои сообщения",
                confirmTitle: "Удалить все мои сообщения?",
                confirmText: "Все ваши сообщения в этом чате будут удалены у всех участников. Это действие необратимо.",
                confirmAction: "Удалить",
                preparing: "Удаление сообщений…",
                progress: { deleted, total in
                    return "Удаление сообщений: \(deleted) из \(total)…"
                },
                completed: { count in
                    return "Удалено сообщений: \(count)."
                },
                empty: "В этом чате нет ваших сообщений."
            )
        case "uk":
            self.localNotifications = LocalNotificationFeatureStrings(
                title: "Локальні сповіщення",
                info: "Показує сповіщення про нові повідомлення, поки застосунок згорнуто. Якщо закрити застосунок або iOS вивантажить його з пам'яті, сповіщення перестануть надходити."
            )
            self.ghostMode = GhostModeFeatureStrings(
                title: "Режим привида",
                on: "Увімк.",
                off: "Вимк.",
                masterInfo: "Читайте повідомлення та історії непомітно: співрозмовники не побачать прочитання, статусу «У мережі» і набору тексту. Секретні чати працюють як зазвичай.",
                suppressMessageReadReceipts: "Не позначати повідомлення прочитаними",
                suppressMessageReadReceiptsInfo: "Для співрозмовника повідомлення лишаються непрочитаними, доки ви не позначите їх прочитаними або не відповісте.",
                suppressStoryReadReceipts: "Не позначати історії переглянутими",
                suppressStoryReadReceiptsInfo: "Автор не дізнається, що ви переглянули історію. Відповідь або реакція видадуть перегляд.",
                suppressOnlineStatus: "Не показувати «У мережі»",
                suppressOnlineStatusInfo: "Приховує звичайний статус «У мережі». Надсилання та деякі дії можуть тимчасово розкрити його.",
                suppressTypingStatus: "Не показувати набір тексту",
                suppressTypingStatusInfo: "Приховує набір тексту, запис голосу та завантаження медіа у хмарних чатах.",
                revealOnInteractions: "Розкриватися під час дій",
                revealOnInteractionsInfo: "Реакції, голосування та кнопки ботів підтверджують прочитання й тимчасово показують вас у мережі.",
                goOfflineAutomatically: "Автоматично переходити офлайн",
                goOfflineAutomaticallyInfo: "Повертає статус офлайн через 2 секунди після дії, яка показала вас у мережі.",
                markViewedMessagesAsRead: "Позначити переглянуті повідомлення прочитаними",
                readReceiptFailed: "Не вдалося надіслати позначку про прочитання.",
                keepViewOnceMedia: "Не спалювати одноразові медіа",
                keepViewOnceMediaInfo: "Одноразові фото, відео, голосові та кружечки можна переглядати скільки завгодно разів, зокрема в секретних чатах. Відправник бачить їх непереглянутими, доки ви не натиснете «Спалити». Працює й з вимкненим привидом.",
                burnViewOnceMedia: "Спалити",
                activeIndicator: "Режим привида увімкнено",
                readAllLocally: "Прочитати лише у себе",
                readAllOnServer: "Прочитати для всіх",
                readAllChats: "Прочитати чати (без архіву)",
                readAllArchive: "Прочитати архів",
                readAllEverything: "Прочитати все",
                hideSection: "ЩО ПРИХОВУВАТИ",
                behaviorSection: "ПОВЕДІНКА"
            )
            self.localMessageArchive = LocalMessageArchiveFeatureStrings(
                title: "Видалені та змінені",
                archiveDeletedMessages: "Зберігати видалені повідомлення",
                archiveDeletedMessagesInfo: "Зберігає видалені хмарні повідомлення, зокрема зникаючі та одноразові медіа. Секретні чати не зберігаються.",
                archiveEditedMessages: "Зберігати версії змін",
                archiveEditedMessagesInfo: "Зберігає попередні версії відредагованих повідомлень. Якщо збереження видалених вимкнено, версії видаляються разом із повідомленням.",
                archiveChats: "Зберігати з архівних чатів",
                archiveChatsInfo: "Якщо вимкнути, нові видалення та версії змін зберігатимуться лише для чатів поза системним архівом.",
                deletedMessageMarker: "Позначка видаленого повідомлення",
                deletedMessageMarkerInfo: "Текст або емодзі біля часу видаленого повідомлення. Порожнє значення відображається як 🧹.",
                keepBetweenLaunches: "Зберігати між запусками",
                keepBetweenLaunchesInfo: "Зберігає архів після повного закриття застосунку; інакше він очищається під час наступного холодного запуску.",
                mediaLimit: "Ліміт медіа",
                mediaLimitInfo: "Обмежує збережені файли. За переповнення першими видаляються найбільші медіа, а текст і версії залишаються.",
                archiveUsage: "Розмір архіву",
                clearMedia: "Очистити медіа",
                clearArchive: "Очистити архів",
                clearActionsInfo: "«Очистити медіа» видаляє лише збережені файли. «Очистити архів» назавжди видаляє збережені повідомлення, їхні попередні версії та медіа.",
                history: "Історія",
                deleted: "Видалено",
                deleteForMe: "Видалити в себе",
                deletedMessageSavedLocally: "Видалене повідомлення збережено лише на цьому iPhone.",
                richMessage: "(форматоване повідомлення)",
                emptyMessage: "(порожнє повідомлення)",
                mediaMessageTapToOpen: "(медіа — натисніть, щоб відкрити)",
                gigabytesSuffix: "ГБ",
                historyTitle: "Історія змін",
                disappearingMediaLimit: "Ліміт для зникаючих",
                disappearingMediaLimitInfo: "Окремий поріг для медіа зі зникаючих та одноразових повідомлень. Вони не займуть більше за цей обсяг, навіть якщо загальний ліміт вищий. За переповнення першими видаляються найбільші файли.",
                saveSection: "ЩО ЗБЕРІГАТИ",
                storageSection: "ЗБЕРІГАННЯ",
                usage: { messageCount, versionCount, size in
                    return "Повідомлень: \(messageCount) · версій: \(versionCount) · розмір: \(size)"
                },
                versionCount: { count in
                    let remainder100 = count % 100
                    let remainder10 = count % 10
                    if remainder100 >= 11 && remainder100 <= 14 {
                        return "\(count) версій"
                    } else if remainder10 == 1 {
                        return "\(count) версія"
                    } else if remainder10 >= 2 && remainder10 <= 4 {
                        return "\(count) версії"
                    } else {
                        return "\(count) версій"
                    }
                }
            )
            self.interfaceTuning = InterfaceTuningFeatureStrings(
                title: "Вкладки, профілі та історії",
                tabsSection: "НИЖНЯ ПАНЕЛЬ",
                profilesSection: "ПРОФІЛІ",
                storiesSection: "ІСТОРІЇ",
                chatsSection: "ЧАТИ",
                cameraSection: "КАМЕРА",
                concealBottomBar: "Приховувати нижню панель",
                concealBottomBarInfo: "Прибирає нижню панель навігації. Зміна повністю застосовується після перезапуску застосунку.",
                showContactsShortcut: "Показувати «Контакти»",
                showContactsShortcutInfo: "Додає окрему вкладку контактів на нижню панель.",
                showCallsShortcut: "Показувати «Дзвінки»",
                showCallsShortcutInfo: "Додає окрему вкладку нещодавніх дзвінків на нижню панель.",
                showTabLabels: "Підписи під вкладками",
                showTabLabelsInfo: "Показує текстові назви під значками вкладок.",
                showSearchShortcut: "Кнопка пошуку",
                showSearchShortcutInfo: "Показує окрему кнопку пошуку поруч із вкладками.",
                stretchBottomBar: "Розтягувати панель",
                stretchBottomBarInfo: "Зберігає повну ширину панелі, навіть якщо частину вкладок приховано.",
                showProfileIdentifiers: "Показувати ID профілю",
                showProfileIdentifiersInfo: "Показує технічний ідентифікатор користувача, групи або каналу в профілі.",
                showDataCenter: "Показувати дата-центр",
                showDataCenterInfo: "Показує номер дата-центру, визначений за фотографією профілю. Без фотографії значення може бути недоступним.",
                showRegistrationDate: "Дата реєстрації",
                showRegistrationDateInfo: "Показує офіційну дату Telegram, а якщо вона недоступна — приблизну оцінку через сервіс AyuGram.",
                showChatCreationDate: "Дата створення чату",
                showChatCreationDateInfo: "Показує дату першого доступного повідомлення або створення групи. Для деяких чатів значення невідоме.",
                profileIdentifierLabel: "User ID",
                mutualContact: "взаємний контакт",
                dataCenterLabel: "DC",
                registrationDateLabel: "Дата реєстрації",
                chatCreationDateLabel: "Дата створення чату",
                showCallbackData: "Показувати callback data",
                showCallbackDataInfo: "Довге натискання inline-кнопки показує дані, що передаються боту, і дозволяє їх скопіювати. Звичайне натискання й надалі виконує кнопку.",
                callbackDataTitle: "Callback data",
                hideStoryStrip: "Приховувати стрічку історій",
                hideStoryStripInfo: "Прибирає стрічку історій угорі списку чатів. Самі історії нікуди не зникають.",
                showAppBadge: "Плашка mad у статус-барі",
                showAppBadgeInfo: "Показує капсулу MADGRAM біля вирізу екрана. Вимкніть, щоб її приховати.",
                disableStoryCameraSwipe: "Вимкнути свайп до камери",
                disableStoryCameraSwipeInfo: "Не відкриває камеру історій свайпом зі списку чатів.",
                confirmStoryOpen: "Запитувати перед переглядом",
                confirmStoryOpenInfo: "Показує підтвердження перед початком перегляду історії.",
                allowStoryRepost: "Пропонувати репост в історію",
                allowStoryRepostInfo: "Показує дію репосту в історію на екрані пересилання.",
                startRoundVideoWithRearCamera: "Починати кружечки із задньої камери",
                startRoundVideoWithRearCameraInfo: "Відкриває запис круглого відео одразу на задній камері.",
                hideGalleryCamera: "Приховувати камеру в галереї",
                hideGalleryCameraInfo: "Прибирає плитку камери з галереї під час вибору фотографій і відео. Звичайне надсилання файлів із медіатеки працює без змін.",
                hidePhoneInSettings: "Приховувати номер у налаштуваннях",
                hidePhoneInSettingsInfo: "Приховує ваш номер лише на екрані налаштувань цього застосунку. Видимість номера для інших людей не змінюється.",
                hideBusinessBotPanel: "Приховувати панель бізнес-бота",
                hideBusinessBotPanelInfo: "Приховує верхню панель керування бізнес-ботом в особистих чатах. Картка в історії залишається видимою.",
                businessBotPanelExceptions: "Винятки",
                businessBotPanelExceptionsInfo: "Для вибраних чатів можна встановити поведінку, відмінну від глобального налаштування.",
                businessBotPanelAddException: "Додати чат",
                businessBotPanelNotManaged: "Цей чат не керується бізнес-ботом.",
                businessBotPanelShow: "Показувати панель",
                businessBotPanelHideInChat: "Приховати в цьому чаті",
                restartNotice: "Деякі параметри нижньої панелі застосовуються після перезапуску застосунку.",
                storyConfirmationTitle: "Відкрити історію?",
                storyConfirmationText: "Автор може побачити ваш перегляд.",
                storyConfirmationAction: "Переглянути"
            )
            self.madgram = MadgramFeatureStrings(
                title: "mad",
                privacySection: "ПРИВАТНІСТЬ",
                privacyInfo: "Приховування номера застосовується після перезапуску застосунку.",
                messagesSection: "ПОВІДОМЛЕННЯ",
                messagesInfo: "Архів видалених повідомлень і фільтри зберігаються лише на цьому пристрої.",
                interfaceSection: "ІНТЕРФЕЙС",
                classicDesign: "Класичний дизайн",
                classicDesignInfo: "Повертає оформлення Telegram до Liquid Glass. Застосовується після перезапуску застосунку.",
                otherSection: "ІНШЕ",
                forwardWithoutAuthor: "Переслати без автора",
                powerSaving: "Ощадливий режим",
                powerSavingInfo: "Постійно, а не лише за низького заряду: без автовідтворення відео та GIF, без зациклених стикерів і емодзі, без розмиття, без фонового завантаження й фонових задач, зі спрощеними анімаціями інтерфейсу. Усі функції лишаються доступними — відео та стикери запускаються дотиком."
            )
            self.localPremium = LocalPremiumFeatureStrings(
                title: "Локальний преміум",
                info: "Акаунт виглядає як Premium: зірка, емодзі-статус, преміум-іконки, більше папок і закріплень, без реклами Premium. Це бачите лише ви, тому преміум-реакції, великі файли, розшифрування голосових і папки понад звичайний ліміт не запрацюють."
            )
            self.messageFilter = MessageFilterFeatureStrings(
                title: "Фільтри повідомлень",
                hideBlockedUsers: "Приховувати повідомлення з чорного списку",
                hideBlockedUsersInfo: "Не показує повідомлення людей, яких ви заблокували. Вони не видаляються, їх просто не видно.",
                hiddenPeersSection: "ПРИХОВАНІ ВІДПРАВНИКИ",
                hiddenPeersInfo: "Тіньовий бан: людина не знає, що прихована, і не потрапляє до чорного списку — ви просто не бачите її повідомлень.",
                hiddenPeersEmpty: "Поки нікого не приховано. Приховати відправника можна через контекстне меню його повідомлення.",
                hideMessages: "Приховати повідомлення",
                showMessages: "Показувати повідомлення",
                hiddenMessagePlaceholder: "Повідомлення приховано",
                messagesHidden: "Повідомлення цього відправника приховано.",
                messagesShown: "Повідомлення цього відправника знову видно.",
                show: "Показувати",
                shareLinkWarningTitle: "Посилання для надсилання повідомлення",
                shareLinkWarningText: "Це посилання пропонує розіслати в чати повідомлення нижче. Такими посиланнями поширюють спам: якщо його надіслати, Telegram може обмежити або заблокувати ваш акаунт.",
                shareLinkWarningOpen: "Все одно відкрити"
            )
            self.messageShot = MessageShotFeatureStrings(
                title: "Скриншот",
                action: "Скриншот",
                contentSection: "ВМІСТ",
                showWallpaper: "Шпалери",
                darkTheme: "Темна тема",
                showAvatar: "Аватар та ім’я",
                showTime: "Час",
                showReactions: "Реакції",
                revealSpoilers: "Розкривати спойлери",
                share: "Поділитися",
                saveToPhotos: "Зберегти у «Фото»",
                copy: "Копіювати",
                savedToPhotos: "Збережено у «Фото».",
                copied: "Зображення скопійовано.",
                saveFailed: "Не вдалося зберегти зображення.",
                selectionLimit: { count in
                    return "На скриншот потраплять перші \(count) повідомлень."
                }
            )
            self.deleteOwnMessages = DeleteOwnMessagesFeatureStrings(
                menuItem: "Видалити всі мої повідомлення",
                confirmTitle: "Видалити всі мої повідомлення?",
                confirmText: "Усі ваші повідомлення в цьому чаті буде видалено в усіх учасників. Цю дію неможливо скасувати.",
                confirmAction: "Видалити",
                preparing: "Видалення повідомлень…",
                progress: { deleted, total in
                    return "Видалення повідомлень: \(deleted) з \(total)…"
                },
                completed: { count in
                    return "Видалено повідомлень: \(count)."
                },
                empty: "У цьому чаті немає ваших повідомлень."
            )
        default:
            self.localNotifications = LocalNotificationFeatureStrings(
                title: "Local Notifications",
                info: "Shows notifications for new messages while the app is in the background. Once you close the app or iOS unloads it, notifications stop."
            )
            self.ghostMode = GhostModeFeatureStrings(
                title: "Ghost Mode",
                on: "On",
                off: "Off",
                masterInfo: "Read messages and stories unnoticed: nobody sees your read receipts, online status or typing. Secret chats work as usual.",
                suppressMessageReadReceipts: "Don't Read Messages",
                suppressMessageReadReceiptsInfo: "Messages stay unread for the sender until you mark them as read or reply.",
                suppressStoryReadReceipts: "Don't Read Stories",
                suppressStoryReadReceiptsInfo: "The author won't know you viewed the story. A reply or reaction reveals the view.",
                suppressOnlineStatus: "Don't Send Online",
                suppressOnlineStatusInfo: "Hides routine online presence. Sending and some interactions can reveal it temporarily.",
                suppressTypingStatus: "Don't Send Typing",
                suppressTypingStatusInfo: "Hides typing, voice recording and media uploads in cloud chats.",
                revealOnInteractions: "Reveal on Interactions",
                revealOnInteractionsInfo: "Reactions, polls and bot buttons confirm the read state and reveal you online temporarily.",
                goOfflineAutomatically: "Go Offline Automatically",
                goOfflineAutomaticallyInfo: "Returns you offline 2 seconds after an action reveals your online status.",
                markViewedMessagesAsRead: "Mark viewed messages as read",
                readReceiptFailed: "Couldn't send read receipt.",
                keepViewOnceMedia: "Don't Burn View-Once Media",
                keepViewOnceMediaInfo: "View-once photos, videos, voice and video messages can be replayed any number of times, including in secret chats. The sender sees them as unopened until you tap Burn. Works even with Ghost Mode off.",
                burnViewOnceMedia: "Burn",
                activeIndicator: "Ghost Mode is on",
                readAllLocally: "Read Only for Me",
                readAllOnServer: "Read for Everyone",
                readAllChats: "Read Chats (Not Archived)",
                readAllArchive: "Read Archive",
                readAllEverything: "Read Everything",
                hideSection: "WHAT TO HIDE",
                behaviorSection: "BEHAVIOR"
            )
            self.localMessageArchive = LocalMessageArchiveFeatureStrings(
                title: "Deleted and Edited",
                archiveDeletedMessages: "Save Deleted Messages",
                archiveDeletedMessagesInfo: "Saves deleted cloud messages, including disappearing and view-once media. Secret chats are never saved.",
                archiveEditedMessages: "Save Edit Versions",
                archiveEditedMessagesInfo: "Saves previous versions of edited messages. When saving deleted messages is off, versions are removed with the original message.",
                archiveChats: "Save from Archived Chats",
                archiveChatsInfo: "When off, new deletions and edit versions are saved only for chats outside the system archive.",
                deletedMessageMarker: "Deleted Message Marker",
                deletedMessageMarkerInfo: "Text or emoji displayed beside a deleted message’s time. An empty value is displayed as 🧹.",
                keepBetweenLaunches: "Keep Between Launches",
                keepBetweenLaunchesInfo: "Keeps the archive after the app fully closes; otherwise it is cleared on the next cold launch.",
                mediaLimit: "Media Limit",
                mediaLimitInfo: "Limits retained files. The largest media is removed first while message text and edit history remain.",
                archiveUsage: "Archive Usage",
                clearMedia: "Clear Media",
                clearArchive: "Clear Archive",
                clearActionsInfo: "“Clear Media” removes only the saved files. “Clear Archive” permanently removes saved messages, their earlier versions and media.",
                history: "History",
                deleted: "Deleted",
                deleteForMe: "Delete for Me",
                deletedMessageSavedLocally: "Deleted message saved only on this iPhone.",
                richMessage: "(rich message)",
                emptyMessage: "(empty message)",
                mediaMessageTapToOpen: "(media message — tap to open)",
                gigabytesSuffix: "GB",
                historyTitle: "Edit History",
                disappearingMediaLimit: "Disappearing Media Limit",
                disappearingMediaLimitInfo: "A separate cap for media from disappearing and view-once messages. They never take more than this, even when the overall limit is higher. Largest files are removed first when the cap is reached.",
                saveSection: "WHAT TO SAVE",
                storageSection: "STORAGE",
                usage: { messageCount, versionCount, size in
                    return "Messages: \(messageCount) · versions: \(versionCount) · size: \(size)"
                },
                versionCount: { count in
                    return count == 1 ? "1 version" : "\(count) versions"
                }
            )
            self.interfaceTuning = InterfaceTuningFeatureStrings(
                title: "Tabs, Profiles and Stories",
                tabsSection: "BOTTOM BAR",
                profilesSection: "PROFILES",
                storiesSection: "STORIES",
                chatsSection: "CHATS",
                cameraSection: "CAMERA",
                concealBottomBar: "Conceal Bottom Bar",
                concealBottomBarInfo: "Removes the bottom navigation bar. Restart the app to apply this change everywhere.",
                showContactsShortcut: "Show Contacts Shortcut",
                showContactsShortcutInfo: "Adds a dedicated Contacts tab to the bottom bar.",
                showCallsShortcut: "Show Calls Shortcut",
                showCallsShortcutInfo: "Adds a dedicated recent calls tab to the bottom bar.",
                showTabLabels: "Tab Labels",
                showTabLabelsInfo: "Shows text labels below tab icons.",
                showSearchShortcut: "Search Shortcut",
                showSearchShortcutInfo: "Shows a separate search button next to the tabs.",
                stretchBottomBar: "Stretch Bottom Bar",
                stretchBottomBarInfo: "Keeps the bar at full width when some tabs are hidden.",
                showProfileIdentifiers: "Show Profile IDs",
                showProfileIdentifiersInfo: "Shows the technical identifier of a user, group or channel on its profile.",
                showDataCenter: "Show Data Center",
                showDataCenterInfo: "Shows the data-center number inferred from the profile photo. It may be unavailable without a photo.",
                showRegistrationDate: "Registration Date",
                showRegistrationDateInfo: "Shows Telegram's official date when available, otherwise an approximate estimate from the AyuGram service.",
                showChatCreationDate: "Chat Creation Date",
                showChatCreationDateInfo: "Shows the first available message date or group creation date. It is unavailable for some chats.",
                profileIdentifierLabel: "User ID",
                mutualContact: "mutual contact",
                dataCenterLabel: "DC",
                registrationDateLabel: "Registration date",
                chatCreationDateLabel: "Chat created",
                showCallbackData: "Show Callback Data",
                showCallbackDataInfo: "Long-pressing an inline button shows the data sent to the bot and lets you copy it. A regular tap still performs the button action.",
                callbackDataTitle: "Callback data",
                hideStoryStrip: "Hide Story Strip",
                hideStoryStripInfo: "Removes the stories row from the top of the chat list. The stories themselves stay.",
                showAppBadge: "mad Badge in Status Bar",
                showAppBadgeInfo: "Shows the MADGRAM capsule next to the screen cutout. Turn off to hide it.",
                disableStoryCameraSwipe: "Disable Camera Swipe",
                disableStoryCameraSwipeInfo: "Prevents opening the story camera by swiping from the chat list.",
                confirmStoryOpen: "Confirm Before Viewing",
                confirmStoryOpenInfo: "Asks for confirmation before story playback begins.",
                allowStoryRepost: "Offer Story Repost",
                allowStoryRepostInfo: "Shows the repost-to-story action on the forwarding screen.",
                startRoundVideoWithRearCamera: "Start Video Messages With Rear Camera",
                startRoundVideoWithRearCameraInfo: "Starts round-video recording with the rear camera.",
                hideGalleryCamera: "Hide Camera in Gallery",
                hideGalleryCameraInfo: "Removes the camera tile from the photo and video picker. Sending existing media from the library continues to work normally.",
                hidePhoneInSettings: "Hide Phone in Settings",
                hidePhoneInSettingsInfo: "Hides your number only in this app's settings UI. It does not change who can see it.",
                hideBusinessBotPanel: "Hide Business Bot Panel",
                hideBusinessBotPanelInfo: "Hides the business bot control panel at the top of private chats. The information card in chat history remains visible.",
                businessBotPanelExceptions: "Exceptions",
                businessBotPanelExceptionsInfo: "Selected chats can use behavior different from the global setting.",
                businessBotPanelAddException: "Add Chat",
                businessBotPanelNotManaged: "This chat is not managed by a business bot.",
                businessBotPanelShow: "Show Panel",
                businessBotPanelHideInChat: "Hide in This Chat",
                restartNotice: "Some bottom-bar changes apply after restarting the app.",
                storyConfirmationTitle: "Open this story?",
                storyConfirmationText: "The author may be able to see your view.",
                storyConfirmationAction: "View"
            )
            self.madgram = MadgramFeatureStrings(
                title: "mad",
                privacySection: "PRIVACY",
                privacyInfo: "Hiding the phone number applies after restarting the app.",
                messagesSection: "MESSAGES",
                messagesInfo: "The deleted-message archive and filters are stored only on this device.",
                interfaceSection: "INTERFACE",
                classicDesign: "Classic Design",
                classicDesignInfo: "Brings back Telegram's look from before Liquid Glass. Applies after restarting the app.",
                otherSection: "OTHER",
                forwardWithoutAuthor: "Forward without sender",
                powerSaving: "Low Power Profile",
                powerSavingInfo: "Always on, not just on low battery: no video and GIF autoplay, no looping stickers and emoji, no blur, no background downloads or background work, and simplified interface animations. Nothing is removed — videos and stickers play when you tap them."
            )
            self.localPremium = LocalPremiumFeatureStrings(
                title: "Local Premium",
                info: "Your account looks like Premium: the star, an emoji status, premium icons, more folders and pins, no Premium ads. Only you see it, so premium reactions, large files, voice transcription and folders above the usual limit won't work."
            )
            self.messageFilter = MessageFilterFeatureStrings(
                title: "Message Filters",
                hideBlockedUsers: "Hide Messages from Blocked Users",
                hideBlockedUsersInfo: "Hides messages from people you blocked. They aren't deleted, just not shown.",
                hiddenPeersSection: "HIDDEN SENDERS",
                hiddenPeersInfo: "Shadow ban: the person is not blocked and never learns they are hidden — you just don't see their messages.",
                hiddenPeersEmpty: "Nobody is hidden yet. Hide a sender from the context menu of their message.",
                hideMessages: "Hide Messages",
                showMessages: "Show Messages",
                hiddenMessagePlaceholder: "Message hidden",
                messagesHidden: "Messages from this sender are now hidden.",
                messagesShown: "Messages from this sender are visible again.",
                show: "Show",
                shareLinkWarningTitle: "Message Sharing Link",
                shareLinkWarningText: "This link asks you to send the message below to your chats. Links like this are used to spread spam: sending it can get your account limited or banned by Telegram.",
                shareLinkWarningOpen: "Open Anyway"
            )
            self.messageShot = MessageShotFeatureStrings(
                title: "Screenshot",
                action: "Screenshot",
                contentSection: "CONTENT",
                showWallpaper: "Wallpaper",
                darkTheme: "Dark Theme",
                showAvatar: "Avatar and Name",
                showTime: "Time",
                showReactions: "Reactions",
                revealSpoilers: "Reveal Spoilers",
                share: "Share",
                saveToPhotos: "Save to Photos",
                copy: "Copy",
                savedToPhotos: "Saved to Photos.",
                copied: "Image copied.",
                saveFailed: "Couldn't save the image.",
                selectionLimit: { count in
                    return "Only the first \(count) messages will be included."
                }
            )
            self.deleteOwnMessages = DeleteOwnMessagesFeatureStrings(
                menuItem: "Delete All My Messages",
                confirmTitle: "Delete all my messages?",
                confirmText: "All of your messages in this chat will be deleted for all participants. This action cannot be undone.",
                confirmAction: "Delete",
                preparing: "Deleting messages…",
                progress: { deleted, total in
                    return "Deleting messages: \(deleted) of \(total)…"
                },
                completed: { count in
                    return "Deleted \(count) messages."
                },
                empty: "You have no messages in this chat."
            )
        }
    }
}

public extension PresentationStrings {
    var localFeatures: LocalFeatureStrings {
        return LocalFeatureStrings(strings: self)
    }
}
