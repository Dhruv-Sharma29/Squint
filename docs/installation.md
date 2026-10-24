# Installation

- [Requirements](#requirements)
- [Install with Homebrew](#install-with-homebrew-recommended)
- [Build from source](#build-from-source)
- [Permissions](#permissions)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)

## Requirements

| | |
|---|---|
| macOS | 14 Sonoma or later |
| Toolchain | Xcode 16+ or Command Line Tools with Swift 6.0+ (`xcode-select --install`) |
| Homebrew | Any current version |

> Squint has been built and tested with Swift 6.4 on macOS 27 (Apple silicon). Older toolchains and Intel Macs are expected to work but are not yet tested.

## Install with Homebrew (recommended)

```sh
brew tap dhruv-sharma29/squint https://github.com/Dhruv-Sharma29/Squint
brew install dhruv-sharma29/squint/squint
```

Homebrew downloads the source of the tagged release and builds it on your Mac, which takes about 20 seconds. This installs:

| Item | Location |
|---|---|
| The app | `$(brew --prefix)/opt/squint/Squint.app` |
| The `squint` command | `$(brew --prefix)/bin/squint` |

**Start Squint now and at every login:**

```sh
brew services start squint
```

**Or open it once:**

```sh
open "$(brew --prefix)/opt/squint/Squint.app"
```

Squint lives in the menu bar (look for the viewfinder icon) and has no Dock icon.

### Why build from source instead of a cask?

Homebrew casks install prebuilt apps. Since Homebrew 5, casks are expected to be signed with an Apple Developer ID and notarized, and the `--no-quarantine` escape hatch is deprecated. An unsigned prebuilt app would be blocked by Gatekeeper on first launch. An app built locally from source is never quarantined, so a formula installs cleanly without a paid developer account. If Squint later ships signed builds, a cask will be added alongside the formula.

## Build from source

```sh
git clone https://github.com/Dhruv-Sharma29/Squint.git
cd Squint
./bundle.sh                 # builds build/Squint.app
open build/Squint.app
```

To use the command-line tool from a source build, run `build/Squint.app/Contents/MacOS/Squint --help`, or symlink it onto your `PATH`.

## Permissions

Squint asks for one permission.

| Permission | Why | Where to grant it |
|---|---|---|
| Screen Recording | To capture the region you select | System Settings › Privacy & Security › Screen Recording |

The first time you capture, macOS asks for permission. Grant it, then capture again. Reading clipboard images, links and the command-line tool need no permission.

## Updating

```sh
brew update
brew upgrade squint
brew services restart squint   # if you use the service
```

Each build has a new ad-hoc code signature, so macOS may ask for Screen Recording permission again after an update.

## Uninstalling

```sh
brew services stop squint
brew uninstall squint
brew untap dhruv-sharma29/squint
tccutil reset ScreenCapture io.github.dhruv-sharma29.squint   # optional: forget the permission
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| Permission is granted, but captures come back empty or show only the wallpaper | The permission belongs to an older build. Remove Squint from the Screen Recording list (or run the `tccutil` command above), then capture again. |
| The menu says **⌘⇧2 is in use by another app** | Another app (for example TextSniper) owns that shortcut. Capture from the menu, or bind a `squint://capture` link to any shortcut; see [Usage](usage.md#links-and-automation). |
| `squint://` links do nothing | macOS registers the link scheme when the app first launches. Open Squint once, then try again. |
| The first capture works but later ones fail with a Vision error | The TRex project reported a macOS 27 regression in Apple's legacy text-recognition API. It could not be reproduced on macOS 27.0.1 (24 recognitions in one process). If you hit it, please open an issue with your exact macOS version. |
| `brew install` fails while compiling | Check that `swift --version` reports 6.0 or later. If it doesn't, install current Command Line Tools with `xcode-select --install`. |
