# Evaluation

To show Squint is better than other tools, you have to measure it. This page covers the metrics, the benchmark, the current results (including where Squint loses), and what the results can't tell you.

- [Headline](#headline)
- [Metrics](#metrics)
- [The benchmark](#the-benchmark)
- [Current results](#current-results)
- [What the results mean](#what-the-results-mean)
- [Threats to validity](#threats-to-validity)
- [Scoring your own screenshots](#scoring-your-own-screenshots)

## Headline

On 40 screenshots of real-world code that Squint was never tuned on, **Squint made 57–62% fewer character errors than the OCR built into macOS and TRex** (7.1% against 16.7–18.8%). It beat them on 35–40 of 40 images, with a sign test at p < 10⁻⁶. It takes about 0.14 s per capture, offline.

**An AI chat assistant (Claude) transcribed every image perfectly**, including a second set with renamed identifiers that it couldn't have memorized. On accuracy alone, Squint does not beat AI chat. Most Squint captures still need a small edit before they run, and line-number gutters are its biggest weakness.

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

Everything is in [`bench/`](../bench/README.md) and can be re-run. In short:

- **40 real functions**, picked at random with a fixed seed: 20 from Python's standard library and 20 from npm's JavaScript source, 6–22 lines each.
- **Realistic rendering:** 6 editor themes, 6 monospaced fonts at 12–20 pt, line numbers on about 40%, and three conditions: a Retina screenshot, or a paused 1080p or 720p video.
- **A novel-code copy** with every identifier renamed, to test whether any system just recalls famous code.
- **Five systems:** Squint, Apple Vision with default settings, Apple Live Text, TRex's own engine, and an AI chat assistant (Claude) that could open only the images. Its file access was checked afterwards. TextSniper isn't included: it's paid and can't be scripted.
- **Squint was not tuned on these images.** Results were recorded with the build at commit `ccd7503`.

## Current results

### Real code (40 images)

| System | Character error rate | Lines exact | Snippet exact | Parses |
|---|---|---|---|---|
| **Squint** (Code Mode) | **7.1%** | **44%** | 2/40 | 3/40 |
| Apple Vision, default settings | 16.7% | 2% | 0/40 | 0/40 |
| TRex | 18.6% | 2% | 0/40 | 0/40 |
| Apple Live Text | 18.8% | 4% | 0/40 | 0/40 |
| Claude (AI chat) | 0.0% | 100% | 40/40 | 40/40 |

Per image, Squint had fewer errors than Apple Vision on 35 images (worse on 4), than TRex on 39 (worse on 1), and than Live Text on all 40. It had more errors than Claude on 38 and tied on 2.

### Renamed identifiers (37 images)

Three JavaScript snippets couldn't be renamed safely and are excluded.

| System | Character error rate | Lines exact | Snippet exact | Parses |
|---|---|---|---|---|
| **Squint** (Code Mode) | **7.4%** | **39%** | 3/37 | 3/37 |
| Apple Vision, default settings | 15.8% | 2% | 0/37 | 0/37 |
| TRex | 17.7% | 1% | 0/37 | 0/37 |
| Apple Live Text | 17.9% | 2% | 0/37 | 0/37 |
| Claude (AI chat) | 0.0% | 100% | 37/37 | 37/37 |

### Where Squint fails

| Condition | Squint error rate (real code) |
|---|---|
| No line numbers | **2.9%** |
| With line numbers | 13.9% |
| Retina screenshot | 4.9% |
| Paused 1080p video | 7.0% |
| Paused 720p video | 9.7% |

**Speed:** median 0.14 s per image (95th percentile 0.20 s), including process start-up, on Apple silicon. The menu bar app keeps Vision loaded, so it's no slower.

Per-image scores: [`bench/results-data.csv`](../bench/results-data.csv) and [`bench/results-data-novel.csv`](../bench/results-data-novel.csv).

## What the results mean

1. **Among on-device tools, Squint is clearly the most accurate for code**, cutting character errors by more than half. The code-layout pass (indentation, blank lines, bracket repair, no autocorrect) is what makes the difference: the same Vision engine without it scores 16.7%.
2. **AI chat is more accurate.** The renamed-identifier set shows this isn't memorization: Claude reads blurry, compressed code character by character. Squint's case against AI chat is **speed, privacy and cost**, not accuracy. It's one keystroke and about 0.1 s, works offline, sends nothing anywhere, and is free.
3. **Squint's output usually needs a small fix.** Only 3 of 40 captures parse as pasted. The largest single cause is line-number gutters, copied as text. That's the first Phase 2 item in the [roadmap](roadmap.md).

## Threats to validity

- **Rendered, not captured.** The screenshots are realistic renders, not captures of real apps or real videos. Real captures add UI clutter, anti-aliasing quirks, scaling and selection mistakes. The next step is scoring real screenshots from users.
- **One AI model, careful instructions.** Claude was given precise transcription rules and time to measure spacing. Quick chat use, other models or free tiers may do worse. That wasn't measured.
- **Two languages.** Results may differ for C-family code, Rust, SQL or shell output.
- **TRex settings.** TRex ran with its default settings (English, accurate mode); other settings may score differently.
- **Earlier development samples.** The three synthetic samples used while building Squint (`fib`, `sum`, `groupBy`) are development data. Their results are not evidence, and they are not part of this benchmark.

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
