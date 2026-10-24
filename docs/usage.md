# Usage

- [Capturing text](#capturing-text)
- [Code Mode and Plain Mode](#code-mode-and-plain-mode)
- [Settings](#settings)
- [Spotlight, Siri and Shortcuts](#spotlight-siri-and-shortcuts)
- [QR codes and barcodes](#qr-codes-and-barcodes)
- [Clipboard images](#clipboard-images)
- [Links and automation](#links-and-automation)
- [Command-line tool](#command-line-tool)
- [Tips for best results](#tips-for-best-results)

## Capturing text

1. Press **⌘⇧2** (or your own shortcut), choose **Capture Text** from the Squint menu, or type "Squint" in Spotlight.
2. Drag over the text. This is the same selection tool as macOS's ⌘⇧4. Press **Esc** to cancel.
3. The text is on your clipboard. Paste it anywhere.

The menu bar icon briefly turns into a checkmark when the copy succeeds. If something goes wrong, it shows a warning triangle and the menu explains what happened. With VoiceOver, both outcomes are announced. Pressing the shortcut again while a capture is in progress does nothing, so you can't open two selections at once.

## Code Mode and Plain Mode

Toggle **Code Mode** in the menu or in Settings. It is on by default, and Squint remembers your choice.

| | Code Mode | Plain Mode |
|---|---|---|
| Indentation | Preserved, snapped to the indent step used in the selection | Dropped |
| Blank lines | Preserved | Dropped |
| Spacing between words or columns | Preserved from on-screen gaps | Single space |
| Editor line numbers | Removed | Kept |
| Autocorrect | Off, so identifiers stay as written | On |
| Language | Latin script | Automatic, or the one chosen in Settings |
| Missing closing brackets and docstring quotes | Restored | Not applicable |
| Best for | Source code, terminal output, config files | Paragraphs, articles, other languages |

To override the setting for one capture, use **Capture Code** or **Capture Plain Text** in Spotlight, or a link such as `squint://capture?mode=plain`.

## Settings

Open **Settings…** from the Squint menu (⌘,).

| Setting | What it does |
|---|---|
| **Shortcut** | Click it, then press a new combination that includes ⌘, ⌥ or ⌃. Esc cancels. If another app already uses the combination, Squint keeps the old one and says so. **Reset** returns to ⌘⇧2. |
| **Code Mode** | The default mode for captures |
| **Play a sound when text is copied** | Off by default |
| **Language** (Plain Mode) | Automatic, or a fixed language. On macOS 27, Vision reads 33 languages, including Hindi and Marathi. With Automatic, if you've added a language such as Hindi in System Settings › General › Language & Region, Squint also reads in it when detection is unsure, and keeps the more confident reading: Hindi mixed with English words comes out right, and Hinglish stays in Latin letters. |
| **Copy as Markdown** | Off by default. In Code Mode, copies the code in a fenced block with its language (` ```python `), ready for a README, a chat or an AI prompt. The language is left off when Squint isn't sure. |
| **Open links** | Off by default. Opens the first web address (http or https) in the copied text. |
| **Custom words** | Names and terms to spell exactly, separated by commas. A word one letter away from one of them, such as `Flaxmers` for `Flaxmere`, is corrected; words under four letters are left alone. |
| **Keep history** | Off by default. Keeps the last 20 captures so you can copy one again from the menu's **History**. They're stored only on this Mac, in `~/Library/Application Support/Squint/history.json`, readable only by you. **Clear History** deletes them, and turning history off deletes them too. |
| **Show in menu bar** | On by default. When hidden, use the shortcut or `squint://` links, and open Squint again (from Finder or Spotlight) to see Settings. |
| **Open at login** | Adds Squint to System Settings › General › Login Items |

## Spotlight, Siri and Shortcuts

Type **"Squint"** in Spotlight to see its actions:

| Action | What it does |
|---|---|
| **Capture Text** | Select an area and copy its text, using the Code Mode setting |
| **Capture Code** | Same, always in Code Mode |
| **Capture Plain Text** | Same, always in Plain Mode |
| **Read Clipboard Image** | Copy the text in the image on the clipboard |

The same actions are in the **Shortcuts** app under Squint, and each one **returns the captured text**, so a shortcut can pass it on: append it to a note, translate it, or open it in an editor. With Siri, say "Capture code with Squint".

**Requirement:** Spotlight, Siri and Shortcuts only run actions from apps signed with an Apple Team ID. Homebrew builds are ad-hoc signed, so these actions don't appear there (the menu, shortcut and `squint://` links all still work). To enable them, build from source with your Apple ID's free development certificate: `SQUINT_SIGN_IDENTITY="Apple Development" ./bundle.sh` (add the Apple ID in Xcode › Settings › Accounts first).

If the actions still don't show up, open Squint once and wait a moment while macOS indexes it. Type `squint`, not `squint://`: with the slashes, Spotlight treats it as a web address.

## Tables

On macOS 26 or later, **Capture Table** in the menu (or `squint://table`) reads a table, with or without ruled lines, and copies it as Markdown, or as tab-separated values that paste straight into Numbers or Excel (Settings › Tables). If the selection holds several tables, the largest is copied.

## Scroll capture

For code longer than the screen, such as a long file in a tutorial video:

1. Choose **Start Scroll Capture** from the Squint menu.
2. Capture the first part as usual, scroll, and capture the next part, overlapping by a line or two.
3. Each capture is joined to the text so far by the lines both show, without repeating them, and the whole is on the clipboard after every capture.
4. Choose **Finish Scroll Capture** when you're done.

If two parts share no lines, the second simply follows the first.

## QR codes and barcodes

Select a QR code or barcode, and its contents (for example a URL) are copied. If the selection contains a code, the code's contents take priority over any text around it, so select just the code.

## Clipboard images

Copied a screenshot from a chat or browser, or an image file in Finder? Choose **Read Clipboard Image** from the menu, or open `squint://clipboard`. Squint reads the image and replaces the clipboard with the text it finds. A copied file is read from a temporary copy, so the original is never changed.

## Links and automation

Squint handles `squint://` links, so any launcher, automation tool or hotkey app can trigger it.

| Link | Action |
|---|---|
| `squint://capture` | Select a region and copy its text (uses the Code Mode setting) |
| `squint://capture?mode=code` | Same, forcing Code Mode |
| `squint://capture?mode=plain` | Same, forcing Plain Mode |
| `squint://clipboard` | Read the image on the clipboard (accepts the same `mode` options) |
| `squint://table` | Capture a table (macOS 26 or later) |
| `squint://settings` | Open Settings |

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

**Alfred:** create a workflow with a Hotkey trigger connected to an **Open URL** action set to `squint://capture`.

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
- **Bigger is better.** Zoom in on small text before capturing. On the benchmark, errors rose from 2.9% on Retina screenshots to 3.6% on paused 720p video, and tiny or heavily blurred text fares worse.
- **Include whole lines.** A partially selected line at the bottom edge can be mistaken for a missing closing bracket.
- **Monospaced fonts work best.** Indentation and spacing are reconstructed from character width, which assumes monospaced text.
- **Check before running.** Squint gets most lines exactly right, but on the benchmark most captures still needed a small fix, usually one misread character. See [Evaluation](evaluation.md).
