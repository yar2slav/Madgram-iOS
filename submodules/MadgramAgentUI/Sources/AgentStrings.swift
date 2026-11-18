import Foundation
import MadgramAgent

struct AgentStrings {
    let title: String
    let settingsTitle: String
    let newChat: String
    let newChatConfirm: String
    let chatHistory: String
    let chatHistoryEmpty: String
    let untitledChat: String
    let deleteChat: String
    let waitForReply: String
    let inputPlaceholder: String
    let emptyTitle: String
    let emptyText: String
    let emptyNoKeyText: String
    let openSettings: String
    let suggestions: [String]
    let thinking: String
    let retry: String
    let send: String
    let cancel: String
    let confirmTitle: (String) -> String
    let sendDeclined: String
    let sent: (String) -> String
    let copy: String
    let copied: String

    let toolListChats: String
    let toolListUnread: String
    let toolSearch: (String) -> String
    let toolRead: (String) -> String
    let toolReadDone: (String, Int) -> String
    let toolSending: (String) -> String
    let unknownChat: String
    let autoReplyOn: (String) -> String
    let autoReplyOff: (String) -> String
    let autoReplySection: String
    let autoReplyInfo: String
    let autoReplyEmpty: String
    let autoReplyClear: String
    let sendWithoutConfirmation: String
    let sendWithoutConfirmationInfo: String
    let agentTab: String
    let agentTabInfo: String
    let tabTitle: String
    let autoReplyBar: (String) -> String
    let autoReplyBarMany: (Int) -> String
    let autoReplyStop: String
    let autoReplyStopAll: String
    let autoReplyNoteTitle: (String) -> String
    let autoReplyUrgentTitle: (String) -> String
    let autoReplyStoppedTitle: (String) -> String
    let toolSearchMessages: (String) -> String
    let toolSearchMessagesDone: (String, Int) -> String
    let toolChatAction: (String) -> String
    let toolChatActionDone: (String, String) -> String
    let toolForward: (String) -> String
    let toolForwardDone: (String, Int) -> String
    let toolSchedule: (String) -> String
    let scheduled: (String, String) -> String
    let toolRemind: String
    let reminded: (String) -> String
    let toolDraft: (String) -> String
    let drafted: (String) -> String
    let toolTranscribe: String
    let toolTranscribeDone: String
    let webSearching: String
    let webFetching: String
    let allowChatActions: String
    let allowForwarding: String
    let allowWebSearch: String
    let extraAccessInfo: String
    let toolViewPhoto: String
    let toolViewPhotoDone: String
    let toolWebSearch: (String) -> String
    let toolWebFetch: (String) -> String
    let toolSearchThisChat: (String) -> String
    let autoReplyWebSearch: String
    let autoReplyLiveStatus: String
    let agentNotifications: String
    let attachPhoto: String
    let toolReadPeriod: (String) -> String
    let toolReadPeriodDone: (String, Int) -> String
    let photoPrefix: String

    let providerSection: String
    let providerAnthropic: String
    let providerOpenAI: String
    let providerAnthropicCompatible: String
    let providerOpenAICompatible: String
    let providerInfo: String
    let baseUrl: String
    let baseUrlPlaceholder: String
    let apiKey: String
    let apiKeyPlaceholder: String
    let apiKeyInfo: String
    let model: String
    let modelNotSelected: String
    let modelsTitle: String
    let modelManual: String
    let modelManualPlaceholder: String
    let modelManualInfo: String
    let modelsLoading: String
    let modelsSection: String
    let modelsFailed: (String) -> String
    let modelsNeedKey: String
    let personaSection: String
    let personaPlaceholder: String
    let personaInfo: String
    let personaReset: String
    let accessSection: String
    let allowRead: String
    let allowSend: String
    let accessInfo: String
    let clearHistory: String
    let clearHistoryDone: String

    init(languageCode: String) {
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

        self.title = t("ИИ-агент", "ШІ-агент", "AI Agent")
        self.settingsTitle = t("Настройки агента", "Налаштування агента", "Agent Settings")
        self.newChat = t("Новый диалог", "Новий діалог", "New Chat")
        self.chatHistory = t("История диалогов", "Історія діалогів", "Chat History")
        self.chatHistoryEmpty = t("Пока нет сохранённых диалогов", "Поки немає збережених діалогів", "No saved chats yet")
        self.untitledChat = t("Без названия", "Без назви", "Untitled")
        self.deleteChat = t("Удалить", "Видалити", "Delete")
        self.waitForReply = t("Дождись, пока агент ответит", "Дочекайся, поки агент відповість", "Wait for the agent to finish")
        self.newChatConfirm = t("Начать новый диалог? Текущий удалится.", "Почати новий діалог? Поточний видалиться.", "Start a new chat? The current one will be deleted.")
        self.inputPlaceholder = t("Сообщение агенту", "Повідомлення агенту", "Message the agent")
        self.emptyTitle = t("Чем помочь?", "Чим допомогти?", "How can I help?")
        self.emptyText = t("Перескажу переписку, найду нужное в чатах, помогу ответить или просто поболтаю.", "Перекажу листування, знайду потрібне в чатах, допоможу відповісти або просто побалакаю.", "I can summarize chats, find things in them, help you reply, or just talk.")
        self.emptyNoKeyText = t("Сначала добавь API-ключ: Anthropic, OpenAI или любой совместимый сервис.", "Спочатку додай API-ключ: Anthropic, OpenAI або будь-який сумісний сервіс.", "Add an API key first: Anthropic, OpenAI or any compatible service.")
        self.openSettings = t("Открыть настройки", "Відкрити налаштування", "Open Settings")
        self.suggestions = [
            t("Что я пропустил в непрочитанных?", "Що я пропустив у непрочитаних?", "What did I miss in unread chats?"),
            t("Перескажи последний чат", "Перекажи останній чат", "Summarize my latest chat"),
            t("Помоги вежливо отказаться от встречи", "Допоможи ввічливо відмовитися від зустрічі", "Help me politely decline a meeting")
        ]
        self.thinking = t("Думаю…", "Думаю…", "Thinking…")
        self.retry = t("Повторить", "Повторити", "Retry")
        self.send = t("Отправить", "Надіслати", "Send")
        self.cancel = t("Отмена", "Скасувати", "Cancel")
        self.confirmTitle = { chat in t("Отправить в «\(chat)»?", "Надіслати в «\(chat)»?", "Send to “\(chat)”?") }
        self.sendDeclined = t("Пользователь отменил отправку.", "Користувач скасував надсилання.", "The user declined to send it.")
        self.sent = { chat in t("Отправлено в «\(chat)»", "Надіслано в «\(chat)»", "Sent to “\(chat)”") }
        self.copy = t("Скопировать", "Скопіювати", "Copy")
        self.copied = t("Скопировано", "Скопійовано", "Copied")

        self.toolListChats = t("Смотрю список чатов", "Дивлюся список чатів", "Looking at chats")
        self.toolListUnread = t("Смотрю непрочитанные", "Дивлюся непрочитані", "Looking at unread chats")
        self.toolSearch = { query in t("Ищу «\(query)»", "Шукаю «\(query)»", "Searching “\(query)”") }
        self.toolRead = { chat in t("Читаю «\(chat)»", "Читаю «\(chat)»", "Reading “\(chat)”") }
        self.toolReadDone = { chat, count in t("Прочитал «\(chat)» · \(count)", "Прочитав «\(chat)» · \(count)", "Read “\(chat)” · \(count)") }
        self.toolSending = { chat in t("Отправка в «\(chat)»", "Надсилання в «\(chat)»", "Sending to “\(chat)”") }
        self.unknownChat = t("чат", "чат", "chat")
        self.autoReplyOn = { chat in t("Автоответчик для «\(chat)»", "Автовідповідач для «\(chat)»", "Auto-reply for “\(chat)”") }
        self.autoReplyOff = { chat in t("Автоответчик выключен: «\(chat)»", "Автовідповідач вимкнено: «\(chat)»", "Auto-reply off: “\(chat)”") }
        self.autoReplySection = t("АВТООТВЕТЧИК", "АВТОВІДПОВІДАЧ", "AUTO-REPLY")
        self.autoReplyInfo = t("Включается из диалога с агентом: «будь моим автоответчиком с …». Отвечает сам, без подтверждения, пока приложение открыто или живо в фоне. Видит только эту переписку и не выполняет просьбы собеседника.", "Вмикається з діалогу з агентом: «будь моїм автовідповідачем з …». Відповідає сам, без підтвердження, поки застосунок відкритий або живий у фоні. Бачить лише це листування й не виконує прохань співрозмовника.", "Turn it on from the agent chat: “be my auto-responder with …”. It replies on its own while the app is open or alive in the background, sees only that chat and ignores requests from the other person.")
        self.autoReplyEmpty = t("Пока ни для кого не включён", "Поки ні для кого не ввімкнено", "Not enabled for anyone yet")
        self.autoReplyClear = t("Удалить все автоответчики", "Видалити всі автовідповідачі", "Remove All Auto-Replies")
        self.sendWithoutConfirmation = t("Отправлять без подтверждения", "Надсилати без підтвердження", "Send without confirmation")
        self.sendWithoutConfirmationInfo = t("Агент отправляет сообщения сразу, без карточки. Включай, только если доверяешь модели.", "Агент надсилає повідомлення одразу, без картки. Вмикай, лише якщо довіряєш моделі.", "The agent sends messages right away, without the card. Only if you trust the model.")
        self.agentTab = t("Агент отдельной вкладкой", "Агент окремою вкладкою", "Agent as a tab")
        self.agentTabInfo = t("Чат с агентом появится в нижней панели рядом с чатами.", "Чат з агентом з'явиться в нижній панелі поруч із чатами.", "The agent chat appears in the tab bar next to Chats.")
        self.tabTitle = t("Агент", "Агент", "Agent")
        self.autoReplyBar = { chat in t("Автоответчик: \(chat)", "Автовідповідач: \(chat)", "Auto-reply: \(chat)") }
        self.autoReplyBarMany = { count in t("Автоответчик в \(count) чатах", "Автовідповідач у \(count) чатах", "Auto-reply in \(count) chats") }
        self.autoReplyStop = t("Стоп", "Стоп", "Stop")
        self.autoReplyStopAll = t("Стоп все", "Стоп усі", "Stop All")
        self.autoReplyNoteTitle = { chat in t("Автоответчик · \(chat)", "Автовідповідач · \(chat)", "Auto-reply · \(chat)") }
        self.autoReplyUrgentTitle = { chat in t("Срочно · \(chat)", "Терміново · \(chat)", "Urgent · \(chat)") }
        self.autoReplyStoppedTitle = { chat in t("Автоответчик остановлен · \(chat)", "Автовідповідач зупинено · \(chat)", "Auto-reply stopped · \(chat)") }
        self.toolSearchMessages = { query in t("Ищу сообщения «\(query)»", "Шукаю повідомлення «\(query)»", "Searching messages “\(query)”") }
        self.toolSearchMessagesDone = { query, count in t("Нашёл «\(query)» · \(count)", "Знайшов «\(query)» · \(count)", "Found “\(query)” · \(count)") }
        self.toolChatAction = { chat in t("Действие с «\(chat)»", "Дія з «\(chat)»", "Action on “\(chat)”") }
        self.toolChatActionDone = { chat, done in t("«\(chat)»: \(done)", "«\(chat)»: \(done)", "“\(chat)”: \(done)") }
        self.toolForward = { chat in t("Пересылаю в «\(chat)»", "Пересилаю в «\(chat)»", "Forwarding to “\(chat)”") }
        self.toolForwardDone = { chat, count in t("Переслал в «\(chat)» · \(count)", "Переслав у «\(chat)» · \(count)", "Forwarded to “\(chat)” · \(count)") }
        self.toolSchedule = { chat in t("Планирую в «\(chat)»", "Планую в «\(chat)»", "Scheduling to “\(chat)”") }
        self.scheduled = { chat, when in t("Запланировал в «\(chat)» · \(when)", "Запланував у «\(chat)» · \(when)", "Scheduled to “\(chat)” · \(when)") }
        self.toolRemind = t("Ставлю напоминание", "Ставлю нагадування", "Setting a reminder")
        self.reminded = { when in t("Напомню · \(when)", "Нагадаю · \(when)", "Reminder · \(when)") }
        self.toolDraft = { chat in t("Черновик в «\(chat)»", "Чернетка в «\(chat)»", "Draft in “\(chat)”") }
        self.drafted = { chat in t("Черновик в «\(chat)» готов", "Чернетка в «\(chat)» готова", "Draft in “\(chat)” ready") }
        self.toolTranscribe = t("Расшифровываю голосовое", "Розшифровую голосове", "Transcribing voice")
        self.toolTranscribeDone = t("Расшифровал голосовое", "Розшифрував голосове", "Transcribed voice")
        self.webSearching = t("Ищу в интернете…", "Шукаю в інтернеті…", "Searching the web…")
        self.webFetching = t("Читаю страницу…", "Читаю сторінку…", "Reading the page…")
        self.allowChatActions = t("Действия с чатами", "Дії з чатами", "Chat actions")
        self.allowForwarding = t("Пересылка сообщений", "Пересилання повідомлень", "Forward messages")
        self.allowWebSearch = t("Поиск в интернете", "Пошук в інтернеті", "Web search")
        self.toolViewPhoto = t("Смотрю фото", "Дивлюся фото", "Looking at the photo")
        self.toolViewPhotoDone = t("Посмотрел фото", "Подивився фото", "Looked at the photo")
        self.toolWebSearch = { query in t("Ищу в интернете «\(query)»", "Шукаю в інтернеті «\(query)»", "Web search “\(query)”") }
        self.toolWebFetch = { host in t("Читаю \(host)", "Читаю \(host)", "Reading \(host)") }
        self.toolSearchThisChat = { query in t("Ищу в чате «\(query)»", "Шукаю в чаті «\(query)»", "Searching chat “\(query)”") }
        self.agentNotifications = t("Уведомления от агента", "Сповіщення від агента", "Notifications from the agent")
        self.autoReplyLiveStatus = t("Статус в чате: думаю, ищу…", "Статус у чаті: думаю, шукаю…", "Live status in chat")
        self.autoReplyWebSearch = t("Интернет в автоответчике", "Інтернет в автовідповідачі", "Web in auto-reply")
        self.toolReadPeriod = { chat in t("Листаю «\(chat)»", "Гортаю «\(chat)»", "Scrolling “\(chat)”") }
        self.toolReadPeriodDone = { chat, count in t("Пролистал «\(chat)» · \(count)", "Прогорнув «\(chat)» · \(count)", "Scrolled “\(chat)” · \(count)") }
        self.attachPhoto = t("Прикрепить фото", "Прикріпити фото", "Attach photo")
        self.photoPrefix = t("[фото] ", "[фото] ", "[photo] ")
        self.extraAccessInfo = t("Действия: прочитать, заглушить, архив, закреп — сразу, без подтверждения. Поиск в интернете работает с официальным Anthropic.", "Дії: прочитати, заглушити, архів, закріп — одразу, без підтвердження. Пошук в інтернеті працює з офіційним Anthropic.", "Actions (read, mute, archive, pin) run right away. Web search works with the official Anthropic API.")

        self.providerSection = t("ПРОВАЙДЕР", "ПРОВАЙДЕР", "PROVIDER")
        self.providerAnthropic = "Anthropic"
        self.providerOpenAI = "OpenAI"
        self.providerAnthropicCompatible = t("Совместимый с Anthropic", "Сумісний з Anthropic", "Anthropic-compatible")
        self.providerOpenAICompatible = t("Совместимый с OpenAI", "Сумісний з OpenAI", "OpenAI-compatible")
        self.providerInfo = t("Совместимые — свой адрес API: прокси, OpenRouter, локальные модели и т.п.", "Сумісні — своя адреса API: проксі, OpenRouter, локальні моделі тощо.", "Compatible means your own API address: proxies, OpenRouter, local models and so on.")
        self.baseUrl = t("Адрес API", "Адреса API", "API address")
        self.baseUrlPlaceholder = "https://example.com/v1"
        self.apiKey = t("API-ключ", "API-ключ", "API key")
        self.apiKeyPlaceholder = t("Вставь ключ", "Встав ключ", "Paste the key")
        self.apiKeyInfo = t("Ключ хранится только на этом устройстве в связке ключей. Переписки, которые читает агент, уходят выбранному провайдеру.", "Ключ зберігається лише на цьому пристрої у в'язці ключів. Листування, яке читає агент, іде обраному провайдеру.", "The key stays on this device in the keychain. Chats the agent reads are sent to the selected provider.")
        self.model = t("Модель", "Модель", "Model")
        self.modelNotSelected = t("Не выбрана", "Не обрана", "Not selected")
        self.modelsTitle = t("Модель", "Модель", "Model")
        self.modelManual = t("ВРУЧНУЮ", "ВРУЧНУ", "MANUALLY")
        self.modelManualPlaceholder = t("Название модели", "Назва моделі", "Model name")
        self.modelManualInfo = t("Можно вписать любую модель, даже если её нет в списке.", "Можна вписати будь-яку модель, навіть якщо її немає в списку.", "You can type any model, even one that isn't listed.")
        self.modelsLoading = t("Загружаю список моделей…", "Завантажую список моделей…", "Loading models…")
        self.modelsSection = t("ДОСТУПНЫЕ МОДЕЛИ", "ДОСТУПНІ МОДЕЛІ", "AVAILABLE MODELS")
        self.modelsFailed = { error in t("Список не загрузился: \(error)", "Список не завантажився: \(error)", "Couldn't load the list: \(error)") }
        self.modelsNeedKey = t("Добавь API-ключ, чтобы загрузить список моделей.", "Додай API-ключ, щоб завантажити список моделей.", "Add an API key to load the models.")
        self.personaSection = t("КТО ТЫ", "ХТО ТИ", "PERSONA")
        self.personaPlaceholder = t("Опиши характер и манеру общения агента", "Опиши характер і манеру спілкування агента", "Describe the agent's character and tone")
        self.personaInfo = t("Системный промпт: кто агент, как говорит, что для тебя важно. Дата и доступ к чатам добавляются сами.", "Системний промпт: хто агент, як говорить, що для тебе важливо. Дата й доступ до чатів додаються самі.", "System prompt: who the agent is, how it talks, what matters to you. Date and chat access are added automatically.")
        self.personaReset = t("Вернуть стандартный", "Повернути стандартний", "Reset to Default")
        self.accessSection = t("ЧТО МОЖНО АГЕНТУ", "ЩО МОЖНА АГЕНТУ", "AGENT ACCESS")
        self.allowRead = t("Читать чаты", "Читати чати", "Read chats")
        self.allowSend = t("Отправлять сообщения", "Надсилати повідомлення", "Send messages")
        self.accessInfo = t("Каждую отправку ты подтверждаешь сам. Без доступа к чатам агент просто болтает.", "Кожне надсилання ти підтверджуєш сам. Без доступу до чатів агент просто балакає.", "You approve every send yourself. Without chat access the agent just chats.")
        self.clearHistory = t("Очистить историю диалога", "Очистити історію діалогу", "Clear Chat History")
        self.clearHistoryDone = t("История очищена", "Історію очищено", "History cleared")
    }

    func providerTitle(_ provider: AgentProviderKind) -> String {
        switch provider {
        case .anthropic:
            return self.providerAnthropic
        case .openai:
            return self.providerOpenAI
        case .anthropicCompatible:
            return self.providerAnthropicCompatible
        case .openaiCompatible:
            return self.providerOpenAICompatible
        }
    }
}
