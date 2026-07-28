# MadGram for iOS

[Русский](#русский) · [English](#english)

## Русский

MadGram — неофициальный клиент Telegram для iPhone, созданный на основе исходного кода
[Telegram iOS](https://github.com/TelegramMessenger/Telegram-iOS). Он сохраняет привычный интерфейс
и добавляет инструменты приватности, локальную работу с сообщениями и дополнительные настройки.

MadGram не связан с Telegram и не одобрен Telegram.

### Возможности

- **Режим призрака** позволяет оставаться офлайн, читать чаты и смотреть истории без раскрытия
  статуса в сети, отметок о прочтении и набора текста.
- **Удалённые и изменённые сообщения** сохраняются в локальном архиве с независимыми
  переключателями, историей версий, настраиваемой меткой и лимитами хранения.
- **Фильтры сообщений** скрывают сообщения выбранных пользователей, не удаляя их из аккаунта.
- **Message Shot** создаёт снимки цепочек сообщений с настройкой темы, обоев, аватаров, времени,
  реакций и спойлеров.
- **Пересылка без автора** использует обычный экран выбора получателей, но скрывает имя отправителя
  там, где Telegram поддерживает такую пересылку.
- **Локальный Premium** включает клиентские элементы Premium-интерфейса. Серверные лимиты и платные
  функции по-прежнему требуют настоящей подписки Telegram Premium.
- **Настройка интерфейса** управляет вкладками, данными профиля, историями, камерой видеосообщений
  и отображением номера телефона.
- **Пользовательские бейджи** загружаются из подписанного реестра и отображаются рядом с профилями.
- **Энергосбережение** одной настройкой ограничивает анимации, автовоспроизведение и фоновую работу.

Настройки MadGram доступны на русском, украинском и английском языках.

### Сборка

Проект собирается Bazel через `build-system/Make/Make.py`. Используйте версию Xcode, указанную в
`versions.json`.

```sh
git clone --recursive https://github.com/yar2slav/Madgram-iOS.git
cd Madgram-iOS

cp build-system/template_minimal_development_configuration.json \
  build-system/local-development-configuration.json
```

Укажите в локальном файле собственные bundle identifier, Telegram `api_id`, Telegram `api_hash` и
Apple Team ID. Файл исключён из Git и не должен попадать в коммиты.

Создание Xcode-проекта:

```sh
python3 build-system/Make/Make.py \
  --cacheDir="$HOME/telegram-bazel-cache" \
  generateProject \
  --configurationPath=build-system/local-development-configuration.json \
  --xcodeManagedCodesigning
```

Сборка для симулятора на Apple Silicon:

```sh
python3 build-system/Make/Make.py \
  --overrideXcodeVersion \
  --cacheDir="$HOME/telegram-bazel-cache" \
  build \
  --configurationPath=build-system/local-development-configuration.json \
  --xcodeManagedCodesigning \
  --buildNumber=1 \
  --configuration=debug_sim_arm64
```

Для устройства и распространения приложения потребуются подходящие сертификаты и provisioning
profiles.

### Приватность

Архив сообщений, фильтры и настройки MadGram хранятся на устройстве. Сообщения и данные аккаунта
продолжают использовать инфраструктуру Telegram и регулируются протоколом и политикой приватности
Telegram.

При включённой настройке Ghost Mode одноразовое медиа может оставаться доступным до явного нажатия
Burn. Пока оно удерживается, клиент не отправляет уведомление о скриншоте в секретном чате. Защита
платного контента и сообщений с явным запретом копирования не обходится.

Клиент периодически получает подписанный реестр бейджей с `https://b.mad.tg`. Содержимое сообщений
и чатов в этот запрос не включается.

### Требования upstream

Перед распространением сборки:

- получите собственные Telegram API credentials;
- используйте отдельные название и иконку приложения;
- явно укажите, что клиент неофициальный;
- сохраните уведомления об открытых лицензиях и соблюдайте лицензии Telegram iOS и зависимостей.

Исходный upstream доступен в
[`TelegramMessenger/Telegram-iOS`](https://github.com/TelegramMessenger/Telegram-iOS).

## English

MadGram is an unofficial Telegram client for iPhone built on top of the official
[Telegram iOS](https://github.com/TelegramMessenger/Telegram-iOS) source. It keeps the familiar
interface while adding privacy controls, local message tools and extra customization.

MadGram is not affiliated with or endorsed by Telegram.

### Features

- **Ghost Mode** keeps the account offline while chats and stories are viewed, with separate
  controls for read receipts, online status and typing status.
- **Deleted and edited messages** can be archived locally, with independent controls, edit history,
  configurable markers and storage limits.
- **Message filters** hide messages from selected users without deleting anything from the account.
- **Message Shot** exports message chains with theme, wallpaper, avatar, timestamp, reaction and
  spoiler controls.
- **Forward without sender** uses the standard recipient picker while removing sender attribution
  where Telegram supports it.
- **Local Premium** unlocks client-side Premium interface elements. Server-side limits and paid
  features still require a real Telegram Premium subscription.
- **Interface tuning** adds controls for tabs, profile details, stories, the round-video camera and
  phone-number visibility.
- **Custom peer badges** are downloaded from a signed registry and displayed alongside profiles.
- **Power Saving** applies a single low-power preset for animations, autoplay and background work.

MadGram-specific settings are available in Russian, Ukrainian and English.

### Building

The project uses Bazel through `build-system/Make/Make.py`. Use the Xcode version listed in
`versions.json`.

```sh
git clone --recursive https://github.com/yar2slav/Madgram-iOS.git
cd Madgram-iOS

cp build-system/template_minimal_development_configuration.json \
  build-system/local-development-configuration.json
```

Set your own bundle identifier, Telegram `api_id`, Telegram `api_hash` and Apple Team ID in the local
file. It is ignored by Git and must not be committed.

Generate an Xcode project:

```sh
python3 build-system/Make/Make.py \
  --cacheDir="$HOME/telegram-bazel-cache" \
  generateProject \
  --configurationPath=build-system/local-development-configuration.json \
  --xcodeManagedCodesigning
```

Build for an Apple Silicon simulator:

```sh
python3 build-system/Make/Make.py \
  --overrideXcodeVersion \
  --cacheDir="$HOME/telegram-bazel-cache" \
  build \
  --configurationPath=build-system/local-development-configuration.json \
  --xcodeManagedCodesigning \
  --buildNumber=1 \
  --configuration=debug_sim_arm64
```

Device and distribution builds require matching Apple signing identities and provisioning profiles.

### Privacy

MadGram's archive, filters and settings are stored on the device. Telegram messages and account data
continue to use Telegram's infrastructure and are subject to Telegram's protocol and privacy policy.

When the relevant Ghost Mode option is enabled, view-once media can remain available until it is
explicitly burned. While it is retained, the client does not send a screenshot notification in a
secret chat. Paid content and messages with explicit copy protection remain protected.

The client periodically downloads a signed badge registry from `https://b.mad.tg`. Message and chat
contents are not included in this request.

### Upstream requirements

Before distributing a build:

- obtain your own Telegram API credentials;
- use a distinct application name and icon;
- make it clear that the client is unofficial;
- retain the applicable open-source notices and comply with the licenses of Telegram iOS and its
  bundled dependencies.

The upstream source remains available at
[`TelegramMessenger/Telegram-iOS`](https://github.com/TelegramMessenger/Telegram-iOS).
