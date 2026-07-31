<div align="center">
  <img src="docs/assets/banner.svg" alt="KeySwitch — automatic keyboard layout switching for macOS" width="100%">

  [![Version](https://img.shields.io/badge/version-3.0.1-6D5DFB)](CHANGELOG.md)
  [![Downloads](https://img.shields.io/github/downloads/Andrles/KeySwitch/total?label=downloads&logo=github&color=2563EB)](https://github.com/Andrles/KeySwitch/releases)

  **A native Russian ↔ English keyboard layout assistant for macOS.**

  [Русский](README.md) · [Download](https://github.com/Andrles/KeySwitch/releases/latest) · [Features](#features) · [Installation](#installation) · [Troubleshooting](#troubleshooting)
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
- Shows the corrected language as an animated `A/Я` menu bar icon.
- Supports System, Light, and Dark appearances in a modern macOS design.
- Checks GitHub Releases for new versions.
- Never sends typed text to a remote service.

## Installation

> [Download the latest KeySwitch release](https://github.com/Andrles/KeySwitch/releases/latest)

### Terminal

```sh
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Andrles/KeySwitch/main/scripts/install.sh)"
```

The command downloads `KeySwitch.pkg` from the latest published GitHub Release,
asks for an administrator password to install it into `/Applications`, and
launches the app. You can [review the script](scripts/install.sh) before running it.

### Manual installation

1. Download the latest `KeySwitch-*.pkg` or `KeySwitch-*.zip` from **Releases**.
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
