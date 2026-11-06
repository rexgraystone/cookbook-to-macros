---
name: enter-recipes
description: Create extracted cookbook recipes in MyFitnessPal through the Android app in an emulator, check MyFitnessPal's per-serving macros against the book's, and track status in INDEX.md. Use when the user asks to enter, add, create, import or upload recipes (or "the next N recipes", "the todo ones", a book) into MyFitnessPal, or to compare MFP macros with a cookbook's.
---

# Enter recipes into MyFitnessPal

Input: recipe files made by the `extract-recipes` skill, `recipes/<book>/pNNN-slug.md`, listed in `recipes/<book>/INDEX.md`. Output: saved MyFitnessPal recipes, an updated INDEX row per recipe, and a commit per recipe.

Read first, every run:
- `${CLAUDE_PLUGIN_ROOT}/skills/enter-recipes/reference/ui-gotchas.md` (screens, selectors, bulk-import quirks).
- `mfp-notes.md` in the project root, if it exists (lessons from earlier runs on this machine).

## Rules
- **Only one agent drives the emulator at a time.** Parallel adb taps and typing corrupt each other. Subagents may read PDFs or check nutrition, never touch adb while another agent does.
- Never type passwords or sign in. If a sign-in screen appears, stop and ask the user.
- Dismiss Premium popups with NO THANKS.
- Never delete or change a saved recipe or diary entry other than the one you're working on.
- If the emulator isn't set up, use the `setup-emulator` skill first.

## Shell
Shell state doesn't persist between Bash calls, so start every Bash call that uses a helper (`dump`, `tapx`, `adb_`, ...) by sourcing them:
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh" && emu_ready && dump
```
If `emu_ready` fails, run `emu_start` in the background (first boot takes 1-2 min). If adb isn't found or can't connect only inside the sandbox, rerun those commands with the sandbox disabled. `mfp_doctor` prints the paths in use.

### Scripts
These wrap the steps below; run them with `bash "${CLAUDE_PLUGIN_ROOT}/scripts/<name>"` from the project folder. Each sources `mfp.sh` itself and exits non-zero on failure, so chain them with `&&` or `|| exit 1`, never through `| head` or `| grep`.

| Script | Where | What |
|---|---|---|
| `new-recipe.sh <file.md>` | Recipes list (top, search empty) | Create a Recipe → fill → Next → `review-rows.sh`. 2-5 min: long timeout or background. |
| `fill-recipe.sh <file.md> [skiphead]` | New Recipe form | Types the MFP name, the leading number of Makes, turns on bulk import and types the lines word by word. Refuses non-ASCII text. |
| `review-rows.sh` | Review Ingredients | Every row as `title \| amount \| kcal \| original line`, Unmatched rows marked. |
| `open-row.sh "<title regex>" ["<food regex>"]` | Review Ingredients | Opens a row's Food Details; exit 1 = not found, 2 = wrong food opened. |
| `pick-result.sh "<exact name>" "<detail text>"` | Search results | Opens the result matching name and serving text (not by index). |
| `set-amount.sh "<unit regex>" <n>` | Food Details | Picks the unit, sets the amount, prints kcal and macros. Then `confirm`. |
| `record-result.py <book> <file.md> <status> "<NNN cal · NNP · NNC · NNF>" "<note>" <entry.md>` | anywhere | Updates the INDEX row and appends `## MFP entry`; refuses `done` when calories are more than 10% off. |

## Pick the work
1. Read the book's `INDEX.md`. Work on rows with Status `todo` (or the ones the user named), in page order.
2. More → Recipes, Meals & Foods → **Recipes** tab: if a recipe with the same MFP name already exists (an interrupted run), review and fix it instead of creating a duplicate.

## Per recipe
1. **Create and bulk import**: on the Recipes list, `new-recipe.sh recipes/<book>/<file>.md` (or by hand: Create a Recipe → Enter Ingredients Manually; name = `MFP name`; servings = **only the leading number** of `Makes`; turn on Bulk Import Ingredients; `typ "<line>"`, `key 66` per line; **Next**). Before Next, check the typed name and lines with `focused_text`.
2. **Review every row** (`review-rows.sh`). For each row check:
   - the food type is right (raw/dry/canned/cooked, lean %, fat level, the brand when the book names one), and it's an ingredient, not a dish that shares a word;
   - the amount is the grams from the line, not cups, slices, tbsp or a count;
   - kcal per 100 g is plausible, carbs/fat/protein aren't suspiciously 0, and kcal roughly equal 4·C + 4·P + 9·F;
   - repeated bulk lines didn't merge into one row with a single line's amount.
   Fix wrong or unmatched rows as `ui-gotchas.md` describes (`open-row.sh` → Replace Ingredient → `pick-result.sh` → `set-amount.sh` → `confirm`). **Wait ~8-10 s after each `confirm`** before the next scroll or script; the review list re-renders and early swipes open random rows. After every fix, re-check that row's kcal: gram units can be broken.
3. **Next** → on the summary check `name_input` (nothing dropped), `servings_input` equals the Makes number, and read per-serving calories, carbs, fat, protein → **Save**. Then `dump` and confirm `name_text` is present; if not, the Save tap didn't register, so tap Save again. Confirm the recipe is on the Recipes tab.
4. **Compare** with the file's `Book per serving`, as a percentage of the book's calories:
   - Within ±10%: `done`.
   - More than 10% off: find the cause (a wrong entry, a misread gram figure, a count read as cups, a merged duplicate). Fix and recheck. If it's still off and every entry looks right, keep the saved recipe and mark it `flagged` with the likely cause in one line (for example "book's macros fit 14 servings, not 12" or "breading has no amounts and is left out"). **Over 10% is always `flagged`, never `done`**, even at 10.5% and even when you trust MFP more than the book.
   - Macros wildly off with calories close (or the reverse) also deserve a one-line note.
   - Can't be entered at all (needs a food MFP lacks, recipe is a template): `skipped` plus a reason.
5. **Record**:
   - Write the MFP entry to a temp file (date saved, the per-serving result, every substitution: which entry you chose for a tricky item and why, with its kcal), then `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/record-result.py" <book> <file.md> <status> "<NNN cal · NNP · NNC · NNF>" "<note or ''>" <entry file>`. It sets the INDEX row's Status and `MFP per serving` (plus the note) and appends `## MFP entry` to the recipe file. Or do the same by hand.
   - New UI lessons: one line each in `mfp-notes.md` at the project root.
6. **Commit** (if the project is a git repo), staging only the files you changed, since other agents may have unfinished files under `recipes/`:
   ```bash
   git add recipes/<book>/INDEX.md recipes/<book>/<file>.md && git commit -m "Add <recipe name> to MyFitnessPal"
   ```
   Add `mfp-notes.md` to the `git add` only if you changed it (a missing path makes `git add` fail). Push only if the user asked for it.

If the app gets into a bad state, see "Freezes and crashes" in `ui-gotchas.md`, then `mfp_launch`. If an unsaved recipe is lost, start that recipe again.

## Batches
Long runs fill your context with UI dumps. For more than a few recipes, hand them to **sequential** subagents, about **10 recipes each (up to 15 when the recipes are short, under ~10 bulk lines)**, starting the next only after the previous one returns. Never run two at once. Each brief should say:
- the book folder and the exact recipe files to do;
- "Use the `enter-recipes` skill; read its `reference/ui-gotchas.md` and the project's `mfp-notes.md`";
- that it is the only agent driving the emulator, must not sign in, and must commit per recipe;
- the status rule: more than 10% off the book's calories is `flagged` with a note, never `done`;
- to return one line per recipe: file, status, MFP per serving, % off, note, plus any new UI lessons.

Between batches, read the returned lines, spot-check one INDEX row and one saved recipe's servings, and stop to ask the user if several recipes came back flagged for the same reason.

## Report
When done, give the user a table: recipe, book per serving, MFP per serving, status, note. Call out flagged rows and what you'd need from them (for example the real serving count).
