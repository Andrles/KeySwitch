<div align="center">
  <img src="docs/assets/banner.svg" alt="KeySwitch — automatic keyboard layout switching for macOS" width="100%">

  [![Version](https://img.shields.io/badge/version-3.2.0-6D5DFB)](CHANGELOG.md)
  [![Downloads](https://img.shields.io/github/downloads/Andrles/KeySwitch/total?label=downloads&logo=github&color=2563EB)](https://github.com/Andrles/KeySwitch/releases)

  **A native Russian ↔ English keyboard layout assistant for macOS.**

  [Русский](README.md) · [Terminal install](#terminal) · [Download](https://github.com/Andrles/KeySwitch/releases/latest) · [Features](#features) · [Installation](#installation) · [Troubleshooting](#troubleshooting)
</div>

## Features

- Detects Russian and English words automatically.
- Fixes text typed with the wrong layout and synchronizes the macOS input source.
- Uses built-in macOS dictionaries locally.
- Recognizes automotive brands and model identifiers such as `BMW X3`, `Audi Q7`, and `Mazda CX-5`.
- Offers spelling checks and optional correction of obvious typos.
- Converts the current word with a double press of Shift.
- Adds the currently active app to exclusions directly from the menu bar.
- Runs in the menu bar without keeping a permanent Dock window.
- Shows distinct menu-bar symbols for ready, paused, and permission/error states.
- Supports System, Light, and Dark appearances in a modern macOS design.
- Checks GitHub Releases for new versions.
- Never sends typed text to a remote service.

## Installation

> [Install via Terminal](#terminal) · [Download the installer](https://github.com/Andrles/KeySwitch/releases/latest)

### Terminal

```sh
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Andrles/KeySwitch/main/scripts/install.sh)"
```

The command selects a `.pkg` asset from the latest published GitHub Release,
asks for an administrator password to install it into `/Applications`, and
launches the app. The previous version is replaced. After the new app passes verification, duplicate KeySwitch bundles (such as “KeySwitch 2”) are removed from `/Applications`. Preferences are preserved. Ad-hoc signed updates may require Accessibility reauthorization; unrelated apps and symbolic links are left intact.
[Review the installation script](https://github.com/Andrles/KeySwitch/blob/main/scripts/install.sh) before running it.

### Manual installation

1. Download the latest `KeySwitch-*.pkg` or `KeySwitch-*.zip` from **Releases**. Open the PKG to replace the previous version and remove duplicate copies from `/Applications`; ZIP installation requires manual replacement.
2. Move KeySwitch to `/Applications` when using the ZIP archive.
3. Launch the app.
4. Grant access in **System Settings → Privacy & Security → Accessibility**.

## Privacy

All text processing happens locally. KeySwitch does not store typing history or
send words to third-party services. Its only optional network request checks the
latest GitHub Release and never includes typed text. See [PRIVACY.md](PRIVACY.md).

## Requirements

| Component | Requirement |
|---|---|
| macOS | 13 Ventura or later |
| Processor | Apple Silicon or Intel |
| Permission | Accessibility |
| Internet connection | Optional; used only to check for updates |

## Troubleshooting

### KeySwitch is running but does not correct text

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Make sure KeySwitch is enabled.
3. If it is already enabled, turn the permission off and on again, then restart KeySwitch.
4. Make sure the active app is not in the exclusions list.

### macOS reports that the app is from an unidentified developer

Open **System Settings → Privacy & Security** and confirm that you want to launch
KeySwitch.

### Temporarily disable automatic switching

Open the KeySwitch menu bar icon and choose **Pause automatic switching**.

If the problem continues, [open an issue](https://github.com/Andrles/KeySwitch/issues/new)
and include the macOS version, KeySwitch version, original word, and expected result.

## Build from source

Install Xcode Command Line Tools, then run:

```sh
git clone https://github.com/Andrles/KeySwitch.git
cd KeySwitch
./scripts/test.sh
./scripts/build.sh
./scripts/package.sh
```

Build artifacts are written to `build/`. The application is universal (`arm64` and `x86_64`).

## Contributing

Bug reports and focused pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Source available, all rights reserved. See [LICENSE.md](LICENSE.md).

## Editing safety and development scope

KeySwitch verifies the focused field, caret and original text before replacement. Secure fields and editors without sufficient Accessibility context are skipped. Double Shift converts the current word; immediately after a correction it restores the original before new input, context changes or 15 seconds. In suggestion mode, double Shift accepts the current suggestion; Escape dismisses it. The General settings example checks the engine only.

Current work focuses on the macOS utility. Voice, AI, Windows and Linux are deferred in [ROADMAP.md](ROADMAP.md).

## Menu bar and Dock

KeySwitch defaults to menu-bar-only mode, including while settings are open.
Open the window through the keyboard icon in the menu bar. The appearance/startup
section contains a persistent menu-bar-only toggle; turn it off to show the Dock icon.
Closing the window keeps the app running. Quit through the KeySwitch menu.

### Safer corrections in 3.1.1

Correct vocabulary, known names, technical terms and identifiers are protected before conversion. Layout conversion preserves letters and case. Automatic spelling uses curated common typo rules; ambiguous dictionary guesses remain suggestions accepted with double Shift. Quotes/brackets are preserved and Tab completes a word. Address/path/code separators are conservative. Mixed identifiers, language collisions and unsupported foreign characters may require manual conversion. The primary supported layout pair is English QWERTY / Russian ЙЦУКЕН.

## Manual actions and personal dictionary (3.2.1)

The “Ручные действия” menu converts the current word or selection, applies a suggestion, undoes the last automatic correction, and changes selection case. Automatic undo expires after further input, a field change, or 15 seconds. Record a shortcut with Command or Control in the dedicated “Ручные действия” section. Delete clears it; Escape cancels recording. New shortcuts are disabled by default. Known system shortcuts, including Control + Option + U (VoiceOver), and conflicts between KeySwitch commands are rejected. Conflicts with other apps are not detected.

New settings use double Shift only for layout conversion. Existing explicit preferences are preserved. Turn off “Двойной Shift — только раскладка” to restore the legacy contextual actions; suggestions can also be accepted with their button or a separate command.

The dedicated “Мой словарь” section provides searchable rows for correct words, ignored words and replacement pairs. Save rules explicitly; invalid drafts remain visible and cannot overwrite committed data. Words are limited to 64 characters. Numeric-only or mixed Russian/English replacement values are rejected before saving. Older ignored entries remain export/import compatible. Learned words help detect layout mistakes. Explicit pairs apply at word boundaries while corrections are enabled, independently of spelling mode; ignored words take priority. JSON export/import merges words; incoming pairs replace matching keys.

Selection layout conversion assumes one source layout throughout the phrase and preserves whitespace and outer punctuation. Mixed-language selections may produce unwanted results. Editing requires writable AXSelectedText; the clipboard is not used. Use the editor's own undo for manual selection edits.

Manual command failures show a brief explanation without taking focus from the editor.

## Application rules and snippets (local 3.3.0)

Select an application in the exclusions section to independently control automatic layout correction, spelling and snippets. Partial profiles leave manual commands available; legacy full exclusions block them too. Removing the rule restores global defaults.

Add an “Abbreviation → phrase” rule in the personal dictionary, save it and enable expansion after Space. Triggers contain one word up to 64 characters; phrases contain one line up to 256 characters and 512 UTF-16 units. Enter, Tab and punctuation do not expand snippets. Expansion preserves the input source. Ignored words take precedence. Snippets are included in dictionary transfer; this version reads legacy files.

Undo uses the existing verified-field guard and expires after new input, a context change or 15 seconds. Use the manual undo command when double Shift is configured for layout only. Physical TextEdit expansion, trigger restoration and selected-text layout conversion were confirmed. Local PKG/ZIP payloads and startup were verified; full installation and publication remain pending.
