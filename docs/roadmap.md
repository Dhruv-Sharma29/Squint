# Roadmap

**Goal:** make Squint the fastest and most accurate *on-device* way to copy code from a screen on macOS, while matching the everyday features people expect from TextSniper and TRex.

The order is deliberate. **Measure first** (Phase 0), add the small expected features (Phase 1), then put most of the effort where Squint can clearly win: code accuracy (Phase 2).

## Status (October 2026)

| Phase | Status |
|---|---|
| 0: Benchmark | **Done.** 40 real-code screenshots plus a renamed-identifier copy, five systems. See [Evaluation](evaluation.md). |
| 1: Expected features | **Done.** Settings, custom shortcut, open at login, Plain Mode language, Spotlight/Shortcuts actions, custom words, opening links, and hiding the menu bar icon. |
| 2: Code accuracy | **Every item built and measured.** Test-set character errors 7.1% → 3.0%, lines exact 61% → 65%, snippets that parse 5 → 11 of 40; fresh held-out set 2.1%, 75%, 10 of 22. The 90% parse target is an [open goal](#open-goals). |
| 3: Structure beyond code | **Done.** Tables (macOS 26 or later), opt-in capture history, and a Hindi–English benchmark that led to reading a second preferred language when detection is unsure. |
| 4: Distribution and trust | **Partly done.** CI, a release script, the `dhruv-sharma29/tap` tap and release 0.3.0; signing, notarization, an official cask and auto-update need an Apple Developer ID (see below). |

**What the benchmark changed:** an AI chat assistant transcribed every test image perfectly, so Squint can't claim to be the most accurate option overall. Its case is the most accurate *on-device* option, 4.6–8× fewer errors than the OCR built into macOS, at 0.13 s per capture, free and private. The plan below reflects that.

- [Status](#status-october-2026)
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

| Capability | TextSniper | TRex | Squint | Plan |
|---|---|---|---|---|
| Capture a screen region to the clipboard | ✓ | ✓ | ✓ | — |
| **Code layout** (indentation, blank lines, brackets) | ✗ (its site warns about misreads on code) | Not listed | **✓** | Phase 2 deepens it |
| **Accuracy benchmark** | Not listed | Not listed | **✓** `squint eval`, [`bench/`](../bench/README.md) | Done |
| QR codes and barcodes | ✓ | ✓ | ✓ | — |
| Custom global shortcut | ✓ | ✓ | ✓ | Done |
| Settings window | Shortcut only | ✓ | ✓ | Done |
| Launch at login | Not listed | ✓ | ✓ | Done |
| Choose recognition language | Follows macOS version | ✓ | ✓ (Plain Mode) | Done |
| Custom word list | Not listed | ✓ | ✗ | Phase 1 |
| Read an image from the clipboard | Not listed | ✓ | ✓ | — |
| URL scheme | Not listed | ✓ | ✓ `squint://` | — |
| Spotlight, Siri and Shortcuts actions | Not listed | Not listed | ✓ (actions return the text) | Done |
| After-capture actions (open URL, run a Shortcut) | Not listed | ✓ | Through Shortcuts | Phase 1 |
| Command-line tool | Not listed | ✓ | ✓ | — |
| Capture history | Not listed | ✓ | ✗ | Phase 3 |
| Table detection | Not listed | ✓ | ✗ | Phase 3 |
| Repeated capture of a region | Not listed | ✓ (watch mode) | ✗ | Phase 2, as scroll capture for code |
| Signed builds and auto-update | Notarized | ✓ | ✗ (built from source) | Phase 4 |
| Homebrew install | Not listed | One command (official cask) | Three commands: tap, trust, install | Phase 4: own tap done; Homebrew 7 requires the trust step for any third-party tap |
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

**Result:** done for TRex, Apple Live Text, Apple Vision and an AI chat assistant on rendered screenshots. TextSniper can't be scripted, and **real screenshots and the user check are still open**.

## Phase 1: Expected features

Small features people expect. Each one should take a day or less, with no new dependencies.

| Feature | Approach |
|---|---|
| Settings window | SwiftUI `Settings` scene, opened from the menu, with General, Shortcut and Recognition tabs |
| Custom global shortcut | A key recorder that re-registers through the existing Carbon `HotKey` and is saved to `UserDefaults`. Report conflicts, since `RegisterEventHotKey` already returns an error when another app owns the shortcut. |
| Launch at login | `SMAppService.mainApp`, a native toggle that doesn't need `brew services` |
| Recognition language and custom words | Language picker filled from Vision's `supportedRecognitionLanguages()`, which lists 33 languages on macOS 27, including Hindi and Marathi. Pass a custom word list through Vision's `customWords`. |
| ~~Spotlight and Shortcuts~~ | **Done:** four App Intents that return the captured text |
| After-capture actions | Open the first URL found (`NSDataDetector`). Running a Shortcut is now possible the other way round, from Shortcuts. |
| Hide the menu bar icon | Optional. Squint stays reachable through the shortcut and `squint://` links. |

**Done when:** the features above ship, each with a unit test or a written manual check.

## Phase 2: Better than both at code

This is where Squint wins. Work in order of measured impact: re-rank this list using the Phase 0 failure analysis.

| # | Improvement | Why it matters |
|---|---|---|
| ~~1~~ | ~~**Remove line-number gutters**~~ | **Done.** Line-numbered test images went from 13.9% to 4.1% character errors, including gutters where Vision reads only two numbers. |
| 1b | **Fix code-only misreads** | **Mostly done:** `{` read as `f`/`t`/`i`/`(`, lone `}` read as `8`/`)`/`]`, template-literal backticks, `\|\|` read as `Il`/`I1`, `=>` read as `>`, `({` read as `(t`, `[` read as `I`, quotes read as `i`, lookalike Cyrillic letters, `} catch`/`} else` without `}`, Python `def__init__`. Still open: dropped `=` and `_` (tried pixel-level underscores: net zero, reverted), `L`/`l`. |
| ~~2a~~ | ~~Rebuild spacing from Vision's word boxes~~ | **Tried and reverted:** dev-set errors rose from 4.1% to 12.5%; Vision's word boxes are too approximate. Needs pixel-level gap detection instead. |
| ~~2~~ | ~~**Character-level spacing**~~ | **Done, differently:** `boundingBox(for:)` turned out to return whole-word boxes, so runs of spaces are measured from the gaps in the pixels instead, matched to the line's spaces only when the counts agree. |
| ~~3~~ | ~~**Bracket repair that understands code**~~ | **Done:** brackets in strings and comments are ignored, a callback's `})` is restored, and a `}` lines up with its opener in brace languages. |
| ~~4~~ | ~~**Detect the language**~~ | **Done:** Python or brace languages for repairs, and a finer guess (Swift, Rust, Go, TypeScript, JavaScript, Python, Java, C++, SQL, shell) for Markdown tags. |
| ~~5~~ | ~~**Repair guided by parsing**~~ | **Done:** JavaScriptCore in-process for JavaScript, an installed Python for Python; a fix is kept only if the whole snippet then parses, and nothing that isn't on screen is added. |
| ~~6~~ | ~~**Copy as Markdown**~~ | **Done:** an optional setting. |
| ~~7~~ | ~~**Scroll capture**~~ | **Done:** a session in the menu; parts are joined by the lines they share. |

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
| ~~`homebrew-tap` repository~~ | **Done:** [Dhruv-Sharma29/homebrew-tap](https://github.com/Dhruv-Sharma29/homebrew-tap), first release 0.3.0. Homebrew 7 asks users to `brew trust` any third-party tap, so the install is three short commands, not one. |
| ~~GitHub Actions CI~~ | **Done:** build, tests and a signed bundle on every push |
| ~~Release script~~ | **Done:** [`scripts/release.sh`](../scripts/release.sh) checks CI, sets the version, tags, verifies the archive's checksum twice and updates the formula (and the tap's). |
| Apple Developer ID ($99 a year) | **Needs the owner's paid account.** Signed and notarized downloads; Spotlight actions for everyone; keeps the Screen Recording permission across updates, which ad-hoc builds lose. `bundle.sh` already signs with any identity in `SQUINT_SIGN_IDENTITY`. |
| Official Homebrew cask | Needs signing and notarization, plus Homebrew's notability bar: 75 stars or 30 forks or watchers, or 225 stars or 90 forks or watchers for a self-submission, and a repository at least 30 days old |
| Auto-update | **Not needed yet:** Homebrew users have `brew upgrade`. Sparkle becomes useful with notarized direct downloads, after the Developer ID. |

## Open goals

### 90% of complete snippets parse

**Status: open.** 11 of 40 test snippets parse (28%) and 10 of 22 on the fresh held-out set (45%), against a target of 90%.

**Why more rules won't get there:** the failures inspected so far are mostly single characters Vision misreads or drops, such as an opener, a quote or an underscore. A rule written for one of these images tends to break another; two such changes were measured and dropped because each regressed 5 development images. Rules tuned further on the same images would fit those images and not new code.

**What could close the gap, each scored on the held-out set before it ships:**

| Approach | Trade-off |
|---|---|
| An on-device recognition model trained on code screenshots | The most direct fix; needs training data and must stay fast (under 1 s) and private |
| A larger labelled dataset: more languages, themes, fonts and real captures | Makes every measurement trustworthy and is needed to train the model above |
| Opt-in clean-up by a language model, preferably on-device | See [Not planned](#not-planned); must never change code that was read correctly |

Until one of these lands, Squint reports parse rate on every benchmark run but does not claim the target.

## Not planned

| Idea | Why not, for now |
|---|---|
| LLM clean-up, on by default | The benchmark shows the gap is real: AI chat was perfect where Squint averaged 4% character errors. But sending screenshots to a cloud model by default breaks the privacy promise. **Under consideration instead:** an opt-in setting, preferably with an on-device model, scored on the benchmark before it ships. |
| General watch mode | Niche. Scroll capture covers the code use case. |
| Tesseract | Vision already reads Hindi and Marathi on current macOS, and Tesseract is a large dependency. |

## Success metrics

Measured on the 40-image test set (rendered screenshots) after Phase 2, October 2026.

| Metric | Target | Now | Met? |
|---|---|---|---|
| Character error rate | At most **half** of the better of TextSniper and TRex | 3.0% vs TRex 18.6% (TextSniper not measurable) | ✓ for TRex |
| Lines exact | At least **20 points** above the better competitor | 65% vs TRex 2% | ✓ |
| Parse rate for complete snippets | **90% or higher** | 28% (11 of 40); 45% (10 of 22) on the fresh held-out set | ✗: an [open goal](#open-goals) |
| Selection-to-clipboard time | **Under 1 s** at the 95th percentile | 0.14 s per recognition; 0.48 s for a cold one-off `squint` run, including start-up | ✓ |
| User check | **4 of 5** users paste and run a snippet without editing it | Not run yet | — |
| Regressions | None on existing benchmark images | Phase 2 left 5 of 102 test images slightly worse (Vision missed an opener and a repair followed it); none on the development set | ✗: small, recorded in [Evaluation](evaluation.md) |

## Risks

| Risk | Mitigation |
|---|---|
| Apple improves Live Text for code | Keep the advantage measurable and public through the benchmark; parse-guided repair is hard to copy |
| AI chat is more accurate | Compete on speed, privacy and cost; consider an opt-in on-device model (see [Not planned](#not-planned)) |
| Reported macOS 27 Vision regression | Move to the Swift `RecognizeTextRequest` API (macOS 15+) if it shows up |
| Overfitting repair rules to the benchmark | Strict held-out split, grouped by source; add new screenshots every release |
| ⌘⇧2 clash with TextSniper | **Resolved:** custom shortcut in Settings, and the clash is reported |
| Permission friction after updates | Developer ID signing (Phase 4) |

## Indicative timeline

| Week | Focus |
|---|---|
| 1 | Phase 0: dataset, competitor outputs, parse-rate metric, baseline table. Set up the `homebrew-tap` repository and CI in parallel. |
| 2–3 | Phase 1 features |
| 4–6 | Phase 2, in benchmark-ranked order, re-measuring after each item |
| 7 | Phase 3 tables and history; evaluation write-up |
| When the account is ready | Phase 4 signing, cask and auto-update |
