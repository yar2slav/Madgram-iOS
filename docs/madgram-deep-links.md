# Madgram Deep Links

The app registers the `mad` URL scheme. Canonical feature links are:

- `mad://settings` — Madgram feature hub
- `mad://ghost` — Ghost Mode
- `mad://filters` — message filters
- `mad://archive` — local message archive
- `mad://interface` — interface tuning, including tabs, profiles, stories, camera, media, and privacy
- `mad://power-saving` — Madgram feature hub, scrolled by the user to Power Saving
- `mad://premium` — Madgram feature hub, scrolled by the user to Local Premium
- `mad://message-shot` — Madgram feature hub; Message Shot itself requires selected messages
- `mad://forward-without-author` — Madgram feature hub; forwarding requires selected messages

Links may use the `settings` namespace and append a feature-specific path. The current
implementation opens the owning settings screen and intentionally ignores the trailing path, so
links such as `mad://settings/interface/disable-camera` and
`mad://settings/ghost/suppress-read-receipts` remain valid as individual feature links.
