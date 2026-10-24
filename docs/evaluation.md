# Evaluation

To show Squint is better than other tools, you have to measure it. This page covers the metrics, the benchmark, the current results (including where Squint loses), and what the results can't tell you.

- [Headline](#headline)
- [Metrics](#metrics)
- [The benchmark](#the-benchmark)
- [Current results](#current-results)
- [How Squint got here](#how-squint-got-here)
- [What the results mean](#what-the-results-mean)
- [Threats to validity](#threats-to-validity)
- [Scoring your own screenshots](#scoring-your-own-screenshots)

## Headline

On screenshots of real-world code that Squint was never tuned on, **Squint made 2.1–3.0% character errors, against 15.8–19.2% for the OCR built into macOS, Apple Live Text and TRex**: at least 5.4× fewer. It beat each of them on 98 of 99 images, at about 0.14 s per capture, offline.

**An AI chat assistant (Claude) transcribed every image perfectly**, including a set with renamed identifiers it couldn't have memorized. On accuracy alone, Squint does not beat AI chat. Squint gets most lines exactly right (57–75%), but only 16–45% of captures parse as pasted, depending on the set. Usually one or two misread characters are the problem.

## Metrics

| Metric | Definition | Better |
|---|---|---|
| **Character error rate** | Levenshtein edit distance between output and ground truth, divided by the number of ground-truth characters. Whitespace counts. | Lower |
| **Lines exact** | Share of lines identical to the ground truth at the same position, including indentation | Higher |
| **Snippet exact** | The whole capture is identical to the source: paste it and nothing needs fixing | Higher |
| **Parses** | Python compiles it, or `node --check` accepts it | Higher |

Trailing whitespace, trailing blank lines and a Markdown fence around a whole answer are ignored for every system, since none of them is visible on screen.

Blind spots: character error rate weighs a missing space the same as a wrong symbol, though only one may break the code. *Lines exact* is positional, so one dropped line shifts everything after it. That's intended, because a dropped `}` breaks the code.

## The benchmark

Everything is in [`bench/`](../bench/README.md) and can be re-run.

- **Real functions**, picked at random with fixed seeds from Python's standard library and npm's JavaScript source, 6–22 lines each.
- **Realistic rendering:** 6 editor themes, 6 monospaced fonts at 12–20 pt, line numbers on about 40% of images, and three conditions: a Retina screenshot, or a paused 1080p or 720p video.
- **Four sets, kept apart:**

| Set | Images | Used for |
|---|---|---|
| Development | 40 (20 Python, 20 JavaScript) | Finding failures and tuning. Never reported as evidence. |
| Test | 40 (20 Python, 20 JavaScript) | Reporting. Run after each round of development. |
| Renamed identifiers | 37 (the test snippets, renamed) | Ruling out memorization by AI models |
| Fresh held-out | 22 (20 Python, 2 JavaScript) | Final numbers: created after all development was done and never looked at during it |

- **Five systems:** Squint, Apple Vision with default settings, Apple Live Text, TRex's own engine, and an AI chat assistant (Claude) that could open only the images; its file access was checked afterwards. TextSniper isn't included: it's paid and can't be scripted. The AI baseline was run on the test and renamed sets.

## Current results

Squint after the Phase 2 accuracy work (October 2026). Version 0.2.0's results are in the history below.

### Test set (40 images)

| System | Character error rate | Lines exact | Snippet exact | Parses |
|---|---|---|---|---|
| **Squint** (Code Mode) | **3.0%** | **65%** | 6/40 | 11/40 |
| Apple Vision, default settings | 16.7% | 2% | 0/40 | 0/40 |
| TRex | 18.6% | 2% | 0/40 | 0/40 |
| Apple Live Text | 18.8% | 4% | 0/40 | 0/40 |
| Claude (AI chat) | 0.0% | 100% | 40/40 | 40/40 |

Per image, Squint had fewer errors than Apple Vision, TRex and Live Text on all 40 images (sign test, p ≈ 2 × 10⁻¹²), and more errors than Claude on 37 (3 ties).

### Renamed identifiers (37 images)

| System | Character error rate | Lines exact | Snippet exact | Parses |
|---|---|---|---|---|
| **Squint** (Code Mode) | **2.9%** | **57%** | 4/37 | 6/37 |
| Apple Vision, default settings | 15.8% | 2% | 0/37 | 0/37 |
| TRex | 17.7% | 1% | 0/37 | 0/37 |
| Apple Live Text | 17.9% | 2% | 0/37 | 0/37 |
| Claude (AI chat) | 0.0% | 100% | 37/37 | 37/37 |

### Fresh held-out set (22 images)

| System | Character error rate | Lines exact | Snippet exact | Parses |
|---|---|---|---|---|
| **Squint** (Code Mode) | **2.1%** | **75%** | 4/22 | 10/22 |
| Apple Vision, default settings | 17.5% | 6% | 0/22 | 0/22 |
| Apple Live Text | 19.0% | 2% | 0/22 | 0/22 |
| TRex | 19.2% | 5% | 0/22 | 0/22 |

Squint beat Apple Vision, Live Text and TRex on all 22 images (p = 4.8 × 10⁻⁷).

### Conditions (test set, Squint)

| Condition | Character error rate |
|---|---|
| Retina screenshot | 2.7% |
| Paused 1080p video | 3.0% |
| Paused 720p video | 3.3% |
| No line numbers / with line numbers | 2.5% / 3.8% |

**Speed:** 0.14 s per recognition in a running app, on Apple silicon. A cold one-off `squint` run, including start-up, took 0.43 s at the median and 0.48 s at the 95th percentile.

Per-image scores: [`bench/results-data.csv`](../bench/results-data.csv), [`results-data-novel.csv`](../bench/results-data-novel.csv), [`results-data-holdout.csv`](../bench/results-data-holdout.csv) and [`results-data-dev.csv`](../bench/results-data-dev.csv).

## Hindi and English

Plain Mode on 18 sentences rendered at two sizes (36 images; [`bench/hindi`](../bench/README.md#hindi-and-english)), character error rate:

| Plain Mode language | Devanagari | Devanagari with English words | Hinglish (Latin letters) |
|---|---|---|---|
| Detected (the default) | 0% | 10.0% | 0% |
| Hindi | 0% | 0% | 76.7%: written out in Devanagari |
| English | 100%: unreadable | 44.0% | 0% |
| Hindi and English, either order | as the first language | | |
| **Detected, plus Hindi when unsure** | **0%** | **2.9%** | **0%** |

Detection picks English for a line that is mostly English words and drops the Devanagari (`आज का standup cancel है।` came back as `stand cancel`). Squint now reads such a line in Hindi as well and keeps the reading Vision is more confident in, whenever someone has Hindi, or another language Vision reads, in System Settings › General › Language & Region. On a Mac with only English there, nothing changes.

**Limits.** Rendered lines in the system font, black on white; real screenshots, handwriting and other Indian languages weren't measured.

## Emoji

Vision can't read emoji. It skips them or reads `:` or `*`, and it can drop the text after one: `console.log("done ✅")` came back as `console.log("done`. Squint finds glyph-sized, shaded or colourful blobs, compares each with all 1,436 emoji in Apple Color Emoji, and keeps only close matches that no other emoji comes near. It then draws `##` over each emoji, lets Vision read the line again, and swaps the `##` back.

**Method.** 300 lines rendered with random emoji (out of all 1,436), code words in syntax colours and plain text: light and dark themes, monospaced and proportional fonts, 12–36 pt, at 1× and 2×. Scored end to end through the `squint` command. A separate check: the 142 benchmark screenshots, which contain no emoji, must come out unchanged.

| | Before | After |
|---|---|---|
| Emoji found | 0 of 465 | **354 of 465 (76%)** |
| Emoji wrong or invented | — | **0** |
| Lines exactly right | 49 of 300 | **162 of 300** |
| Benchmark screenshots changed | — | **0 of 142** |

By on-screen size: 32 px and larger, 85%; 20–31 px, 78%; under 20 px, 50%. Code at 13 pt on a Retina display is about 26 px.

**Speed.** About 35 ms more per capture (0.08 → 0.12 s on the benchmark), and 0.1 s once, the first time emoji glyphs are needed.

**Limits.** Rendered lines, not real screenshots; Apple's emoji art only (screenshots from Windows, Android or many websites use other art); no skin-tone, multi-person or keycap sequences. The detector was tuned on these rendered lines and the benchmark images, so the numbers are optimistic until it's scored on fresh real screenshots.

## How Squint got here

Test-set character error rate after each change. Every change was developed on the development set.

| Build | Change | Test set | Renamed |
|---|---|---|---|
| 0.1.0 | Code layout pass | 7.1% | 7.4% |
| | Remove line-number gutters (first version) | 4.1% | 3.7% |
| | Code-only misread repairs | 3.4% | 3.9% |
| 0.2.0 | Gutters detected from as few as two readable numbers | 3.2% | 3.4% |
| Phase 2 | Language-aware repairs, parse-guided repair, bracket handling, spacing from pixels | **3.0%** | **2.9%** |

**Being honest about the last row:** the misread repairs made two renamed-set images worse. The cause was a gutter safety check that one merged, misread number could veto. That fix was prompted by looking at test-set results, so the test sets are no longer fully untouched for that rule. That's why the **fresh held-out set** exists: it was built after all development, and is the cleanest estimate (2.4%).

**Phase 2, honestly:** the development set improved far more than the unseen sets (character errors 3.1% → 1.7%, lines exact 68% → 82%, parsing 8 → 28 of 40), the usual sign of rules fitted to the data they were built from. On the unseen sets, character errors fell by 0.2–0.4 points and parsing roughly doubled (test 5 → 11 of 40, held-out 8 → 10 of 22). Five of 102 test images got slightly worse, mostly where Vision missed an opening brace and a repair then lined a `}` up with the wrong one. Looking at those five led to two bug fixes (alignment limited to brace languages, so Python's `)` stays where Vision read it); the numbers above include them, so the test sets are no longer fully untouched for those two rules.

**Measured dead ends in Phase 2:** recovering underscores from the pixels (drawing them again for a second reading) helped some images and hurt as many, net zero on the development set, and was reverted. Taking the smallest gap between rows as the line spacing made five development images worse, so only captures of two or three rows use it.

**A measured dead end:** rebuilding the spaces in each line from Vision's per-word positions raised development-set errors from 4.1% to 12.5%. In accurate mode, Vision's word boxes are too approximate for that. The change was reverted and is documented in the code.

## What the results mean

1. **Among on-device tools, Squint is clearly the most accurate for code**, with 4.6–8× fewer character errors. The code-layout pass is what makes the difference: the same Vision engine without it scores 15.8–17.5%.
2. **AI chat is more accurate.** The renamed-identifier set shows it isn't memorization. Squint's case against AI chat is **speed, privacy and cost**, not accuracy. It's one keystroke and about 0.1 s, works offline, sends nothing anywhere, and is free.
3. **Most captures still need a small fix.** Squint gets 53–71% of lines exactly right, but one wrong character anywhere stops a snippet from parsing. The remaining errors are mostly characters Vision misreads or drops (`=`, `_`, `L` read as `l`), which layout can't recover. That's the next accuracy task in the [roadmap](roadmap.md).

## Threats to validity

- **Rendered, not captured.** The screenshots are realistic renders, not captures of real apps or real videos. Real captures add UI clutter, anti-aliasing quirks, scaling and selection mistakes. The next step is scoring real screenshots from users.
- **The held-out set is mostly Python** (20 of 22), because the pool of eligible JavaScript functions had already been used by the other sets.
- **One AI model, careful instructions.** Claude was given precise transcription rules and time to measure spacing. Quick chat use, other models or free tiers may do worse. That wasn't measured.
- **Two languages.** Results may differ for C-family code, Rust, SQL or shell output.
- **TRex settings.** TRex ran with its default settings (English, accurate mode); other settings may score differently.
- **Earlier development samples.** The three synthetic samples used while building Squint (`fib`, `sum`, `groupBy`) are development data and aren't part of the benchmark.

## Scoring your own screenshots

`squint eval` scores a folder of screenshots against ground truth:

```text
my-screenshots/
├── django-view.png              # the screenshot
├── django-view.txt              # ground truth: the exact source, including indentation
├── django-view.textsniper.txt   # optional: another tool's output for the same image
└── ...
```

```sh
squint eval my-screenshots
```

It prints character error rate and exact lines per image and on average, for Squint, plain Vision and any `.textsniper.txt` outputs. For the full benchmark with all five systems, see [`bench/`](../bench/README.md).

**Real screenshots are the most valuable contribution.** Capture at native resolution, copy the ground truth from the original source rather than retyping it, and keep every screenshot from one video or deck together, so test images never leak into tuning.
