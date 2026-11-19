<p align="center">
  <img src=".github/readme/icon.png" width="128" height="128" alt="mad">
</p>

<h1 align="center">mad</h1>

<p align="center">
  форк telegram для ios со своим ии-агентом, приватностью и чистой лентой
</p>

<p align="center">
  <a href="../../releases/latest">скачать</a> · <a href="#установка">установка</a> · <a href="#сборка">сборка</a> · <a href="https://t.me/+l-wwJloXQ802ZDcy">канал</a> · <a href="README.en.md">english</a>
</p>

<p align="center">
  <a href="../../releases/latest"><img src="https://img.shields.io/github/v/release/yar2slav/Madgram-iOS?label=%D1%80%D0%B5%D0%BB%D0%B8%D0%B7&color=111111&labelColor=2b2b2e" alt="релиз"></a>
  <a href="../../releases"><img src="https://img.shields.io/github/downloads/yar2slav/Madgram-iOS/total?label=%D1%81%D0%BA%D0%B0%D1%87%D0%B8%D0%B2%D0%B0%D0%BD%D0%B8%D0%B9&color=111111&labelColor=2b2b2e" alt="скачиваний"></a>
  <a href="../../stargazers"><img src="https://img.shields.io/github/stars/yar2slav/Madgram-iOS?label=%D0%B7%D0%B2%D1%91%D0%B7%D0%B4&color=111111&labelColor=2b2b2e" alt="звёзд"></a>
</p>

---

## что внутри

### ии-агент

- свой ии на отдельной вкладке, работает на твоём ключе: anthropic, openai или любой совместимый api, вплоть до локальных моделей
- пересказывает переписки и непрочитанное, ищет по всем чатам
- пишет и отправляет сообщения от твоего имени, готовит черновики ответов
- ставит напоминания и отложенные сообщения, смотрит фото, расшифровывает голосовые, ищет в интернете
- автоответчик в выбранных чатах: свой сценарий, лимит ответов в час и стоп-фразы
- несколько диалогов с историей, заметки автоответчика приходят в чат агента

### приватность

- режим призрака: читаешь чаты и смотришь истории без отметок о прочтении и без «в сети»
- призрак для отдельного чата
- одноразовые фото, видео и голосовые не сгорают, пока сам не нажмёшь «сжечь»
- блокировка чатов пин-кодом, паролем, графическим ключом или face id
- локальный пароль на траты звёзд, подарки и передачу nft
- номер можно скрыть везде
- локальные имена для людей и чатов, видишь их только ты

### архив удалённых и правок

- удалённые сообщения остаются в чате, включая исчезающие и одноразовые медиа
- полная история правок у каждого изменённого сообщения
- экспорт чата в txt, json или html вместе с удалёнными и правками

### чистая лента

- реклама в каналах и спонсорские сообщения скрываются
- свои правила скрытия по словам и регуляркам
- теневой бан: скрыть сообщения человека без блокировки, он не узнает
- плашки иноагентов вырезаются из текста
- спойлеры снимаются сами
- utm, fbclid и прочие метки слежки вычищаются из ссылок

### профиль

- аккаунты с других площадок: steam, github, gitlab, discord, reddit, twitch, spotify, soundcloud, last.fm и свой домен
- каждый аккаунт подтверждается входом, видят их только пользователи mad
- бейджи mad и цветные ники с эффектами: перелив, радуга, блик и пульс
- id, дата регистрации и даты вступления в группы прямо в профиле

### сообщения и медиа

- скриншот выбранных сообщений с обоями, аватарками и реакциями
- пересылка без автора
- бесплатный перевод и расшифровка голосовых без премиума
- камера в 4k и 60 кадров, кружки на ультраширике 0.5x
- точное число просмотров под постами

### уведомления

- пуш-уведомления с именем и текстом, пока mad живёт в фоне
- уведомления, когда выбранные люди заходят в сеть или выходят из неё
- уведомления о реакциях на твои сообщения

### интерфейс

- классический дизайн telegram до liquid glass
- настройки mad по категориям с поиском
- локальный премиум: эмодзи-статус, иконки, больше папок и закрепов
- чат «что нового» с живыми тумблерами функций прямо в сообщении

полный список по версиям лежит в [релизах](../../releases).

## куда ходит mad

| что | куда |
| --- | --- |
| переписка | серверы telegram, как в обычном клиенте |
| ии-агент | напрямую к провайдеру, чей ключ ты указал |
| бейджи, цветные ники, аккаунты профиля, свой домен | `b.mad.tg` |
| перевод сообщений | google translate |
| архив удалённых, правки, блокировки чатов | остаются на устройстве |

## установка

### через mad installer (проще всего)

[mad installer](https://github.com/yar2slav/mad-installer) ставит mad на айфон в пару кликов: подключаешь айфон кабелем, входишь в свой apple id и жмёшь «установить». он сам скачает релиз, подпишет его бесплатным сертификатом и поставит на телефон, а через 7 дней продлит подпись одной кнопкой.

<p>
  <a href="https://github.com/yar2slav/mad-installer/releases/latest/download/mad.installer_1.0.0_universal.dmg"><b>скачать для macOS</b></a> · <a href="https://github.com/yar2slav/mad-installer/releases/latest/download/mad.installer_1.0.0_x64-setup.exe"><b>скачать для Windows</b></a>
</p>

### вручную

1. скачай `ipa` из [последнего релиза](../../releases/latest)
2. подпиши и поставь через sideloadly, altstore, sidestore, feather, esign или свой сертификат

`ipa` в релизах без подписи. с бесплатным apple id подпись живёт 7 дней, потом её надо обновить.

## сборка

нужен mac с xcode. клонируй с подмодулями:

```bash
git clone --recursive -j8 https://github.com/yar2slav/Madgram-iOS.git
```

впиши свои `api_id`, `api_hash`, team id и bundle id в `build-system/template_minimal_development_configuration.json` и собери:

```bash
python3 build-system/Make/Make.py --overrideXcodeVersion --bazelArguments='--//Telegram:shareExtensionOnly' build --configurationPath build-system/template_minimal_development_configuration.json --xcodeManagedCodesigning --buildNumber=1 --configuration=release_arm64
```

подробный гайд от telegram: [docs/building.md](docs/building.md).

## связь

баги и идеи пиши в директ [канала](https://t.me/+l-wwJloXQ802ZDcy). автор: [yar2slav](https://t.me/yar2slav).

## благодарности

[telegram ios](https://github.com/TelegramMessenger/Telegram-iOS). mad не связан с telegram и не является официальным клиентом.
