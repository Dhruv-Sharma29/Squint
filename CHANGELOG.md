# Changelog

All notable changes to Squint are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-10-24

### Added

- **Settings window** (⌘, from the menu): record your own global shortcut, open at login, choose the Plain Mode recognition language, and play a sound when text is copied. All settings, including Code Mode, persist across launches.
- **Spotlight, Siri and Shortcuts actions:** Capture Text, Capture Code, Capture Plain Text and Read Clipboard Image. Type "Squint" in Spotlight. In Shortcuts, each action returns the captured text. macOS only runs them for apps signed with an Apple Team ID: `SQUINT_SIGN_IDENTITY="Apple Development" ./bundle.sh` signs with a free Apple ID; Homebrew builds are ad-hoc and don't get them.
- **Editor line numbers are removed** in Code Mode, even when Vision reads only two of them, and lone docstring `"""` lines Vision skips are restored.
- More code-only misreads repaired: `{` read as `f` or `t`, a lone `}` read as `8`, `)` or `]`, template-literal backticks read as quotes, and `||` read as `|l`.
- **VoiceOver announces** when text is copied and when a capture fails.
- **Benchmark** ([`bench/`](bench/README.md)): development, test, renamed-identifier and fresh held-out sets of real-code screenshots, comparing Squint with Apple Vision, Live Text, TRex and an AI chat assistant. Results in [Evaluation](docs/evaluation.md).
- **End-to-end tests** of the capture and clipboard journeys through the real recognition pipeline (37 tests in 7 suites).
- **Continuous integration:** every push is built, tested and bundled on GitHub Actions.
- App icon in Apple's layered format, so macOS 26 and later show it in the native shape rather than inside a grey container.
- Menu bar icon based on the logo, drawn as a template image that follows light and dark menu bars.
- Product README with a demo and a before/after comparison generated from real output.
- [Roadmap](docs/roadmap.md) with status, a phased plan and success metrics.
- [Website](https://dhruv-sharma29.github.io/Squint/), deployed to GitHub Pages.

### Changed

- Character error rate on the benchmark's test set fell from **7.1% to 3.2%** (renamed identifiers: 7.4% to 3.4%; fresh held-out set: 2.4%).
- Code Mode's menu tick now lines up with the menu's icons.
- Builds are signed with the hardened runtime.
- The Screen Recording message says to reopen Squint, which macOS requires before a new permission takes effect.

### Fixed

- Long messages, such as the Screen Recording one, stretched the menu across the screen. Missing permission now shows a short message and an **Open Screen Recording Settings…** button.
- A missing image file is reported as missing, not as being in the wrong format.
- **Read Clipboard Image** read the *icon* of an image file copied in Finder instead of the image.
- Pressing the shortcut twice quickly opened two selection overlays.
- The Code Mode setting was forgotten on every launch.
- `]` misread as `l` (for example `item[keyl;`) is repaired, and a misread bracket no longer turns restored `}` lines into `]`.

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
