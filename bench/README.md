# Benchmark

Measures how accurately each tool turns a screenshot of code into code, on screenshots it was never tuned on. Results and their interpretation are in [docs/evaluation.md](../docs/evaluation.md).

## What's compared

| System | How it's run |
|---|---|
| `squint` | Squint's Code Mode, release build (`bench/run.py`) |
| `plain` | Apple Vision with default settings (`squint --plain`) |
| `livetext` | Apple's Live Text engine, VisionKit's `ImageAnalyzer` ([`LiveText.swift`](LiveText.swift)) |
| `trex` | TRex's own `VisionOCREngine` with TRex's default settings ([`TRexRunner`](TRexRunner)) |
| `claude` | An AI chat assistant given the screenshot and the prompt below, with no access to the answers |

TextSniper isn't included: it's paid, closed-source and has no command-line interface.

## The test set

[`make_dataset.py`](make_dataset.py) picks **real functions** at random (fixed seed): 20 from Python's standard library and 20 from npm's JavaScript source, 6–22 lines each, and only ones that parse. Each gets random rendering settings:

- 6 editor themes (Dark+, Light+, GitHub Light, Monokai, Solarized Dark, One Dark)
- 6 monospaced fonts at 12–20 pt
- line numbers on about 40% of images
- 3 conditions: a Retina **screenshot**, or a paused **1080p** or **720p video** (downscaled, JPEG-compressed, upscaled back)

`--novel` writes a second set with every identifier consistently renamed (`groupBy` → `amberKiln`), so no model can recall the code from training. `--dev` writes the development set used for tuning, and `--holdout` a fresh test set; neither shares a snippet with the test set.

The images are rendered, not captured from real apps. They're realistic, but not a substitute for real screenshots; see [Threats to validity](../docs/evaluation.md#threats-to-validity).

## Run it

From the repository root:

```sh
python3 bench/make_dataset.py                 # bench/data/truth/*.txt + manifest.json
python3 bench/make_dataset.py --novel         # bench/data-novel/
swift bench/Render.swift bench/data           # bench/data/images/*.png
swift bench/Render.swift bench/data-novel
swift build -c release
python3 bench/run.py bench/data               # squint, plain, livetext (+ trex, below)
python3 bench/run.py bench/data-novel
python3 bench/score.py bench/data             # tables + results-data.csv
python3 bench/score.py bench/data-novel
```

**TRex (optional):** clone [TRex](https://github.com/amebalabs/TRex) next to this repository, then build `bench/TRexRunner` with `swift build -c release` and run `bench/run.py` with `TREX_RUNNER=bench/TRexRunner/.build/release/TRexRunner`.

**AI chat:** give each image to the assistant with the prompt below and save the reply as `outputs/<id>.claude.txt`. The published run used Claude agents that could open only the images and their own output files; their file access was checked afterwards.

> Transcribe the code in this image exactly. Do not fix bugs, complete cut-off code, rename anything or reformat. Preserve indentation with spaces exactly as displayed, and preserve blank lines. Do not include the editor's line numbers. Output only the code, with no Markdown fences or explanation.

`SQUINT_BINARY` measures a specific build instead of `.build/release/Squint`.

## Hindi and English

[`hindi/sentences.tsv`](hindi/sentences.tsv) has 18 everyday sentences, six each in Devanagari, Devanagari mixed with English words, and Hinglish (Hindi in Latin letters). [`hindi/Render.swift`](hindi/Render.swift) draws them at 18 pt on a Retina display and at 14 pt:

```sh
swiftc -O bench/hindi/Render.swift -o /tmp/render-hindi && /tmp/render-hindi bench/hindi/sentences.tsv bench/data-hindi
squint eval bench/data-hindi                   # Plain Mode, detected language
squint eval bench/data-hindi --also hi-IN      # detected, plus Hindi when detection is unsure
squint eval bench/data-hindi --language hi-IN  # Hindi only
```

Results are in [Evaluation](../docs/evaluation.md#hindi-and-english).

## Rules

- **Never tune on the test sets.** Develop against `data-dev`, run `data` and `data-novel` to report, and keep `data-holdout` for final numbers.
- Publish per-image results (`results-*.csv`) alongside the summary. They contain scores and settings only, no code.
