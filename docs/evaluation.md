# Evaluation

To show that Squint is better than other tools, you have to measure it. This page defines the metrics, the dataset format, and a fair protocol for comparing Squint with TextSniper and with plain OCR.

- [What is compared](#what-is-compared)
- [Metrics](#metrics)
- [Dataset format](#dataset-format)
- [Running an evaluation](#running-an-evaluation)
- [Building a benchmark](#building-a-benchmark)
- [Current results](#current-results)
- [Threats to validity](#threats-to-validity)

## What is compared

| System | What it is |
|---|---|
| `plain` | Apple Vision with autocorrect on and no layout pass. This is close to what general-purpose Mac OCR apps produce, but it is not TextSniper itself. |
| `squint` | Squint's Code Mode |
| `textsniper` | Real TextSniper output that you capture by hand, if a `.textsniper.txt` file exists |

## Metrics

| Metric | Definition | Better |
|---|---|---|
| **CER** (character error rate) | Levenshtein edit distance between output and ground truth, divided by the number of ground-truth characters. Whitespace counts. | Lower |
| **Lines exact** | Share of lines identical to the ground truth at the same position, including indentation | Higher |

Each metric has blind spots:

- CER weighs a missing space the same as a wrong symbol, even though only one of them may break the code.
- *Lines exact* is positional. One dropped line shifts every line after it, so it penalizes dropped lines heavily. This is intended, because a dropped `}` breaks the code.
- Neither metric checks whether the result actually runs. A **compiles/parses** metric (`python -m py_compile`, `node --check`, and so on) is planned.

## Dataset format

A benchmark is a folder of files that share a name:

```text
benchmark/
├── django-view.png              # the screenshot
├── django-view.txt              # ground truth: the exact source, including indentation
├── django-view.textsniper.txt   # optional: TextSniper's output for the same image
├── rust-match.png
└── rust-match.txt
```

- Images can be `.png`, `.jpg` or `.jpeg`. Any image without a `.txt` file is skipped.
- Ground truth must keep the original indentation (spaces, not tabs) and blank lines. Trailing newlines are ignored.

## Running an evaluation

```sh
squint eval path/to/benchmark
```

```text
file            system   CER    lines exact
fib_py.png      plain    0.202  0%
fib_py.png      squint   0.008  88%
...
MEAN (n=2)      plain    0.213  6%
MEAN (n=2)      squint   0.004  94%
```

The output is tab-separated, so you can paste it into a spreadsheet or redirect it to a file.

## Building a benchmark

1. **Collect real screenshots** that match how people use Squint: video tutorials, conference slides, documentation, editor and terminal screenshots. Vary the language, theme (light and dark), font and zoom level. Aim for at least 30–50 images.
2. **Capture at native resolution** with ⌘⇧4. Don't resize the images.
3. **Get ground truth by copying, not retyping.** Many tutorials link to their source code. Copy the exact lines shown on screen, which avoids typos in the ground truth.
4. **Record TextSniper's output** for each image. Open the image full-size, select the same region with TextSniper, and save the result as `name.textsniper.txt`. Use the same region and resolution for every tool.
5. **Split before tuning.** Put about 20% of the images, chosen at random, in a separate `test/` folder and don't look at its results until the end. Tune only against the rest. Keep all screenshots from the same video or slide deck in the same split, or the test set will leak into tuning.
6. **Report the mean and the number of images**, and read individual failures. A table of averages hides the reasons things fail.

## Current results

> **Smoke test only. This is not evidence of real-world accuracy.** The two images are synthetic renders of clean monospaced code on a flat dark background. Real screenshots will be harder.

| Sample | System | CER | Lines exact |
|---|---|---|---|
| Python, 8 lines (`fib_py`) | plain | 0.202 | 0% |
| | **squint** | **0.008** | **88%** |
| JavaScript, 9 lines (`sum_js`) | plain | 0.225 | 11% |
| | **squint** | **0.000** | **100%** |
| **Mean (n = 2)** | plain | 0.213 | 6% |
| | **squint** | **0.004** | **94%** |

The remaining Python error is two spaces before an inline `#` comment collapsing to one (see [Known limitations](architecture.md#known-limitations)).

**README example (`groupBy`, 12 lines of JavaScript, synthetic):** plain 0 of 12 lines exact with a 19.4% character error rate; Squint 12 of 12 with 0%. That sample first scored 8 of 12 for Squint, and its failures led to the `]`-read-as-`l` repair. Because the fix was designed after seeing this sample, it is development data, not test data.

**Stability check:** 24 recognitions in a single process on macOS 27.0.1 all returned correct output. This was a check for the reported macOS 27 Vision regression.

## Threats to validity

- **Synthetic data** overstates accuracy: no compression, blur, syntax colouring or UI clutter.
- **Overfitting:** the repair rules were designed after looking at these two samples. Only a held-out test set can show whether they generalize.
- **Baseline fidelity:** `plain` approximates general-purpose OCR apps but is not any of them. Compare against real TextSniper output before claiming Squint is better.
