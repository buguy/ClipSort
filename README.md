# ClipSort

**AI-powered clipboard organizer.** Press one hotkey to automatically classify and save your clipboard content — text or screenshots — into the right folder.

Works great with Obsidian, Logseq, Notion (local), or any folder-based note system.

![Windows](https://img.shields.io/badge/platform-Windows-blue)
![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2.0-green)
![License](https://img.shields.io/badge/license-MIT-yellow)

## How It Works

```
Ctrl+Shift+D
    │
    ├─ Text?  → Send to AI → Get folder + title → Save as .md
    │
    └─ Image? → Save PNG → Resize → Base64 → Send to AI Vision
                                              → Get folder → Save as .png
```

1. Copy text or take a screenshot to your clipboard
2. Press **Ctrl+Shift+D**
3. AI reads your content, picks the best folder, and saves it automatically
4. A notification tells you where it was saved

ClipSort scans your folder structure each time, so the AI always knows your current organization. If no existing folder fits, it creates a new one.

## Features

- **Text + Image support** — Automatically detects clipboard type
- **AI Vision** — Screenshots are analyzed visually, not just OCR
- **Two-level folder scanning** — AI sees both parent and sub-folders
- **Auto-create folders** — AI suggests new folders when needed
- **No app lock-in** — Just saves files to folders. Works with any app that reads local files
- **Tiny cost** — ~$0.08/month for text, ~$0.30/month for heavy screenshot use
- **Debug mode** — Ctrl+Shift+Alt+D shows raw AI response

## Requirements

- **Windows 10/11**
- **[AutoHotkey v2.0+](https://www.autohotkey.com/)**
- **[OpenRouter](https://openrouter.ai/) account + API key** (pay-as-you-go, no subscription)

## Quick Start

### 1. Get your API key

Sign up at [OpenRouter](https://openrouter.ai/), add a few dollars of credits, and create an API key at [Settings → Keys](https://openrouter.ai/settings/keys).

### 2. Configure

Open `ClipSort.ahk` in a text editor and set your values:

```ahk
VAULT_PATH := "D:\Notes"                             ; Any folder path
OPENROUTER_API_KEY := "sk-or-v1-xxxxxxxxxxxx"        ; Your API key
MODEL := "google/gemini-2.5-flash-lite"              ; Default model
```

`VAULT_PATH` can be any folder — your Obsidian vault, a Logseq graph, a Dropbox folder, or just `C:\Users\you\Documents\Notes`.

### 3. Set up folders (optional)

Run `InitFolders.ahk` once to create a starter folder structure, or skip this and let AI create folders on the fly.

Edit `InitFolders.ahk` to customize the folders before running:

```ahk
VAULT := "D:\Notes"  ; Same path as VAULT_PATH above

folders := [
    "Tech", "Tech\Coding", "Tech\Gadgets",
    "Finance", "Finance\Investing",
    "Health", "Health\Fitness",
    ; Add your own...
]
```

### 4. Run

Double-click `ClipSort.ahk`. You'll see the AutoHotkey icon in your system tray.

### 5. Use

| Action | Steps |
|---|---|
| **Save text** | Copy text (Ctrl+C) → Press **Ctrl+Shift+D** |
| **Save screenshot** | Screenshot to clipboard (PicPick / PrintScreen) → Press **Ctrl+Shift+D** |
| **Debug mode** | Press **Ctrl+Shift+Alt+D** to see AI's raw response |

### 6. Auto-start (optional)

Press `Win+R` → type `shell:startup` → place a shortcut to `ClipSort.ahk` there.

## Output Format

### Text notes (.md)

```markdown
# AI-generated title

- **Created**: 2026-04-13 12:00:00
- **Category**: AI/Tools

---

(your copied text)
```

Filename: `20260413_120000_Tools.md`

### Screenshots (.png)

Saved directly as PNG. Filename: `20260413_135012_Budgeting.png`

Images are automatically resized to max 800×800px before sending to AI (to reduce API payload).

## Cost

Using Gemini 2.5 Flash Lite via OpenRouter (pay-per-token, no subscription):

| Type | Per use | 50/day | Monthly |
|---|---|---|---|
| Text | ~$0.00005 | $0.0025 | ~$0.08 |
| Screenshot | ~$0.0002 | $0.01 | ~$0.30 |

Monitor usage at [OpenRouter Activity](https://openrouter.ai/activity).

## Alternative Models

Change the `MODEL` variable in the script:

| Model | ID | Vision | Cost/month |
|---|---|---|---|
| **Gemini 2.5 Flash Lite** (default) | `google/gemini-2.5-flash-lite` | ✅ | ~$0.08 |
| Gemma 4 26B | `google/gemma-4-26b-a4b-it` | ✅ | ~$0.10 |
| Llama 3.3 70B | `meta-llama/llama-3.3-70b-instruct` | ❌ | ~$0.08 |
| Llama 3.3 70B (free) | `meta-llama/llama-3.3-70b-instruct:free` | ❌ | $0 |

> **Tip:** Text-only models are slightly more accurate for text classification. Use a vision model only if you need screenshot support.

## Compatible Apps

ClipSort saves standard `.md` and `.png` files to regular folders. Any app that reads local files will work:

- **[Obsidian](https://obsidian.md/)** — Point your vault to the ClipSort folder
- **[Logseq](https://logseq.com/)** — Use as your graph directory
- **[Typora](https://typora.io/)** — Open the folder directly
- **VS Code** — Great for browsing markdown files
- **Any file manager** — It's just files in folders

## Configuration

### Ignored folders

These folders are excluded from AI's options (edit `ScanFolderTree` in the script):

- Hidden folders (starting with `.`)
- `attachments`, `Clippings`, `templates`, `Inbox`

### Adding folders

Just create new folders in your target directory — ClipSort scans the latest structure every time you press the hotkey.

## Troubleshooting

| Problem | Solution |
|---|---|
| "Clipboard is empty" | Content might be rich text. Try pasting to Notepad first, then re-copy. |
| "Failed to save image" | Make sure your screenshot tool copies to clipboard (not to a file). |
| Everything goes to Inbox | Use Debug mode (Ctrl+Shift+Alt+D) to check AI response format. |
| Text vs screenshot classify differently | Normal — text classification is more accurate. Use text when possible. |
| HTTP 400 error | Check API key. Some models may have provider issues — try the default model. |

## How It Works (Technical)

- **Clipboard detection**: Win32 `IsClipboardFormatAvailable` API (CF_BITMAP / CF_DIB)
- **Image capture**: PowerShell with `-STA` flag to access GUI clipboard
- **Image processing**: Auto-resize via `System.Drawing` to reduce API payload
- **Base64 encoding**: PowerShell `[Convert]::ToBase64String`
- **AI API**: OpenRouter (OpenAI-compatible) chat completions with vision support
- **File encoding**: UTF-8 without BOM via `ADODB.Stream`
- **Response parsing**: Regex-based extraction of `FOLDER:` and `TITLE:` from any response field

## License

MIT
