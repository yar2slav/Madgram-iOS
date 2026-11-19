<p align="center">
  <img src=".github/readme/icon.png" width="128" height="128" alt="mad">
</p>

<h1 align="center">mad</h1>

<p align="center">
  a telegram fork for ios with its own ai agent, privacy tools and a clean feed
</p>

<p align="center">
  <a href="../../releases/latest">download</a> · <a href="#install">install</a> · <a href="#build">build</a> · <a href="https://t.me/+l-wwJloXQ802ZDcy">channel</a> · <a href="README.md">русский</a>
</p>

---

## features

### ai agent

- your own ai on its own tab, running on your key: anthropic, openai or any compatible api, local models included
- sums up chats and unread messages, searches across all chats
- writes and sends messages as you, drafts replies
- sets reminders and scheduled messages, looks at photos, transcribes voice messages, searches the web
- an auto-responder for chosen chats: its own script, an hourly limit and stop phrases
- several conversations with history, auto-responder notes arrive in the agent chat

### privacy

- ghost mode: read chats and watch stories without read receipts and without showing "online"
- ghost mode per chat
- view-once photos, videos and voice messages don't burn until you tap burn
- lock chats with a pin, password, pattern or face id
- a local password for spending stars, gifts and nft transfers
- your number can be hidden everywhere
- local names for people and chats that only you see

### deleted and edited message archive

- deleted messages stay in the chat, including disappearing and view-once media
- full edit history for every edited message
- chat export to txt, json or html with deleted messages and edits

### a clean feed

- channel ads and sponsored messages are hidden
- your own hiding rules by words and regular expressions
- shadow ban: hide a person's messages without blocking them, they never find out
- foreign agent disclaimers are cut from the text
- spoilers come off by themselves
- utm, fbclid and other trackers are stripped from links

### profile

- accounts from other platforms: steam, github, gitlab, discord, reddit, twitch, spotify, soundcloud, last.fm and your own domain
- each account is verified by signing in, and only mad users can see them
- mad badges and coloured names with effects: flow, rainbow, shimmer and pulse
- id, registration date and group join dates right in the profile

### messages and media

- screenshots of selected messages with wallpaper, avatars and reactions
- forward without the sender
- free translation and voice transcription without premium
- 4k 60 fps camera, round videos on the 0.5x ultra-wide lens
- exact view counts under posts

### notifications

- push notifications with the name and text while mad stays alive in the background
- alerts when chosen people come online or go offline
- notifications about reactions to your messages

### interface

- telegram's classic design from before liquid glass
- mad settings grouped into categories, with search
- local premium: emoji status, icons, more folders and pins
- a what's new chat with live feature toggles right in the message

the full list per version is in [releases](../../releases).

## where mad connects

| what | where |
| --- | --- |
| your chats | telegram servers, same as the official client |
| ai agent | straight to the provider whose key you entered |
| badges, coloured names, profile accounts, own domain | `b.mad.tg` |
| message translation | google translate |
| deleted archive, edit history, chat locks | stay on the device |

## install

### with mad installer (easiest)

[mad installer](https://github.com/yar2slav/mad-installer) puts mad on your iphone in a couple of clicks: plug in the iphone, sign in with your apple id and press install. it downloads the release, signs it with your free certificate and installs it, and renews the signature with one button after 7 days.

<p>
  <a href="https://github.com/yar2slav/mad-installer/releases/latest/download/mad.installer_1.0.0_universal.dmg"><b>download for macOS</b></a> · <a href="https://github.com/yar2slav/mad-installer/releases/latest/download/mad.installer_1.0.0_x64-setup.exe"><b>download for Windows</b></a>
</p>

### manually

1. download the `ipa` from the [latest release](../../releases/latest)
2. sign and install it with sideloadly, altstore, sidestore, feather, esign or your own certificate

the `ipa` in releases is unsigned. with a free apple id the signature lasts 7 days, then it has to be renewed.

## build

you need a mac with xcode. clone with submodules:

```bash
git clone --recursive -j8 https://github.com/yar2slav/Madgram-iOS.git
```

put your `api_id`, `api_hash`, team id and bundle id into `build-system/template_minimal_development_configuration.json` and build:

```bash
python3 build-system/Make/Make.py --overrideXcodeVersion --bazelArguments='--//Telegram:shareExtensionOnly' build --configurationPath build-system/template_minimal_development_configuration.json --xcodeManagedCodesigning --buildNumber=1 --configuration=release_arm64
```

telegram's detailed guide: [docs/building.md](docs/building.md).

## contact

bugs and ideas go to the [channel](https://t.me/+l-wwJloXQ802ZDcy) direct messages. author: [yar2slav](https://t.me/yar2slav).

## credits

[telegram ios](https://github.com/TelegramMessenger/Telegram-iOS). mad is not affiliated with telegram and is not an official client.
