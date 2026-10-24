# Roadmap

**Goal:** make Squint the most accurate way to copy code from a screen on macOS, while matching the everyday features people expect from TextSniper and TRex.

The order is deliberate. **Measure first** (Phase 0), add the small expected features (Phase 1), then put most of the effort where Squint can clearly win: code accuracy (Phase 2).

- [Where Squint stands](#where-squint-stands)
- [Principles](#principles)
- [Phase 0: Benchmark](#phase-0-benchmark)
- [Phase 1: Expected features](#phase-1-expected-features)
- [Phase 2: Better than both at code](#phase-2-better-than-both-at-code)
- [Phase 3: Structure beyond code](#phase-3-structure-beyond-code)
- [Phase 4: Distribution and trust](#phase-4-distribution-and-trust)
- [Not planned](#not-planned)
- [Success metrics](#success-metrics)
- [Risks](#risks)
- [Indicative timeline](#indicative-timeline)

## Where Squint stands

Sources: [textsniper.app](https://textsniper.app) and the [TRex README](https://github.com/amebalabs/TRex), as of October 2026. "Not listed" means the product page or README doesn't mention the feature, not that it definitely doesn't exist.

| Capability | TextSniper | TRex | Squint 0.1 | Plan |
|---|---|---|---|---|
| Capture a screen region to the clipboard | ✓ | ✓ | ✓ | — |
| **Code layout** (indentation, blank lines, brackets) | ✗ (its site warns about misreads on code) | Not listed | **✓** | Phase 2 deepens it |
| **Accuracy benchmark tool** | Not listed | Not listed | **✓** `squint eval` | Phase 0 uses it |
| QR codes and barcodes | ✓ | ✓ | ✓ | — |
| Custom global shortcut | ✓ | ✓ | ✗ (fixed ⌘⇧2, the same default as TextSniper) | Phase 1 |
| Settings window | Shortcut only | ✓ | ✗ | Phase 1 |
| Launch at login | Not listed | ✓ | Only via `brew services` | Phase 1 |
| Choose recognition language | Follows macOS version | ✓ | Automatic only, in Plain Mode | Phase 1 |
| Custom word list | Not listed | ✓ | ✗ | Phase 1 |
| Read an image from the clipboard | Not listed | ✓ | ✓ | — |
| URL scheme | Not listed | ✓ | ✓ `squint://` | — |
| After-capture actions (open URL, run a Shortcut) | Not listed | ✓ | ✗ | Phase 1 |
| Command-line tool | Not listed | ✓ | ✓ | — |
| Capture history | Not listed | ✓ | ✗ | Phase 3 |
| Table detection | Not listed | ✓ | ✗ | Phase 3 |
| Repeated capture of a region | Not listed | ✓ (watch mode) | ✗ | Phase 2, as scroll capture for code |
| Signed builds and auto-update | Notarized | ✓ | ✗ (built from source) | Phase 4 |
| Homebrew install | Not listed | One command (official cask) | Three commands | Phase 4 (one command) |
| Price | $7.99–$11.99 | Free, MIT | Free, MIT | — |

## Principles

1. **Measure before and after.** No change to accuracy is merged without `squint eval` results on the held-out set, before and after.
2. **On device and private.** No network access and no telemetry. Captures are deleted as soon as they've been read.
3. **No third-party dependencies** unless a feature cannot exist without one.
4. **Keep the expected features small and boring.** Spend the effort on code accuracy.

## Phase 0: Benchmark

*Nothing in Phase 2 can be shown to work without this.*

| Task | Detail |
|---|---|
| Real dataset | 50 or more screenshots: video tutorials, slides, docs, editors, terminals; light and dark themes; at least 5 languages; several zoom levels. See [Evaluation](evaluation.md#building-a-benchmark). |
| Competitor outputs | Save `name.textsniper.txt` and `name.trex.txt` for every image. TRex is free, so both can be compared. |
| Generalize `squint eval` | Score any `name.<system>.txt` file, not just `textsniper` |
| **Parse rate** metric | Share of complete snippets that parse (`python -m py_compile`, `node --check`, `swiftc -parse`, and so on). "Pastes and runs" is what users care about. |
| Held-out split | 20% of images, grouped by source video or deck, never used for tuning |
| User check | Five target users (for example CS students copying code from lecture videos) each capture three snippets from their own material. Record whether the paste ran without edits. |

**Done when:** `docs/evaluation.md` publishes a baseline table of Squint vs TextSniper vs TRex on the held-out set.

## Phase 1: Expected features

Small features people expect. Each one should take a day or less, with no new dependencies.

| Feature | Approach |
|---|---|
| Settings window | SwiftUI `Settings` scene, opened from the menu, with General, Shortcut and Recognition tabs |
| Custom global shortcut | A key recorder that re-registers through the existing Carbon `HotKey` and is saved to `UserDefaults`. Report conflicts, since `RegisterEventHotKey` already returns an error when another app owns the shortcut. |
| Launch at login | `SMAppService.mainApp`, a native toggle that doesn't need `brew services` |
| Recognition language and custom words | Language picker filled from Vision's `supportedRecognitionLanguages()`, which lists 33 languages on macOS 27, including Hindi and Marathi. Pass a custom word list through Vision's `customWords`. |
| After-capture actions | Open the first URL found (`NSDataDetector`), or run a named Shortcut (`shortcuts run`) |
| Hide the menu bar icon | Optional. Squint stays reachable through the shortcut and `squint://` links. |

**Done when:** the features above ship, each with a unit test or a written manual check.

## Phase 2: Better than both at code

This is where Squint wins. Work in order of measured impact: re-rank this list using the Phase 0 failure analysis.

| # | Improvement | Why it matters |
|---|---|---|
| 1 | **Remove line-number gutters**: detect a left column of consecutive integers and strip it | Editor and video screenshots usually include line numbers. Today Squint copies them. |
| 2 | **Character-level spacing**: split Vision boxes at spaces with `VNRecognizedText.boundingBox(for:)` | Keeps aligned comments and runs of spaces, the one error left in the smoke test |
| 3 | **Bracket repair that understands code**: ignore brackets in strings and comments; restore `});`, `})` and `]);` in the order they were opened | Removes today's biggest known limitation |
| 4 | **Detect the language** (Python, JavaScript, Swift, Java, C-family) from keywords and syntax | Enables language-specific repair, such as no braces in Python and checking semicolons in C-family code |
| 5 | **Repair guided by parsing**: generate candidate fixes and keep the one that parses, when the language's tool is installed | Something no general OCR tool does; measured directly by the parse rate |
| 6 | **Copy as Markdown**: optional fenced code block with a language tag | Pastes straight into README files, chats and LLM prompts |
| 7 | **Scroll capture**: several captures while scrolling a long file or video, merged by overlapping lines | Gets a whole file from a long tutorial. TRex's watch mode is the nearest equivalent but doesn't understand code. |

**Done when:** on the held-out set, Squint beats both TextSniper and TRex on character error rate, exact lines and parse rate. Targets are under [Success metrics](#success-metrics).

## Phase 3: Structure beyond code

| Feature | Approach |
|---|---|
| Tables → TSV or Markdown | Evaluate Vision's document recognition on macOS 26+ before writing a custom detector |
| Capture history | Last *N* captures, stored only on this Mac, opt-in, with a "Clear history" button |
| Mixed Hindi–English text | Benchmark a Hindi and Hinglish set using Vision's `hi-IN` support. Tesseract isn't needed on current macOS. |

## Phase 4: Distribution and trust

| Step | Effect |
|---|---|
| `homebrew-tap` repository | `brew install dhruv-sharma29/tap/squint`: one command instead of three |
| GitHub Actions CI | Build and `swift test` on every push |
| Release script | Tag → compute checksum → update formula, in one step |
| Apple Developer ID ($99 a year) | Signed and notarized downloads. Also keeps the Screen Recording permission across updates, since ad-hoc builds lose it. |
| Official Homebrew cask | Needs signing and notarization, plus Homebrew's notability bar: 75 stars or 30 forks or watchers, or 225 stars or 90 forks or watchers for a self-submission, and a repository at least 30 days old |
| Auto-update | Sparkle for direct downloads; Homebrew users already have `brew upgrade` |

## Not planned

| Idea | Why not, for now |
|---|---|
| LLM clean-up | Has to beat the rule-based repair on the held-out set first. It also adds latency and either a large model or network access, which conflicts with the privacy promise. Revisit with an on-device model if the benchmark shows a gap that rules can't close. |
| General watch mode | Niche. Scroll capture covers the code use case. |
| Tesseract | Vision already reads Hindi and Marathi on current macOS, and Tesseract is a large dependency. |

## Success metrics

These targets are **proposed** and should be revisited once Phase 0 shows the real baselines. All are measured on the held-out set.

| Metric | Target |
|---|---|
| Character error rate | At most **half** of the better of TextSniper and TRex |
| Lines exact | At least **20 percentage points** above the better competitor |
| Parse rate for complete snippets | **90% or higher** |
| Selection-to-clipboard time | **Under 1 s** at the 95th percentile, on a 2020-or-later Mac |
| User check | **4 of 5** users paste and run a snippet without editing it |
| Regressions | None on existing benchmark images |

## Risks

| Risk | Mitigation |
|---|---|
| Apple improves Live Text for code | Keep the advantage measurable and public through the benchmark; parse-guided repair is hard to copy |
| Reported macOS 27 Vision regression | Move to the Swift `RecognizeTextRequest` API (macOS 15+) if it shows up |
| Overfitting repair rules to the benchmark | Strict held-out split, grouped by source; add new screenshots every release |
| ⌘⇧2 clash with TextSniper | Custom shortcut in Phase 1; Squint already reports the clash in its menu |
| Permission friction after updates | Developer ID signing (Phase 4) |

## Indicative timeline

| Week | Focus |
|---|---|
| 1 | Phase 0: dataset, competitor outputs, parse-rate metric, baseline table. Set up the `homebrew-tap` repository and CI in parallel. |
| 2–3 | Phase 1 features |
| 4–6 | Phase 2, in benchmark-ranked order, re-measuring after each item |
| 7 | Phase 3 tables and history; evaluation write-up |
| When the account is ready | Phase 4 signing, cask and auto-update |
