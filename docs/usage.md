# Usage

- [Capturing text](#capturing-text)
- [Code Mode and Plain Mode](#code-mode-and-plain-mode)
- [QR codes and barcodes](#qr-codes-and-barcodes)
- [Clipboard images](#clipboard-images)
- [Links and automation](#links-and-automation)
- [Command-line tool](#command-line-tool)
- [Tips for best results](#tips-for-best-results)

## Capturing text

1. Press **⌘⇧2**, or choose **Capture Text** from the Squint menu.
2. Drag over the text. This is the same selection tool as macOS's ⌘⇧4. Press **Esc** to cancel.
3. The text is on your clipboard. Paste it anywhere.

The menu bar icon briefly turns into a checkmark when the copy succeeds. If something goes wrong, the icon shows a warning triangle and the menu explains what happened.

## Code Mode and Plain Mode

Toggle **Code Mode** in the menu. It is on by default.

| | Code Mode | Plain Mode |
|---|---|---|
| Indentation | Preserved, snapped to the indent step used in the selection | Dropped |
| Blank lines | Preserved | Dropped |
| Spacing between words or columns | Preserved from on-screen gaps | Single space |
| Autocorrect | Off, so identifiers stay as written | On |
| Language | Latin script | Detected automatically |
| Missing closing brackets | Restored | Not applicable |
| Best for | Source code, terminal output, config files | Paragraphs, articles, other languages |

To override the toggle for a single capture, use a link such as `squint://capture?mode=plain`.

## QR codes and barcodes

Select a QR code or barcode, and its contents (for example a URL) are copied. If the selection contains a code, the code's contents take priority over any text around it, so select just the code.

## Clipboard images

Copied a screenshot from a chat or browser? Choose **Read Clipboard Image** from the menu, or open `squint://clipboard`. Squint reads the image on the clipboard and replaces it with the text it finds.

## Links and automation

Squint handles `squint://` links, so any launcher, automation tool or hotkey app can trigger it.

| Link | Action |
|---|---|
| `squint://capture` | Select a region and copy its text (uses the Code Mode toggle) |
| `squint://capture?mode=code` | Same, forcing Code Mode |
| `squint://capture?mode=plain` | Same, forcing Plain Mode |
| `squint://clipboard` | Read the image on the clipboard (accepts the same `mode` options) |

**From Terminal:**

```sh
open "squint://capture"
```

**Raycast:** create a Script Command with this content, then give it any hotkey in Raycast's settings.

```sh
#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Capture Code
# @raycast.mode silent
open "squint://capture?mode=code"
```

**Shortcuts:** add an **Open URLs** action with `squint://capture`, then choose **Add Keyboard Shortcut** in the shortcut's details.

**Alfred:** create a workflow with a Hotkey trigger connected to an **Open URL** action set to `squint://capture`.

This is also how to use a shortcut other than ⌘⇧2.

## Command-line tool

```text
usage: squint                       start the menu bar app
       squint [--plain] <image>     print the text in an image
       squint eval <directory>      score each x.png against x.txt (and x.textsniper.txt if present)
```

Examples:

```sh
squint screenshot.png                   # Code Mode
squint --plain scanned-page.jpg         # Plain Mode
squint screenshot.png | pbcopy          # straight to the clipboard
squint eval ~/squint-benchmark          # accuracy report; see evaluation.md
```

The exit status is `0` on success and `1` on error, with the error message on standard error.

## Tips for best results

- **Start the selection at the code's left margin.** Indentation is measured from the leftmost line in the selection. If you select only a deeply nested block, it comes out with that block at column 0.
- **Leave out line-number gutters.** Line numbers are text, so Squint copies them.
- **Bigger is better.** Zoom in on small text before capturing, especially in videos.
- **Include whole lines.** A partially selected line at the bottom edge can be mistaken for a missing closing bracket.
- **Monospaced fonts work best.** Indentation and spacing are reconstructed from character width, which assumes monospaced text.
