# How it works

- [Pipeline](#pipeline)
- [Source layout](#source-layout)
- [The code-layout pass](#the-code-layout-pass)
- [Concurrency](#concurrency)
- [Design decisions](#design-decisions)
- [Security, privacy, performance and accessibility](#security-privacy-performance-and-accessibility)
- [Known limitations](#known-limitations)

## Pipeline

```text
 shortcut · menu · Spotlight ·          Read Clipboard Image ·
 Shortcuts · squint://capture           squint://clipboard
            │                                     │
   screencapture -i (system UI)     image file copied in Finder,
            │                       else clipboard PNG/TIFF
            └──────────────┬──────────────────────┘
                           ▼
                temporary image file
                           │
     Vision: VNRecognizeTextRequest + VNDetectBarcodesRequest
                           │
           barcode found? ─┼─ yes ─► barcode payloads
                           │ no
                           ▼
       find emoji; if any, draw `##` over them, run Vision
       again, and swap each `##` back for its emoji
                           │
                           ▼
                group text boxes into rows
                           │
          Plain Mode ──────┼────── Code Mode
     join rows with spaces │   remove line-number gutter
                           │   lay rows on a line grid
                           │   ─► Slots ─► render
                           ▼
       clipboard  ·  temporary image deleted
```

Everything runs on device. Squint makes no network requests.

## Source layout

Folders are organised by feature, with one type per file.

| Path | Responsibility |
|---|---|
| `Sources/Squint/main.swift` | Entry point: no arguments starts the app, any arguments run the CLI |
| `App/SquintApp.swift` | SwiftUI `MenuBarExtra` and `Settings` scenes |
| `App/AppDelegate.swift` | Owns the model, receives `squint://` links, and shares the model with App Intents |
| `App/CaptureModel.swift` | `@MainActor @Observable` state and the capture → recognize → copy flow; one capture at a time |
| `App/Preferences.swift` | Settings saved to `UserDefaults` |
| `App/Shortcut.swift` | A global shortcut: Carbon key code and modifiers, display name, menu key equivalent |
| `App/ShortcutRecorder.swift` | Records a new shortcut in Settings |
| `App/SettingsView.swift` | The Settings window's content |
| `App/SettingsPanel.swift` | The Settings window itself, opened in front by Squint (SwiftUI's `Settings` scene opened behind other apps) |
| `App/LaunchAtLogin.swift` | Open at login through `SMAppService` |
| `App/LinkCommand.swift` | Parses `squint://` links |
| `App/MenuContent.swift` | Menu items |
| `App/MenuBarIcon.swift` | The logo as a monochrome menu bar template image, drawn in code |
| `App/HotKey.swift` | The global shortcut through Carbon `RegisterEventHotKey` |
| `App/Intents/` | Four App Intents and the `AppShortcutsProvider` behind Spotlight, Siri and Shortcuts |
| `Capture/ScreenCapture.swift` | Runs `screencapture -i` and returns the captured image file |
| `Capture/ClipboardImage.swift` | Copies a clipboard image, or an image file copied in Finder, to a temporary file |
| `OCR/Recognizer.swift` | Vision requests, row grouping, line-number removal and the code-layout pass |
| `OCR/TextBox.swift` | One run of recognized text and its bounds |
| `OCR/Slot.swift` | One output row: text, unreadable ink, or blank |
| `OCR/InkMap.swift` | Pixel access used to find glyphs Vision skipped |
| `OCR/EmojiFinder.swift` | Finds colour emoji, which Vision can't read, and puts them back into the text |
| `OCR/EmojiGlyphs.swift` | Every emoji rendered in Apple Color Emoji, for comparison |
| `Eval/Metrics.swift` | Edit distance, character error rate, exact-line rate |
| `Eval/CLI.swift` | `squint <image>` and `squint eval` |
| `Formula/squint.rb` | Homebrew formula |
| `bundle.sh` | Assembles and ad-hoc signs `Squint.app` |
| `Assets/` | App icon (the `AppIcon.icon` source plus compiled `Assets.car` and `AppIcon.icns`) and App Intents metadata (`Metadata.appintents`); see [Development](development.md#app-icon) |
| `scripts/` | Regenerates App Intents metadata and the README media |
| `bench/` | The accuracy benchmark; see [Evaluation](evaluation.md) |
| `.github/workflows/ci.yml` | Builds, tests and bundles on every push |

## The code-layout pass

Vision returns a list of text boxes. Each box is one recognized string with a bounding box in normalized coordinates, with the origin at the bottom-left. Code Mode turns those boxes back into source code in seven steps.

1. **Group into rows.** Boxes whose vertical centres are within half a box height of each other form one row, ordered left to right. If Vision merged an editor line number with the code after it ("12  return x"), the number is split off using the candidate's own character geometry.
2. **Remove a line-number gutter.** At least two rows must start with an integer; those integers must mostly increase and end at about the same x (a right-aligned column); and on at least 80% of rows the code must start clearly to the right. Vision often reads only 1–3 of 11 numbers, so the empty column is the stronger evidence. The column is removed, including misread numbers such as `l7` and misread numbers merged with code (`4O  return`). Line spacing is measured *before* removal, because rows that held only a number still mark where a line is.
3. **Estimate character width.** For each box with at least 4 characters, divide its width by its character count. The median is the character width. This assumes a monospaced font.
4. **Estimate line pitch.** The median vertical distance between consecutive rows. A gap of *n* pitches between two rows means *n − 1* rows are missing.
5. **Check missing rows for ink.** For each missing row, `InkMap` scans a band 0.4 × the median text height either side of where the row should be. It looks for pixels that differ from the background by more than 64/255 in any channel. The same check runs below the last recognized row. A row with ink becomes `.ink`, meaning there is a glyph Vision didn't read. A row without ink becomes `.blank`. With a gutter, the scan starts right of it, so line numbers never count as ink.
6. **Compute indentation.** Each row's left edge, relative to the leftmost row, is divided by the character width and rounded to whole columns. The smallest non-zero indent is taken as the indent step, and every indent is snapped to a multiple of it. This absorbs measurement error at deeper nesting levels.
7. **Rebuild spacing within a row.** The gap between neighbouring boxes on one row becomes the matching number of spaces, so aligned comments keep their alignment.
8. **Render.** Walk the slots top to bottom, keeping a stack of open brackets (`{`, `(`, `[`):
   - A text row ending in ` 1`, ` I`, ` l`, ` |`, ` f` or ` t` that is followed by a more-indented row gets that character replaced by `{`. These are Vision's common brace misreads.
   - A lone `8`, `)` or `]` while the innermost open bracket is `{` becomes `}`.
   - A `'`-quoted string containing `${` gets backticks (a template literal), and `|l`, `l|`, `|I` or `I|` between spaces becomes `||`.
   - On a row with more `[` than `]`, an `l` right after `[name` and before `;`, `.`, `)`, `,` or the line end becomes `]` (`item[keyl;` → `item[key];`).
   - A `(` or `[` still open in the middle of a row is treated as a misread and dropped from the stack. Only `{` and an opener at the very end of a row (a multi-line call or literal) stay open, so one misread can't change which closers are restored further down.
   - An `.ink` row becomes the closer for the innermost open bracket, at its measured indent.
   - An `.ink` row right after a Python `def` or `class` line opens a docstring with `"""`, and the next `.ink` row closes it. Vision skips a lone `"""` just as it skips a lone `}`.
   - Trailing blank rows are dropped.

### Evidence behind these steps

| Observation | How it was checked |
|---|---|
| Vision returns only one candidate per line in `.accurate` mode, so there are no alternatives to re-rank | Requested `topCandidates(5)`; got 1 |
| Vision does not read a lone `}` | The full image, a cropped row, and a row upscaled 3× with padding all returned nothing |
| Autocorrect damages code | Plain Mode output turned `fib(n):` into `fib (n) :` |
| `{` at the end of a line is read as `1` | Seen in `for (const x of arr) {` |
| `]` is read as `l`, which used to turn restored `}` lines into `]` | Seen in `item[key];` and `groups[k].push(...)`; now covered by unit tests |
| Line numbers were the largest error source | On the benchmark's test set, error rate on line-numbered images went from 13.9% to 6.1% after gutter removal; images without line numbers were unchanged. Developed on a separate dev set. |

## Concurrency

The package compiles in Swift 6 language mode with strict concurrency checking.

- `CaptureModel` is `@MainActor @Observable`. The UI reads it directly.
- Recognition runs one image at a time on `Recognizer`'s own serial queue, and callers await it through a continuation. Vision's `perform` blocks its thread while Vision's own work runs on Swift's cooperative thread pool. Called from that pool with as many images at once as it has threads, every thread blocks and nothing is left to run Vision's work: a deadlock, which hit CI's three-core runners. `recognizesMoreImagesAtOnceThanThePoolHasThreads` guards it.
- `ScreenCapture` waits for `screencapture` through a continuation resumed by the process's termination handler, so no thread is blocked during the selection.
- The Carbon hotkey callback runs on the main thread and enters the main actor with `MainActor.assumeIsolated`.

## Design decisions

| Decision | Alternative | Why |
|---|---|---|
| `screencapture -i` for selection | A custom ScreenCaptureKit overlay | Users already know the system UI, and it needs no overlay code to maintain. TRex makes the same choice. |
| Carbon `RegisterEventHotKey` | The `KeyboardShortcuts` package | No third-party dependencies, and no Accessibility permission needed |
| `VNRecognizeTextRequest` | The Swift `RecognizeTextRequest` API (macOS 15+) | Keeps macOS 14 support with a synchronous API usable from the CLI. To revisit if the reported macOS 27 regression shows up. |
| Repairs based on pixels and bracket balance | An LLM post-processor | Deterministic, offline, explainable and fast. An LLM would need to beat this on a held-out benchmark before being added. |
| One executable for both app and CLI | Separate targets | One binary to build, sign and install; the CLI is also the evaluation harness. |
| Homebrew formula built from source | A cask with a prebuilt app | Avoids Gatekeeper quarantine without a paid Developer ID; see [Installation](installation.md#why-build-from-source-instead-of-a-cask). |

Deliberate simplifications are marked in the source with `ponytail:` comments. Each comment names the limit of the simplification and how to improve on it.

## Security, privacy, performance and accessibility

Reviewed for 0.2.0. Each row says how it was checked.

### Security and privacy

| Area | State | How it was checked |
|---|---|---|
| Network | **None.** Vision runs on device, and the source contains no networking API. | Source scan; OCR with all network access denied by the OS sandbox (`sandbox-exec … (deny network*)`) gives identical output. |
| Screenshots | Written to the per-user temporary folder under a random name and **deleted right after recognition**, including on failure. Image files copied in Finder are read from a copy; the original is never touched. | `CaptureModelTests`, `ClipboardImageTests` |
| Permissions | Screen Recording only, requested on first capture. Without it, the selection overlay never opens and the menu explains the fix. | `CaptureModelTests` |
| `squint://` links | Two commands (capture, read the clipboard image); anything else is rejected and reported. Any app can open a link, but the worst it can do is start a selection or replace the clipboard with the text of the image already on it, and browsers ask before opening custom links. | `LinkCommandTests`, `CaptureModelTests` |
| Code signing | Signed with the **hardened runtime**, which blocks code injection and unsigned libraries. Ad-hoc by default; `SQUINT_SIGN_IDENTITY` signs with a real identity. App Intents need a Team ID: for ad-hoc builds, `linkd` logs `Rejecting invalid client due to requiresValidatedBundle`. Not notarized: distribution signing needs a paid Apple account. Homebrew builds from source, so Gatekeeper doesn't apply. | `codesign -dv`: `flags=0x10002(adhoc,runtime)` ad-hoc, `TeamIdentifier` set when signed; `linkd` logs show 0 rejections for the signed build |
| Sandbox | Not sandboxed. Squint launches the system's `screencapture` tool and writes temporary files; App Sandbox would need a different capture method (ScreenCaptureKit) and entitlements. A trade-off for a Homebrew app, required for an App Store build. | Design decision |
| Dependencies | **No third-party packages.** CI pins `actions/checkout` to a commit. | `Package.swift`, `.github/workflows/ci.yml` |
| Secrets | None in the repository or the app. | Source scan |

### Performance

Measured on Apple silicon, macOS 27.0.1.

| Measurement | Result |
|---|---|
| Recognition per capture in a running process (benchmark) | 0.14 s on average |
| A one-off `squint` run, including start-up | median 0.43 s, 95th percentile 0.48 s |
| Typical capture (code region), one-off run | peak memory footprint about 120 MB (0.2.0: about 90 MB). Most of the difference is emoji support: drawing every emoji once for comparison, and keeping them (7.5 MB). |
| Worst case: a full 5K-display capture (5120 × 2549) | 0.27 s, 231 MB peak, released afterwards. `InkMap` holds a full-colour copy of the image. |
| Menu bar app at idle | 75 MB resident, 0% CPU, 3 threads |
| Repeated recognitions in one process | 80 in a row with identical accuracy to separate processes: no sign of the macOS 27 Vision regression TRex reported |

### Accessibility

- Menus, Settings and the shortcut recorder use standard controls with text labels. The menu bar icon and the Code Mode item have VoiceOver labels and values.
- Copies and failures are announced to VoiceOver, so the icon change is never the only feedback.
- Everything works from the keyboard: the global shortcut, menu key equivalents, Spotlight and Shortcuts.
- No animations, so Reduce Motion needs no special handling.
- Settings renders correctly in light and dark appearance (checked by rendering the real view off-screen).

## Known limitations

- **Proportional fonts:** indentation and spacing assume monospaced text.
- **Continuation lines** aligned to an opening parenthesis are snapped to the nearest indent step.
- **Brackets inside strings and comments** are counted as code when deciding which closer to restore.
- **Combined closers** such as `});` are restored as a bare `}`.
- **Busy backgrounds:** ink detection uses the top-left pixel as the background colour, which suits flat editor themes but not gradients or photos.
- **Mixed selections:** if a selection contains a QR code, its contents replace the text.
- **Runs of spaces inside one Vision box** collapse to a single space, for example two spaces before an inline comment.
- **Line numbers** are removed only when they form a right-aligned column of increasing numbers on at least half the rows. Left-aligned or sparse gutters are kept.
- **Docstrings:** only a lone `"""` right after a `def` or `class` line is restored; other lone quotes come back as blank lines.
- **Emoji:** about three in four are found (half of those under 20 px), only in Apple's emoji art, without skin-tone or multi-person variants, and grey or black ones (🌑, ⚫) are hard to tell from text. In proportional fonts, Vision may add a space beside an emoji that touches a quote. See [Evaluation](evaluation.md#emoji).
- **Character misreads** Vision makes (dropped `=` and `_`, `L` read as `l`) are not corrected. They're the largest remaining error source on the benchmark.
- **Spacing inside a line** comes from Vision's text, which sometimes adds a space before `(` or collapses runs of spaces. Rebuilding it from Vision's word positions was tried and made results worse (see [Evaluation](evaluation.md#how-squint-got-here)).
