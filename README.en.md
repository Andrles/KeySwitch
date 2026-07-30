<div align="center">
  <img src="docs/assets/banner.svg" alt="KeySwitch — automatic keyboard layout switching for macOS" width="100%">

  **A native, offline Russian ↔ English keyboard layout assistant for macOS.**

  [Русский](README.md) · [Features](#features) · [Installation](#installation) · [Build](#build-from-source)
</div>

## Features

- Detects Russian and English words automatically.
- Fixes text typed with the wrong layout and synchronizes the macOS input source.
- Uses built-in macOS dictionaries locally.
- Offers spelling checks and optional correction of obvious typos.
- Converts the current word with a double press of Shift.
- Adds the currently active app to exclusions directly from the menu bar.
- Runs in the menu bar without keeping a permanent Dock window.
- Never sends typed text to a remote service.

## Installation

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

Local builds use an ad-hoc signature and are not notarized. Public releases should be signed with an Apple Developer ID and notarized.

## Privacy

All text processing happens locally. KeySwitch does not make network requests, store typing history, or send words to third-party services. See [PRIVACY.md](PRIVACY.md).

## Requirements

- macOS 13 Ventura or later;
- Apple Silicon or Intel Mac;
- Accessibility permission.

## Build from source

Install Xcode Command Line Tools, then run:

```sh
git clone <YOUR-REPOSITORY-URL>
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
