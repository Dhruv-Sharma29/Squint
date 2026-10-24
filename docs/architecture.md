# How it works

- [Pipeline](#pipeline)
- [Source layout](#source-layout)
- [The code-layout pass](#the-code-layout-pass)
- [Concurrency](#concurrency)
- [Design decisions](#design-decisions)
- [Known limitations](#known-limitations)

## Pipeline

```text
 ⌘⇧2 · menu · squint://capture          squint://clipboard · menu
            │                                     │
   screencapture -i (system UI)          clipboard PNG/TIFF
            └──────────────┬──────────────────────┘
                           ▼
                temporary image file
                           │
     Vision: VNRecognizeTextRequest + VNDetectBarcodesRequest
                           │
           barcode found? ─┼─ yes ─► barcode payloads
                           │ no
                           ▼
                group text boxes into rows
                           │
          Plain Mode ──────┼────── Code Mode
     join rows with spaces │   lay rows on a line grid
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
| `App/SquintApp.swift` | SwiftUI `MenuBarExtra` scene |
| `App/AppDelegate.swift` | Owns the model and receives `squint://` links |
| `App/CaptureModel.swift` | `@MainActor @Observable` state and the capture → recognize → copy flow |
| `App/MenuContent.swift` | Menu items |
| `App/HotKey.swift` | Global ⌘⇧2 through Carbon `RegisterEventHotKey` |
| `Capture/ScreenCapture.swift` | Runs `screencapture -i` and returns the captured image file |
| `Capture/ClipboardImage.swift` | Writes a clipboard image to a temporary file |
| `OCR/Recognizer.swift` | Vision requests, row grouping and the code-layout pass |
| `OCR/Slot.swift` | One output row: text, unreadable ink, or blank |
| `OCR/InkMap.swift` | Pixel access used to find glyphs Vision skipped |
| `Eval/Metrics.swift` | Edit distance, character error rate, exact-line rate |
| `Eval/CLI.swift` | `squint <image>` and `squint eval` |
| `Formula/squint.rb` | Homebrew formula |
| `bundle.sh` | Assembles and ad-hoc signs `Squint.app` |
| `Assets/` | App icon: the `AppIcon.icon` source plus compiled `Assets.car` and `AppIcon.icns` (see [Development](development.md#app-icon)) |

## The code-layout pass

Vision returns a list of text boxes. Each box is one recognized string with a bounding box in normalized coordinates, with the origin at the bottom-left. Code Mode turns those boxes back into source code in seven steps.

1. **Group into rows.** Boxes whose vertical centres are within half a box height of each other form one row, ordered left to right.
2. **Estimate character width.** For each box with at least 4 characters, divide its width by its character count. The median is the character width. This assumes a monospaced font.
3. **Estimate line pitch.** The median vertical distance between consecutive rows. A gap of *n* pitches between two rows means *n − 1* rows are missing.
4. **Check missing rows for ink.** For each missing row, `InkMap` scans a band 0.4 × the median text height either side of where the row should be. It looks for pixels that differ from the background by more than 64/255 in any channel. The same check runs below the last recognized row. A row with ink becomes `.ink`, meaning there is a glyph Vision didn't read. A row without ink becomes `.blank`.
5. **Compute indentation.** Each row's left edge, relative to the leftmost row, is divided by the character width and rounded to whole columns. The smallest non-zero indent is taken as the indent step, and every indent is snapped to a multiple of it. This absorbs measurement error at deeper nesting levels.
6. **Rebuild spacing within a row.** The gap between neighbouring boxes on one row becomes the matching number of spaces, so aligned comments keep their alignment.
7. **Render.** Walk the slots top to bottom, keeping a stack of open brackets (`{`, `(`, `[`):
   - A text row ending in ` 1`, ` I`, ` l` or ` |` that is followed by a more-indented row gets that character replaced by `{`. This is Vision's most common brace misread.
   - An `.ink` row becomes the closer for the innermost open bracket, at its measured indent.
   - Trailing blank rows are dropped.

### Evidence behind these steps

| Observation | How it was checked |
|---|---|
| Vision returns only one candidate per line in `.accurate` mode, so there are no alternatives to re-rank | Requested `topCandidates(5)`; got 1 |
| Vision does not read a lone `}` | The full image, a cropped row, and a row upscaled 3× with padding all returned nothing |
| Autocorrect damages code | Plain Mode output turned `fib(n):` into `fib (n) :` |
| `{` at the end of a line is read as `1` | Seen in `for (const x of arr) {` |

## Concurrency

The package compiles in Swift 6 language mode with strict concurrency checking.

- `CaptureModel` is `@MainActor @Observable`. The UI reads it directly.
- Recognition runs in a `nonisolated async` function, so Vision's synchronous work happens off the main actor.
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

## Known limitations

- **Proportional fonts:** indentation and spacing assume monospaced text.
- **Continuation lines** aligned to an opening parenthesis are snapped to the nearest indent step.
- **Brackets inside strings and comments** are counted as code when deciding which closer to restore.
- **Combined closers** such as `});` are restored as a bare `}`.
- **Busy backgrounds:** ink detection uses the top-left pixel as the background colour, which suits flat editor themes but not gradients or photos.
- **Mixed selections:** if a selection contains a QR code, its contents replace the text.
- **Runs of spaces inside one Vision box** collapse to a single space, for example two spaces before an inline comment.
- **Line-number gutters** are copied as text.
