# Development

- [Getting started](#getting-started)
- [Conventions](#conventions)
- [Testing](#testing)
- [App Intents metadata](#app-intents-metadata)
- [Screen Recording permission during development](#screen-recording-permission-during-development)
- [Releasing a new version](#releasing-a-new-version)
- [Testing the formula before a release](#testing-the-formula-before-a-release)

## Getting started

```sh
swift build                    # debug build
swift run Squint               # start the menu bar app from Terminal
swift run Squint --help        # the CLI
swift test                     # unit tests
./bundle.sh                    # release build → build/Squint.app (ad-hoc signed)
open build/Squint.app
```

The app needs no Xcode project. Swift Package Manager builds it, and `bundle.sh` wraps the binary in an app bundle with the `Info.plist` (bundle ID, `LSUIElement`, the `squint://` scheme). It also copies in the precompiled app icon.

### App icon

| File | Role |
|---|---|
| `Assets/AppIcon.icon` | **Source.** Apple's layered icon format; open it in Icon Composer (bundled with Xcode 26+). The artwork is a full-bleed 1024 × 1024 square, and macOS applies the rounded shape itself. |
| `Assets/Assets.car` | Compiled icon used by macOS 26 and later |
| `Assets/AppIcon.icns` | Compiled fallback for macOS 14–15 |
| `Assets/AppIcon.png` | Preview used in the README |

The compiled files are committed so that `bundle.sh`, and Homebrew users who only have the Command Line Tools, don't need Xcode. After editing the source, recompile with:

```sh
xcrun actool Assets/AppIcon.icon --compile Assets --platform macosx \
  --minimum-deployment-target 14.0 --app-icon AppIcon --output-partial-info-plist "$(mktemp)"
```

Why this format: macOS 26 and later put old-style `.icns` icons, and plain asset-catalog icons, inside a grey rounded square. Only layered `.icon` artwork gets the native shape. Both alternatives were tested and both got the grey container.

The menu bar shows a monochrome version of the logo: an eye with `</>` inside a viewfinder. It is drawn in code in `App/MenuBarIcon.swift` as a template image, so like an SF Symbol it stays sharp at every scale and follows light and dark menu bars.

## Conventions

- **Swift 6 language mode** with strict concurrency. The build must have no warnings.
- **One type per file**, in folders organised by feature (`App/`, `App/Intents/`, `Capture/`, `OCR/`, `Eval/`).
- **State:** `@MainActor @Observable` classes, not `ObservableObject`.
- **No third-party dependencies** without discussion. The whole app runs on system frameworks.
- **Deliberate simplifications** carry a `ponytail:` comment naming the limit and how to improve on it. Search for them before changing an algorithm:
  ```sh
  grep -rn "ponytail:" Sources
  ```
- **Accuracy changes need evidence.** Develop against the dev set (`python3 bench/make_dataset.py --dev`), never the test set. When the change is done, run the test set once and include before and after results in the pull request. See [`bench/`](../bench/README.md).

## Testing

71 tests in 14 suites, written with Swift Testing. CI runs them on every push ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml)), together with a build and a signed bundle.

| Suite | Covers |
|---|---|
| `RecognizerTests` | Indent snapping; restoring brackets and docstring quotes Vision skipped; `{` and `]` misreads; a misread can't change later closers; line-number gutter removal, and code that merely starts with numbers is left alone; missing vs unreadable files; reading a QR code; metrics |
| `CaptureModelTests` | **End-to-end journeys** through Vision and the code-layout pass, with a rendered screenshot in place of the selection overlay and a private pasteboard: capture, cancel, missing permission (the overlay never opens), a second press while busy, clipboard images, an empty clipboard, `squint://` routing |
| `AppIntentsMetadataTests` | The committed `Metadata.appintents` lists exactly the intents in `Sources/Squint/App/Intents` |
| `ShortcutTests` | Recording a shortcut from a key press, rejecting plain keys, named keys, display order, encoding |
| `PreferencesTests` | Defaults for new users; every setting survives a relaunch |
| `LinkCommandTests` | `squint://` link parsing, including case and unknown links |
| `ClipboardImageTests` | Image data, image files copied in Finder (regression: Squint used to read the file's icon), and text-only clipboards. Uses a private pasteboard, so tests never touch the real clipboard. |

The first test that calls Vision in a fresh process can take about 25 seconds while macOS compiles the model. Later runs take milliseconds.

Not covered by automated tests: the system's own selection overlay and Screen Recording prompt, App Intents running inside Spotlight (the framework won't resolve their dependencies outside its own perform flow), and clicking through the Settings window. Check those by hand before a release.

For end-to-end accuracy, use `squint eval` on a benchmark folder; see [Evaluation](evaluation.md).

## README media

`docs/images/comparison.png` and `docs/images/demo.gif` are generated from **real Squint output**, never drawn by hand. Regenerate them after any change to recognition:

```sh
swift build -c release
swiftc Sources/Squint/App/MenuBarIcon.swift scripts/ReadmeMedia/main.swift -o .build/readme-media
.build/readme-media
```

The script renders a code frame, runs the release `Squint` binary on it in both modes, scores the results with `squint eval`, and draws the images from those outputs. The demo's windows and selection animation are illustrations of the flow, but the pasted text is exactly what Squint produced.

## App Intents metadata

Spotlight, Siri and Shortcuts find Squint's actions through `Assets/Metadata.appintents`. Xcode generates this only for app targets, not for Swift-package executables, so `scripts/app-intents-metadata.sh` runs the same two steps directly: the compiler extracts constant values from the sources, then Apple's `appintentsmetadataprocessor` exports the metadata. Run it whenever anything in `Sources/Squint/App/Intents` changes, and commit the result:

```sh
scripts/app-intents-metadata.sh   # needs Xcode, not only the Command Line Tools
```

The output is committed so Homebrew builds without Xcode still include it.

## Screen Recording permission during development

Every build gets a new ad-hoc signature, so macOS treats it as a new app and may stop honouring an earlier Screen Recording grant. If captures come back empty after a rebuild, run:

```sh
tccutil reset ScreenCapture io.github.dhruv-sharma29.squint
```

Then capture again and re-grant the permission.

## Releasing a new version

1. Update the version in `bundle.sh` (`CFBundleShortVersionString`, and increment `CFBundleVersion`) and add an entry to [CHANGELOG.md](../CHANGELOG.md).
2. Commit, tag and push:
   ```sh
   git tag v0.2.0
   git push origin main v0.2.0
   ```
3. Compute the checksum of GitHub's source tarball for the tag:
   ```sh
   curl -sL https://github.com/Dhruv-Sharma29/Squint/archive/refs/tags/v0.2.0.tar.gz | shasum -a 256
   ```
4. Update `url` and `sha256` in [`Formula/squint.rb`](../Formula/squint.rb), then commit and push.
5. Verify as a user would:
   ```sh
   brew update
   brew upgrade squint            # or: brew install dhruv-sharma29/tap/squint
   brew test squint
   brew audit --strict squint
   ```

## Testing the formula before a release

You can test a formula change without publishing anything by installing from a temporary local tap that points at a local tarball:

```sh
# 1. Package the working tree the same way GitHub would.
mkdir -p /tmp/squint-pkg/Squint-0.0.0
rsync -a --exclude .build --exclude build ./ /tmp/squint-pkg/Squint-0.0.0/
tar -czf /tmp/squint-pkg/squint.tar.gz -C /tmp/squint-pkg Squint-0.0.0
SHA=$(shasum -a 256 /tmp/squint-pkg/squint.tar.gz | cut -d' ' -f1)

# 2. Create a throwaway tap containing a copy of the formula that points at it.
brew tap-new local/squint-test --no-git
TAP="$(brew --repository)/Library/Taps/local/homebrew-squint-test"
sed -e "s|^  url .*|  url \"file:///tmp/squint-pkg/squint.tar.gz\"|" \
    -e "s|^  sha256 .*|  sha256 \"$SHA\"|" Formula/squint.rb > "$TAP/Formula/squint.rb"

# 3. Install and test, then clean up.
brew install --build-from-source local/squint-test/squint
brew test local/squint-test/squint
brew uninstall squint && brew untap local/squint-test
```
