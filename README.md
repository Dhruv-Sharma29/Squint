# Squint

**Screen OCR for code on macOS.** Select code anywhere on your screen, such as a video tutorial, a slide deck or a screenshot, and get text you can paste and run, with its indentation, blank lines and brackets intact.

```sh
brew tap dhruv-sharma29/squint https://github.com/Dhruv-Sharma29/Squint
brew install dhruv-sharma29/squint/squint
brew services start squint
```

Then press **⌘⇧2**, drag over some code, and paste.

---

## Why Squint

General-purpose screen OCR is tuned for prose. On source code it typically:

- drops leading whitespace, so indentation and Python block structure are lost;
- collapses blank lines;
- "autocorrects" identifiers and symbols into English words;
- skips lines that contain a single character, such as a closing `}`.

TextSniper's own product page notes that it *"can have misreads when there are a lot of symbols such as you might find in computer code."* Squint is built for that case. It uses Apple's on-device Vision engine, the same one TRex uses and very likely TextSniper too, then adds a layout and repair pass designed for code. [How it works](docs/architecture.md) explains each step.

## Features

| Feature | Details |
|---|---|
| **Code Mode** (default) | Keeps indentation, blank lines and column spacing. Turns off English autocorrect. Restores closing brackets that Vision skips, and repairs `{` misread as `1`. |
| **Plain Mode** | For prose, with autocorrect and automatic language detection. |
| **QR codes and barcodes** | Select a code to copy its contents. |
| **Clipboard images** | Read text from an image you've already copied, such as a screenshot from chat. |
| **Shortcut and links** | Global **⌘⇧2**, plus `squint://` links for Raycast, Alfred, Shortcuts or any hotkey tool. |
| **Command line** | `squint <image>` prints text; `squint eval <dir>` measures accuracy against ground truth. |
| **Private by design** | Runs entirely on device with no network access. Screenshots are deleted as soon as they've been read. |

## Documentation

| Guide | What's inside |
|---|---|
| [Installation](docs/installation.md) | Homebrew, building from source, permissions, updating, uninstalling, troubleshooting |
| [Usage](docs/usage.md) | Capturing, modes, QR codes, clipboard, `squint://` links, CLI, tips for best results |
| [How it works](docs/architecture.md) | Pipeline, code-layout algorithm, design decisions, known limitations |
| [Evaluation](docs/evaluation.md) | Metrics, dataset format, how to benchmark against TextSniper, current results |
| [Development](docs/development.md) | Building, testing, project conventions, releasing a new version |
| [Changelog](CHANGELOG.md) | Release history |

## Project status

**0.1.0, early.** The core pipeline works. Accuracy has so far been measured only on a small synthetic smoke test, which is not evidence of real-world performance. A benchmark built from real screenshots is the next milestone; see [Evaluation](docs/evaluation.md).

## Requirements

macOS 14 Sonoma or later. Homebrew builds Squint from source, so it needs Xcode or the Command Line Tools with Swift 6.

## Acknowledgements

- Text recognition by Apple's [Vision](https://developer.apple.com/documentation/vision) framework.
- [TRex](https://github.com/amebalabs/TRex) by Ameba Labs (MIT) was a reference for the capture flow, the feature set and Homebrew distribution. Squint contains no TRex code.

## License

[MIT](LICENSE)
