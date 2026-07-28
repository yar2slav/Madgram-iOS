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
}

public struct LocalMessageArchiveFeatureStrings {
    public let title: String
    public let archiveDeletedMessages: String
    public let archiveDeletedMessagesInfo: String
    public let archiveEditedMessages: String
    public let archiveEditedMessagesInfo: String
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

    public let usage: (Int, Int, String) -> String
    public let versionCount: (Int) -> String
}

public struct MadgramFeatureStrings {
    public let title: String
    public let featuresSection: String
    public let info: String
    public let forwardWithoutAuthor: String
    public let powerSection: String
    public let powerSaving: String
    public let powerSavingInfo: String
}

public struct LocalPremiumFeatureStrings {
    public let section: String
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

public struct InterfaceTuningFeatureStrings {
    public let title: String
    public let tabsSection: String
    public let profilesSection: String
    public let storiesSection: String
    public let mediaSection: String
    public let privacySection: String

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
    public let dataCenterLabel: String
    public let registrationDateLabel: String
    public let chatCreationDateLabel: String

    public let hideStoryStrip: String
    public let hideStoryStripInfo: String
    public let disableStoryCameraSwipe: String
    public let disableStoryCameraSwipeInfo: String
    public let confirmStoryOpen: String
    public let confirmStoryOpenInfo: String
    public let allowStoryRepost: String
    public let allowStoryRepostInfo: String

    public let startRoundVideoWithRearCamera: String
    public let startRoundVideoWithRearCameraInfo: String
    public let hidePhoneInSettings: String
    public let hidePhoneInSettingsInfo: String

    public let restartNotice: String
    public let storyConfirmationTitle: String
    public let storyConfirmationText: String
    public let storyConfirmationAction: String
}

public struct LocalFeatureStrings {
    public let ghostMode: GhostModeFeatureStrings
    public let localMessageArchive: LocalMessageArchiveFeatureStrings
    public let interfaceTuning: InterfaceTuningFeatureStrings
    public let madgram: MadgramFeatureStrings
    public let localPremium: LocalPremiumFeatureStrings
    public let messageFilter: MessageFilterFeatureStrings
    public let messageShot: MessageShotFeatureStrings

    public init(strings: PresentationStrings) {
        let languageCode = strings.baseLanguageCode
            .lowercased()
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map(String.init) ?? "en"

        switch languageCode {
        case "ru":
            self.ghostMode = GhostModeFeatureStrings(
                title: "Режим призрака",
                on: "Вкл.",
                off: "Выкл.",
                masterInfo: "Читает облачные сообщения и истории локально, скрывая прочтение, статус «В сети» и набор текста. Секретные чаты не изменяются.",
                suppressMessageReadReceipts: "Не отмечать сообщения прочитанными",
                suppressMessageReadReceiptsInfo: "Сообщения читаются только на этом iPhone и остаются непрочитанными на сервере до ручного подтверждения или отправки.",
                suppressStoryReadReceipts: "Не отмечать истории просмотренными",
                suppressStoryReadReceiptsInfo: "Просмотр истории остаётся локальным. Ответ или реакция подтверждает просмотр этой истории.",
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
                keepViewOnceMediaInfo: "Одноразовые фото, видео, голосовые и кружки можно пересматривать сколько угодно раз, включая секретные чаты. Отправитель видит их непросмотренными, пока вы не нажмёте «Сжечь».",
                burnViewOnceMedia: "Сжечь"
            )
            self.localMessageArchive = LocalMessageArchiveFeatureStrings(
                title: "Удалённые и изменённые",
                archiveDeletedMessages: "Сохранять удалённые сообщения",
                archiveDeletedMessagesInfo: "Сохраняет удалённые облачные сообщения, включая исчезающие и одноразовые медиа. Секретные чаты не сохраняются.",
                archiveEditedMessages: "Сохранять версии изменений",
                archiveEditedMessagesInfo: "Сохраняет предыдущие версии отредактированных сообщений. Если сохранение удалённых выключено, версии удаляются вместе с исходным сообщением.",
                deletedMessageMarker: "Метка удалённого сообщения",
                deletedMessageMarkerInfo: "Текст или эмодзи рядом со временем удалённого сообщения. Пустое значение отображается как 🧹.",
                keepBetweenLaunches: "Сохранять между запусками",
                keepBetweenLaunchesInfo: "Сохраняет архив после полного закрытия приложения; иначе он очищается при следующем холодном запуске.",
                mediaLimit: "Лимит медиа",
                mediaLimitInfo: "Ограничивает сохранённые файлы. При переполнении первыми удаляются самые крупные медиа, а текст и версии остаются.",
                archiveUsage: "Размер архива",
                clearMedia: "Очистить медиа",
                clearArchive: "Очистить архив",
                clearActionsInfo: "«Очистить медиа» удаляет только сохранённые файлы. «Очистить архив» окончательно удаляет локальные сообщения, версии и связанные медиа с этого iPhone.",
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
                title: "Настройка интерфейса",
                tabsSection: "НИЖНЯЯ ПАНЕЛЬ",
                profilesSection: "ПРОФИЛИ",
                storiesSection: "ИСТОРИИ",
                mediaSection: "КРУГЛЫЕ ВИДЕО",
                privacySection: "ЛОКАЛЬНАЯ ПРИВАТНОСТЬ",
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
                showRegistrationDateInfo: "Показывает приблизительную дату регистрации, только если Telegram уже передал её клиенту.",
                showChatCreationDate: "Дата создания чата",
                showChatCreationDateInfo: "Показывает дату первого доступного сообщения или дату создания группы. Для некоторых чатов значение неизвестно.",
                profileIdentifierLabel: "User ID",
                dataCenterLabel: "DC",
                registrationDateLabel: "Дата регистрации",
                chatCreationDateLabel: "Дата создания чата",
                hideStoryStrip: "Скрывать ленту историй",
                hideStoryStripInfo: "Убирает истории с верхней части списка чатов, не удаляя их и не меняя состояние на сервере.",
                disableStoryCameraSwipe: "Отключить свайп к камере",
                disableStoryCameraSwipeInfo: "Не открывает камеру историй свайпом от списка чатов.",
                confirmStoryOpen: "Спрашивать перед просмотром",
                confirmStoryOpenInfo: "Показывает подтверждение перед началом просмотра истории.",
                allowStoryRepost: "Предлагать репост в историю",
                allowStoryRepostInfo: "Показывает действие репоста в историю в системном экране пересылки.",
                startRoundVideoWithRearCamera: "Начинать с задней камеры",
                startRoundVideoWithRearCameraInfo: "Открывает запись круглого видео сразу на задней камере.",
                hidePhoneInSettings: "Скрывать номер в настройках",
                hidePhoneInSettingsInfo: "Скрывает ваш номер только на экране настроек этого приложения. Настройки видимости номера для других людей не меняются.",
                restartNotice: "Некоторые параметры нижней панели и номера применяются после перезапуска приложения.",
                storyConfirmationTitle: "Открыть историю?",
                storyConfirmationText: "Автор может увидеть ваш просмотр.",
                storyConfirmationAction: "Просмотреть"
            )
            self.madgram = MadgramFeatureStrings(
                title: "Madgram",
                featuresSection: "ФУНКЦИИ MADGRAM",
                info: "Функции, которых нет в обычном Telegram. Все данные этих функций хранятся только на этом устройстве.",
                forwardWithoutAuthor: "Переслать без автора",
                powerSection: "ЭНЕРГОПОТРЕБЛЕНИЕ",
                powerSaving: "Щадящий режим",
                powerSavingInfo: "Постоянно, а не только при низком заряде: без автовоспроизведения видео и GIF, без зацикленных стикеров и эмодзи, без размытия, без фоновой загрузки и фоновых задач, с упрощёнными анимациями интерфейса. Все функции остаются доступны — видео и стикеры запускаются по нажатию."
            )
            self.localPremium = LocalPremiumFeatureStrings(
                section: "ПРЕМИУМ",
                title: "Локальный премиум",
                info: "Разблокирует интерфейс Telegram Premium только на этом устройстве. Возможности, которые проверяет сервер — большие файлы, премиум-реакции и эмодзи, расшифровка голосовых — продолжат требовать подписку."
            )
            self.messageFilter = MessageFilterFeatureStrings(
                title: "Фильтры сообщений",
                hideBlockedUsers: "Скрывать сообщения из чёрного списка",
                hideBlockedUsersInfo: "Не показывает сообщения людей, которых вы заблокировали. Сообщения остаются на сервере и в локальной базе, их просто не видно.",
                hiddenPeersSection: "СКРЫТЫЕ ОТПРАВИТЕЛИ",
                hiddenPeersInfo: "Теневой бан: человек не знает, что скрыт, и не попадает в чёрный список — вы просто не видите его сообщений.",
                hiddenPeersEmpty: "Пока никто не скрыт. Скрыть отправителя можно через контекстное меню его сообщения.",
                hideMessages: "Скрыть сообщения",
                showMessages: "Показывать сообщения",
                hiddenMessagePlaceholder: "Сообщение скрыто",
                messagesHidden: "Сообщения этого отправителя скрыты.",
                messagesShown: "Сообщения этого отправителя снова видны.",
                show: "Показывать"
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
        case "uk":
            self.ghostMode = GhostModeFeatureStrings(
                title: "Режим привида",
                on: "Увімк.",
                off: "Вимк.",
                masterInfo: "Читає хмарні повідомлення та історії локально, приховуючи прочитання, статус «У мережі» й набір тексту. Секретні чати не змінюються.",
                suppressMessageReadReceipts: "Не позначати повідомлення прочитаними",
                suppressMessageReadReceiptsInfo: "Повідомлення читаються лише на цьому iPhone і залишаються непрочитаними на сервері до ручного підтвердження або надсилання.",
                suppressStoryReadReceipts: "Не позначати історії переглянутими",
                suppressStoryReadReceiptsInfo: "Перегляд історії залишається локальним. Відповідь або реакція підтверджує перегляд цієї історії.",
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
                keepViewOnceMediaInfo: "Одноразові фото, відео, голосові та кружечки можна переглядати скільки завгодно разів, зокрема в секретних чатах. Відправник бачить їх непереглянутими, доки ви не натиснете «Спалити».",
                burnViewOnceMedia: "Спалити"
            )
            self.localMessageArchive = LocalMessageArchiveFeatureStrings(
                title: "Видалені та змінені",
                archiveDeletedMessages: "Зберігати видалені повідомлення",
                archiveDeletedMessagesInfo: "Зберігає видалені хмарні повідомлення, зокрема зникаючі та одноразові медіа. Секретні чати не зберігаються.",
                archiveEditedMessages: "Зберігати версії змін",
                archiveEditedMessagesInfo: "Зберігає попередні версії відредагованих повідомлень. Якщо збереження видалених вимкнено, версії видаляються разом із повідомленням.",
                deletedMessageMarker: "Позначка видаленого повідомлення",
                deletedMessageMarkerInfo: "Текст або емодзі біля часу видаленого повідомлення. Порожнє значення відображається як 🧹.",
                keepBetweenLaunches: "Зберігати між запусками",
                keepBetweenLaunchesInfo: "Зберігає архів після повного закриття застосунку; інакше він очищається під час наступного холодного запуску.",
                mediaLimit: "Ліміт медіа",
                mediaLimitInfo: "Обмежує збережені файли. За переповнення першими видаляються найбільші медіа, а текст і версії залишаються.",
                archiveUsage: "Розмір архіву",
                clearMedia: "Очистити медіа",
                clearArchive: "Очистити архів",
                clearActionsInfo: "«Очистити медіа» видаляє лише збережені файли. «Очистити архів» остаточно видаляє локальні повідомлення, версії та пов’язані медіа з цього iPhone.",
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
                title: "Налаштування інтерфейсу",
                tabsSection: "НИЖНЯ ПАНЕЛЬ",
                profilesSection: "ПРОФІЛІ",
                storiesSection: "ІСТОРІЇ",
                mediaSection: "КРУГЛІ ВІДЕО",
                privacySection: "ЛОКАЛЬНА ПРИВАТНІСТЬ",
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
                showRegistrationDateInfo: "Показує приблизну дату реєстрації лише тоді, коли Telegram уже передав її клієнту.",
                showChatCreationDate: "Дата створення чату",
                showChatCreationDateInfo: "Показує дату першого доступного повідомлення або створення групи. Для деяких чатів значення невідоме.",
                profileIdentifierLabel: "User ID",
                dataCenterLabel: "DC",
                registrationDateLabel: "Дата реєстрації",
                chatCreationDateLabel: "Дата створення чату",
                hideStoryStrip: "Приховувати стрічку історій",
                hideStoryStripInfo: "Прибирає історії з верхньої частини списку чатів, не видаляючи їх і не змінюючи стан на сервері.",
                disableStoryCameraSwipe: "Вимкнути свайп до камери",
                disableStoryCameraSwipeInfo: "Не відкриває камеру історій свайпом зі списку чатів.",
                confirmStoryOpen: "Запитувати перед переглядом",
                confirmStoryOpenInfo: "Показує підтвердження перед початком перегляду історії.",
                allowStoryRepost: "Пропонувати репост в історію",
                allowStoryRepostInfo: "Показує дію репосту в історію на екрані пересилання.",
                startRoundVideoWithRearCamera: "Починати із задньої камери",
                startRoundVideoWithRearCameraInfo: "Відкриває запис круглого відео одразу на задній камері.",
                hidePhoneInSettings: "Приховувати номер у налаштуваннях",
                hidePhoneInSettingsInfo: "Приховує ваш номер лише на екрані налаштувань цього застосунку. Видимість номера для інших людей не змінюється.",
                restartNotice: "Деякі параметри нижньої панелі та номера застосовуються після перезапуску застосунку.",
                storyConfirmationTitle: "Відкрити історію?",
                storyConfirmationText: "Автор може побачити ваш перегляд.",
                storyConfirmationAction: "Переглянути"
            )
            self.madgram = MadgramFeatureStrings(
                title: "Madgram",
                featuresSection: "ФУНКЦІЇ MADGRAM",
                info: "Функції, яких немає у звичайному Telegram. Усі дані цих функцій зберігаються лише на цьому пристрої.",
                forwardWithoutAuthor: "Переслати без автора",
                powerSection: "ЕНЕРГОСПОЖИВАННЯ",
                powerSaving: "Ощадливий режим",
                powerSavingInfo: "Постійно, а не лише за низького заряду: без автовідтворення відео та GIF, без зациклених стикерів і емодзі, без розмиття, без фонового завантаження й фонових задач, зі спрощеними анімаціями інтерфейсу. Усі функції лишаються доступними — відео та стикери запускаються дотиком."
            )
            self.localPremium = LocalPremiumFeatureStrings(
                section: "ПРЕМІУМ",
                title: "Локальний преміум",
                info: "Розблоковує інтерфейс Telegram Premium лише на цьому пристрої. Можливості, які перевіряє сервер — великі файли, преміум-реакції та емодзі, розшифрування голосових — і надалі потребують підписки."
            )
            self.messageFilter = MessageFilterFeatureStrings(
                title: "Фільтри повідомлень",
                hideBlockedUsers: "Приховувати повідомлення з чорного списку",
                hideBlockedUsersInfo: "Не показує повідомлення людей, яких ви заблокували. Повідомлення залишаються на сервері та в локальній базі, їх просто не видно.",
                hiddenPeersSection: "ПРИХОВАНІ ВІДПРАВНИКИ",
                hiddenPeersInfo: "Тіньовий бан: людина не знає, що прихована, і не потрапляє до чорного списку — ви просто не бачите її повідомлень.",
                hiddenPeersEmpty: "Поки нікого не приховано. Приховати відправника можна через контекстне меню його повідомлення.",
                hideMessages: "Приховати повідомлення",
                showMessages: "Показувати повідомлення",
                hiddenMessagePlaceholder: "Повідомлення приховано",
                messagesHidden: "Повідомлення цього відправника приховано.",
                messagesShown: "Повідомлення цього відправника знову видно.",
                show: "Показувати"
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
        default:
            self.ghostMode = GhostModeFeatureStrings(
                title: "Ghost Mode",
                on: "On",
                off: "Off",
                masterInfo: "Reads cloud messages and stories locally while hiding read receipts, online presence and typing. Secret chats are unchanged.",
                suppressMessageReadReceipts: "Don't Read Messages",
                suppressMessageReadReceiptsInfo: "Messages are read only on this iPhone and stay unread on the server until manually confirmed or sent.",
                suppressStoryReadReceipts: "Don't Read Stories",
                suppressStoryReadReceiptsInfo: "Story views stay local. Replying or reacting confirms the view of that story.",
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
                keepViewOnceMediaInfo: "View-once photos, videos, voice and video messages can be replayed any number of times, including in secret chats. The sender sees them as unopened until you tap Burn.",
                burnViewOnceMedia: "Burn"
            )
            self.localMessageArchive = LocalMessageArchiveFeatureStrings(
                title: "Deleted and Edited",
                archiveDeletedMessages: "Save Deleted Messages",
                archiveDeletedMessagesInfo: "Saves deleted cloud messages, including disappearing and view-once media. Secret chats are never saved.",
                archiveEditedMessages: "Save Edit Versions",
                archiveEditedMessagesInfo: "Saves previous versions of edited messages. When saving deleted messages is off, versions are removed with the original message.",
                deletedMessageMarker: "Deleted Message Marker",
                deletedMessageMarkerInfo: "Text or emoji displayed beside a deleted message’s time. An empty value is displayed as 🧹.",
                keepBetweenLaunches: "Keep Between Launches",
                keepBetweenLaunchesInfo: "Keeps the archive after the app fully closes; otherwise it is cleared on the next cold launch.",
                mediaLimit: "Media Limit",
                mediaLimitInfo: "Limits retained files. The largest media is removed first while message text and edit history remain.",
                archiveUsage: "Archive Usage",
                clearMedia: "Clear Media",
                clearArchive: "Clear Archive",
                clearActionsInfo: "“Clear Media” removes only retained files. “Clear Archive” permanently removes local messages, versions and related media from this iPhone.",
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
                usage: { messageCount, versionCount, size in
                    return "Messages: \(messageCount) · versions: \(versionCount) · size: \(size)"
                },
                versionCount: { count in
                    return count == 1 ? "1 version" : "\(count) versions"
                }
            )
            self.interfaceTuning = InterfaceTuningFeatureStrings(
                title: "Interface Tuning",
                tabsSection: "BOTTOM BAR",
                profilesSection: "PROFILES",
                storiesSection: "STORIES",
                mediaSection: "ROUND VIDEOS",
                privacySection: "LOCAL PRIVACY",
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
                showRegistrationDateInfo: "Shows an approximate registration date only when Telegram has already supplied it to the client.",
                showChatCreationDate: "Chat Creation Date",
                showChatCreationDateInfo: "Shows the first available message date or group creation date. It is unavailable for some chats.",
                profileIdentifierLabel: "User ID",
                dataCenterLabel: "DC",
                registrationDateLabel: "Registration date",
                chatCreationDateLabel: "Chat created",
                hideStoryStrip: "Hide Story Strip",
                hideStoryStripInfo: "Removes stories from the top of the chat list without deleting them or changing server state.",
                disableStoryCameraSwipe: "Disable Camera Swipe",
                disableStoryCameraSwipeInfo: "Prevents opening the story camera by swiping from the chat list.",
                confirmStoryOpen: "Confirm Before Viewing",
                confirmStoryOpenInfo: "Asks for confirmation before story playback begins.",
                allowStoryRepost: "Offer Story Repost",
                allowStoryRepostInfo: "Shows the repost-to-story action on the forwarding screen.",
                startRoundVideoWithRearCamera: "Start With Rear Camera",
                startRoundVideoWithRearCameraInfo: "Starts round-video recording with the rear camera.",
                hidePhoneInSettings: "Hide Phone in Settings",
                hidePhoneInSettingsInfo: "Hides your number only in this app's settings UI. It does not change who can see it.",
                restartNotice: "Some bottom-bar and phone-number changes apply after restarting the app.",
                storyConfirmationTitle: "Open this story?",
                storyConfirmationText: "The author may be able to see your view.",
                storyConfirmationAction: "View"
            )
            self.madgram = MadgramFeatureStrings(
                title: "Madgram",
                featuresSection: "MADGRAM FEATURES",
                info: "Features that stock Telegram doesn't have. Everything they store stays on this device.",
                forwardWithoutAuthor: "Forward without sender",
                powerSection: "POWER USAGE",
                powerSaving: "Low Power Profile",
                powerSavingInfo: "Always on, not just on low battery: no video and GIF autoplay, no looping stickers and emoji, no blur, no background downloads or background work, and simplified interface animations. Nothing is removed — videos and stickers play when you tap them."
            )
            self.localPremium = LocalPremiumFeatureStrings(
                section: "PREMIUM",
                title: "Local Premium",
                info: "Unlocks the Telegram Premium interface on this device only. Anything the server validates — large uploads, premium reactions and emoji, voice transcription — still requires a subscription."
            )
            self.messageFilter = MessageFilterFeatureStrings(
                title: "Message Filters",
                hideBlockedUsers: "Hide Messages from Blocked Users",
                hideBlockedUsersInfo: "Hides messages from people you have blocked. The messages stay on the server and in the local database, they are simply not displayed.",
                hiddenPeersSection: "HIDDEN SENDERS",
                hiddenPeersInfo: "Shadow ban: the person is not blocked and never learns they are hidden — you just don't see their messages.",
                hiddenPeersEmpty: "Nobody is hidden yet. Hide a sender from the context menu of their message.",
                hideMessages: "Hide Messages",
                showMessages: "Show Messages",
                hiddenMessagePlaceholder: "Message hidden",
                messagesHidden: "Messages from this sender are now hidden.",
                messagesShown: "Messages from this sender are visible again.",
                show: "Show"
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
        }
    }
}

public extension PresentationStrings {
    var localFeatures: LocalFeatureStrings {
        return LocalFeatureStrings(strings: self)
    }
}
