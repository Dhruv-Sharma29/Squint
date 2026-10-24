# Changelog

All notable changes to Squint are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- App icon in Apple's layered format, so macOS 26 and later show it in the native shape rather than inside a grey container. It appears in Finder, Spotlight, System Settings and permission prompts.

## [0.1.0] - 2026-10-24

### Added

- Menu bar app with a global **⌘⇧2** shortcut and the system region-selection UI.
- **Code Mode**: indentation, blank lines and column spacing are preserved; autocorrect is off; closing brackets that Vision skips are restored; `{` misread as `1`, `I`, `l` or `|` is repaired.
- **Plain Mode** with autocorrect and automatic language detection.
- QR code and barcode reading.
- **Read Clipboard Image**.
- `squint://capture` and `squint://clipboard` links, with an optional `?mode=code|plain`.
- `squint` command-line tool and the `squint eval` benchmark harness.
- Homebrew formula that builds from source, with `brew services` support for starting at login.
