# cookbook-to-macros

**Turn any cookbook into MyFitnessPal recipes, check the book's macros, and log meals: a Claude Code plugin.**

You give Claude a cookbook PDF. It pulls every recipe out with exact gram weights, creates each one as a recipe in your MyFitnessPal account, compares MyFitnessPal's per-serving numbers with the ones the book prints, and tells you which recipes don't add up and why. After that, "I had 2 servings of the turkey chili for lunch" is all it takes to log a meal.

> **Not affiliated with MyFitnessPal.** Automating the MyFitnessPal app may conflict with its terms of service. Use this only on your own account, at your own risk. Cookbooks are copyrighted: use it only with books you own, keep the extracted recipes private, and don't redistribute them. This repo contains no cookbook content.

## What it does

| Step | You say | Claude does |
|---|---|---|
| **1. Set up** | "Set up the Android emulator for MyFitnessPal." | Installs the Android SDK pieces, creates a virtual phone, installs the MyFitnessPal app. **You** sign in to Google and MyFitnessPal yourself; Claude never types passwords. |
| **2. Extract** | "Extract the recipes from `my-book.pdf`." | Writes one Markdown file per recipe (ingredients as printed, gram-based import lines, servings, the book's macros) and an `INDEX.md` status table for the book. Checks page images for grams and macros, converts counts ("3 onions") to grams, expands sub-recipes, and notes where the book's own numbers look wrong. |
| **3. Enter** | "Enter the next 10 todo recipes into MyFitnessPal." | Creates each recipe in the app, reviews every matched ingredient (wrong entries, broken units, 0-kcal spices), saves it, compares it with the book, and marks it `done` (within 10%), `flagged` (with the likely cause) or `skipped`. Commits after each recipe. |
| **4. Log** | "I had 1.5 servings of the turkey chili for dinner." | Finds your recipe (or a database entry), sets the amount, logs it to the right meal, and checks it landed. |

### Why an emulator?
When this was built, MyFitnessPal's website wouldn't save recipes, so everything goes through the official Android app running in the Android emulator, driven over `adb`. The free MyFitnessPal tier is enough.

### What to expect
- **Accuracy:** in testing on three cookbooks (311 recipes), about two-thirds came within 10% of the book. Nearly all of the rest were the book's own arithmetic: macros that don't add up to the printed calories, sauces or toppings left out of the totals, or serving counts that don't fit the numbers. Every flagged recipe gets a one-line reason.
- **Speed:** a few minutes per recipe, since Claude drives the app screen by screen. A batch of 10 takes about an hour. Big cookbooks are an overnight job.
- **Fragility:** the app's layout can change with updates. See [Limitations](#limitations).

## Requirements
- [Claude Code](https://code.claude.com).
- Windows (with Git Bash), macOS or Linux, with hardware virtualization enabled and about 10 GB of free disk.
- Python 3 with PyMuPDF: `pip install pymupdf`.
- Java 17+ and the Android SDK command-line tools. The `setup-emulator` skill installs these with you.
- A MyFitnessPal account (free tier is fine).

## Install
In Claude Code:
```
/plugin marketplace add rexgraystone/cookbook-to-macros
/plugin install cookbook-to-macros@cookbook-to-macros
```
Or try it from a local clone without installing: `claude --plugin-dir /path/to/cookbook-to-macros`.

You normally just ask in plain words and Claude picks the right skill. They're also available directly as `/cookbook-to-macros:setup-emulator`, `:extract-recipes`, `:enter-recipes` and `:log-food`.

## Quick start
Work in a folder that holds your cookbook PDF, ideally a **private** git repo so progress is saved.

1. "Set up the Android emulator for MyFitnessPal." Sign in when Claude asks.
2. "Extract the recipes from `my-book.pdf`; call the book `weeknight` and add `(Weeknight Book)` to the MyFitnessPal names."
3. "Enter the next 10 todo recipes from weeknight." Repeat, or ask Claude to keep going in batches until the book is done.
4. "I had a serving of the turkey chili for lunch."

See [`examples/`](examples/) for an invented recipe file and index.

## How it works
| Piece | What it does |
|---|---|
| `skills/setup-emulator` | Cross-platform SDK, emulator and MyFitnessPal install, window sizing, and a final check. |
| `skills/extract-recipes` | Rules for turning a page into a recipe file, a table of standard count weights, and `scripts/pdf_pages.py` (PyMuPDF) for column-aware page text, titles, search and page renders. Several books can be extracted in parallel with subagents. |
| `skills/enter-recipes` | The per-recipe procedure in the app, status rules, the 10% check, commit per recipe, and batching through one subagent at a time. `reference/ui-gotchas.md` collects the app's quirks and how to recover from emulator freezes. |
| `skills/log-food` | Turns "I ate …" into a diary entry. |
| `scripts/mfp.sh` | Bash helpers for driving the app: read the screen (`dump`), tap by text or id (`tapx`), type, scroll, set servings, screenshots, start the emulator, health check (`mfp_doctor`). Coordinates scale to the device's screen. |
| `scripts/*.sh`, `scripts/record-result.py` | Step scripts for creating a recipe from its file, reviewing and fixing ingredient rows, and recording the result in `INDEX.md` with a strict 10% status check. |

Only one agent may drive the emulator at a time; parallel taps corrupt each other. PDF reading and nutrition checks can run in parallel.

This is a plugin made of skills and scripts, not an MCP server: Claude follows the skills and runs the scripts with its normal tools, which lets it use judgment on bad database matches and app hiccups.

### Configuration
Set these in your shell, or in your project's `.claude/settings.json` under `env`:

| Variable | Default |
|---|---|
| `ANDROID_SDK_ROOT` (or `ANDROID_HOME`) | Windows `%LOCALAPPDATA%\Android\Sdk`, macOS `~/Library/Android/sdk`, Linux `~/Android/Sdk` |
| `MFP_AVD` | `MFP_Pixel` |
| `MFP_SERIAL` | adb's default device |
| `MFP_PKG` | `com.myfitnesspal.android` |
| `MFP_TMP` | `<temp>/mfp` (screen dumps, screenshots) |
| `MFP_PYTHON` | `python3`, else `python` |

**Windows notes:** if the SDK was installed from inside an MSIX-packaged app, Windows may have redirected it to `%LOCALAPPDATA%\Packages\<App>_*\LocalCache\Local\Android\Sdk`; `mfp.sh` checks there too. If Claude Code's sandbox hides the SDK or blocks adb, those commands need to run outside the sandbox.

## Limitations
- **App updates can break things.** Element ids, button labels, menu paths and a few fallback coordinates were observed on one late-2026 app version on a 1080x2400 screen. After an app update, re-check the items listed in `skills/enter-recipes/reference/ui-gotchas.md`.
- **MyFitnessPal's bulk import is quirky.** It reads bare counts as cups, merges duplicate lines, and often picks entries with wrong or missing macros. The skills convert counts to grams and review every row, but expect several fixes per recipe.
- **Database entries vary in quality.** User-submitted entries are often wrong. The skills check calories per 100 g and the macro sum, but a result is only as good as the entries chosen.
- **The emulator is not always stable.** Expect occasional app freezes or emulator crashes on long runs; the gotchas file covers recovery, and an unsaved recipe is simply redone.
- **Setup is the least-tested part.** The setup skill was written from a working install, not yet run end to end on a fresh machine. Reports welcome.
- Premium features aren't used, and Premium popups are dismissed.

## Privacy
Nothing leaves your machine except what Claude Code sends to the model and what the MyFitnessPal app syncs to your account. Your extracted recipes stay in your project folder. Don't commit cookbook PDFs or extracted recipes to a public repository.

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md). Reports of UI changes in new app versions are the most useful.

## License
MIT. See [LICENSE](LICENSE).
