---
name: log-food
description: Log what the user ate or drank to their MyFitnessPal diary through the MyFitnessPal Android app in an emulator, preferring their own saved recipes. Use whenever the user says what they ate ("I had 2 servings of the turkey chili for lunch", "log a banana", "ate a chicken burrito bowl for dinner", "log 150 g rice"), or asks to add food to MyFitnessPal.
---

# Log food to MyFitnessPal

Find the best match for each item (the user's own recipe first, otherwise the food database) and add it to the diary with the right amount and meal. Everything goes through the Android app with `${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh`. Read `${CLAUDE_PLUGIN_ROOT}/skills/enter-recipes/reference/ui-gotchas.md` and the project's `mfp-notes.md` (if any) before driving the app.

## Rules
- Never type passwords or sign in. A sign-in screen: stop and ask the user.
- Only one agent drives the emulator at a time.
- Don't change or delete diary entries other than the ones you're adding or fixing.

## 1. Parse the request
For each item:
- **Food** and **amount** (servings, grams, pieces, cups). Default to 1 serving.
- **Meal**: Breakfast, Lunch, Dinner or Snacks. If unstated, infer from the local time (before 11:00 Breakfast, 11:00-16:00 Lunch, 16:00-21:00 Dinner, else Snacks) and say you guessed.
- **Date**: today unless they say otherwise.

Ask first only when genuinely ambiguous ("some pasta"). Otherwise log it and say what you picked.

## 2. Get the app ready
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh" && (emu_ready || echo "not running")
```
Shell state doesn't persist between Bash calls: start every call that uses a helper with `source "${CLAUDE_PLUGIN_ROOT}/scripts/mfp.sh" &&`. If it isn't running, `emu_start` in the background. Then `mfp_launch`. If the emulator isn't set up at all, use the `setup-emulator` skill.

## 3. Open Log Food for the meal
1. `dump`, then `tapx buttonManageMyDay` (Today). For another date, change it here first.
2. Tap the blue **+**: in the `dump`, find the node whose content-desc is exactly `Add` and `tap` its centre (about `tap 929 2262` on 1080x2400; `tapx Add` can hit other "Add…" labels). Then `dump` and `tapx textBottomNavigationItem0` (Log Food).
3. `tapx selectMeal`, `dump`, `tapx <Meal>`.

## 4. Find the item
Check the user's own items first:
- **My Recipes** tab (`tapx "My Recipes"`, then `results`). Recipes created by `enter-recipes` carry the book's suffix, e.g. "Sample Turkey Chili (Weeknight Book)"; the book's `INDEX.md` lists the MFP names.
- **My Meals** and **My Foods** for saved meals and custom foods; the **All** tab's history for repeats.

Otherwise search: `tapx searchEditText`, `typ "<food>"`, `key 66`, wait ~3 s, `results`. Choose:
- The exact brand or restaurant when named.
- Verified entries, with a serving unit that fits the amount (a gram unit for "150 g").
- For whole foods, generic USDA-style raw/cooked entries. Sanity-check kcal per 100 g; user-submitted entries are often wrong.
- Don't use `quickLogAddRemoveIcon` (one-tap +): it can't set the amount.

## 5. Set the amount and add
1. Tap the row name (`tapx "<name>"`, escaping regex characters such as `( ) . +`, or a plain part of the name; if nothing happens, fresh `dump` and tap its `itemWithHeaderContainer`). Dismiss Premium popups with NO THANKS.
2. Unit: `tapx includeServingSizeContainer`, `dump`, tap the unit (`1.0 g`, `1.0 serving`, …).
3. Amount: `tapx includeNumberServingsContainer`, then `set_servings <n>` (with a `1.0 g` unit, n is grams; for a "2.0 pieces" serving, 3 pieces = 1.5).
4. `dump` and check `txtNoOfServings`, `txtServingSize`, `textEnergyValue`.
5. Confirm with the check mark at the top right (`confirm`; about `tap 996 209` on 1080x2400). Leave Food Details with it, not Back.

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/pick-result.sh" "<exact name>" "<serving text>"` opens a result by name and serving text (safer than by index, since result order can change), and `set-amount.sh "^1.0 g$" 150` sets unit and amount; check the kcal they print.

## 6. Verify and report
Back on the diary, `dump` (scroll with `swipe_up`) and confirm each entry sits under the right meal with the expected calories. Reply with one line per item: name, amount, meal, calories, and any guess you made. If something went in wrong, edit or delete that entry rather than adding a duplicate.

Subagents can look up nutrition or read recipe files in parallel, but do the UI work yourself (or hand all of it to one subagent).
