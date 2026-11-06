# MyFitnessPal Android app: UI notes and gotchas

Shared by `enter-recipes`, `log-food` and `setup-emulator`. These were observed on one late-2026 build of the Android app on a 1080x2400 Pixel-style emulator, over a few hundred recipes. Resource-ids, labels and coordinates can change with app updates; if a selector stops matching, `dump` and look for the new name. Record your app version with:

```bash
adb_ shell dumpsys package com.myfitnesspal.android | grep versionName
```

Project-specific lessons go in `mfp-notes.md` in the project root (read it before driving the app; add one line per new lesson).

Sections: Helpers · Navigation · Resource-ids · Text fields and keyboard · Recipe creation · Bulk import quirks · Bad auto-match patterns · Units and amounts · Search, scrolling and timing · Fixing rows · Save · Freezes and crashes · Script pitfalls · Diary

## Helpers (`scripts/mfp.sh`)
- Shell variables and functions don't persist between Bash tool calls, so start every call with `source "<plugin>/scripts/mfp.sh" &&` (the skills give the full path).
- `dump` prints one line per visible node: text, content-desc, resource-id, bounds, flags. Call it again whenever the screen changes; `tapx` and `results` use the last dump. It retries a few times and never leaves a stale screen behind: if it prints "dump failed", the app is probably hung (see Freezes and crashes).
- `tapx <regex> [n]` matches against "text content-desc resource-id" joined with spaces. Don't anchor with `^…$` and don't include quote characters. It's a regex: escape `( ) . + ? [ ]` in names (`Turkey Chili \(Weeknight Book\)`) or match a plain part of the name.
- `tapr X Y`, `swipe_slow X1 Y1 X2 Y2 [ms]` and `confirm` take 1080x2400 coordinates and scale them to the device. `hide_kb`, `scroll_top`, `clear_field` and `food_header` cover the common moves below.
- `shot <name>` saves a screenshot and prints its path; open it with the Read tool. Read may show it scaled down (for example 900 px wide for a 1080 px screen), so scale coordinates back up before tapping.
- Test ads are filtered out of `dump`. Never tap ads.

## Navigation
- Launch or relaunch with `mfp_launch`. If the app is in a bad state, relaunch rather than pressing Back repeatedly.
- Pressing Back twice from a picker can leave the app (it has opened the Play Store before).
- On ingredient and food search screens, pressing Back (`key 4`) while the keyboard is already hidden closes the whole search. Don't press Back just to hide the keyboard; use `hide_kb`.
- **Never press Back in Food Details opened from a Review Ingredients row**: it drops the whole review list ("No Ingredients"). If it happens, press Back once more to reach the form (the bulk text is kept) and tap Next to re-match. Leave Food Details with `confirm` (the check mark).
- Premium upsells ("Feature Highlight", "Go Premium", trials): tap **NO THANKS** or close. Recipe creation and logging work on the free tier.
- A sign-in or "session expired" screen: stop and ask the user to sign in. Never type credentials.

## Observed resource-ids (re-check after app updates)
| Where | id / label | Use |
|---|---|---|
| Bottom bar | `buttonManageMyDay` | Today / Dashboard |
| Today | content-desc `Add` (blue +, bottom right) | Add menu |
| Add menu | `textBottomNavigationItem0` | Log Food |
| Log Food | `selectMeal` | Meal picker (Breakfast/Lunch/Dinner/Snacks) |
| Search | `searchEditText` | Search field |
| Search results | `text_primary` / `text_secondary` | Name / detail (what `results` prints) |
| Search results | `itemWithHeaderContainer` | Whole row, if tapping the name does nothing |
| Search results | `quickLogAddRemoveIcon` | One-tap add of the default serving. Avoid it |
| Recipes list | `btn_add_item` | Create a Recipe |
| New Recipe form | `inputName`, `inputServings`, `switchBulkImport`, `inputIngredients` | Name, servings, bulk toggle, bulk text |
| Review Ingredients | `title`, `info`, `calories`, `original_text` | Row food, amount, kcal, the bulk line it came from |
| Recipe summary | `name_input`, `servings_input`, `calories_per_serving` | Check before Save |
| Saved recipe | `name_text` | Present once Save has registered |
| Food details | `txtFoodName`, `txtNoOfServings`, `txtServingSize`, `textEnergyValue`, `tv_macro_value` | Read back before confirming (`food_header`) |
| Food details | `includeServingSizeContainer` | Unit picker (`1.0 g`, `1.0 serving`, …) |
| Food details | `includeNumberServingsContainer` | Opens the "How Much?" dialog |
| "How Much?" | `numOfServings`, `serving_size`, `button1` | Amount field, unit spinner (items are `text1`), Save |
| Recipe edit mode | `check_box` | Row selection (state not shown by `dump`) |
| System dialog | `aerr_close` | "… isn't responding": Close app |

The confirm check mark on food-detail screens is at the top right (`confirm`, about `tap 996 209` on 1080x2400); `tapx Add` hits the "Add Food" title instead. On the review list the same spot is the **Edit** button, which opens "Select Item" mode (close it with the X at about `tapr 73 209`). Only fire `confirm` when Food Details is really open.

## Text fields and keyboard
- `typ` drops apostrophes; `%`, double quotes and non-ASCII letters (ñ, é) are unreliable, and a word with a non-ASCII letter can vanish silently. Write "93 lean", "2 milkfat", "nonfat", "jalapeno".
- Long `input text` strings can be cut at about 18 characters (seen after an emulator soft reboot). Type word by word (`fill-recipe.sh` does) and check the result with `focused_text`.
- Clear a field with `clear_field` (select all + delete; Android 13+). Long runs of `key 67` (25+ deletes) in a search box have ANR'd the app.
- Tapping a prefilled field puts the cursor mid-text; `key 123` moves it to the end.
- In the "How Much?" dialog the number usually arrives selected, but after picking a unit the selection can be lost and typing appends ("1" + "5.5" = "15.5"). `set_servings` selects all first and warns if the field doesn't show what it typed.
- In search results the keyboard covers the lower rows, and a tap there types a letter into the search box. `hide_kb` (a short slow scroll) first. The keyboard comes back after leaving Food Details.
- The keyboard can flip to a GIF/emoji panel that swipes don't dismiss, and taps land on it. Check `adb_ shell dumpsys input_method | grep mInputShown` and tap the panel's hide chevron (find it with `shot`).
- If typed text lands in a Google search page, a tap missed and focus went to the Google app: `adb_ shell am force-stop com.google.android.googlequicksearchbox`, `mfp_launch` and retry.

## Recipe creation
- Path: More → **Recipes, Meals & Foods** → **Create a Recipe** (`btn_add_item`) → **Enter Ingredients Manually**. The **Recipes** tab on the same screen lists saved recipes.
- The website did not save recipes at the time of writing, which is why everything goes through the app.
- Servings: type **only the leading number** of the book's Makes. "5 (per bowl)" typed whole became 590 servings. Check `servings_input` on the summary.
- If you searched the Recipes list, clear the box and hide the keyboard first; otherwise the Create tap misses and the bulk text goes into the search box.
- After Save, the Recipes list can take a couple of seconds to load; wait before the next Create.
- To fix a saved recipe: open it → More options → **Edit Recipe** → tap the row → Replace Ingredient → Save.

## Bulk import quirks
- Type one ingredient per line (`typ "<line>"`, then `key 66`). Lines of the form `<grams> g <description>` match most reliably. Don't type markdown code fences: a "```" line becomes an Unmatched row.
- **Count words are read as cups**: "3 chipotle peppers" became 3 cups, "3 medium onion" 3 cups chopped. Convert counts to grams before importing, or replace the row with a per-piece entry and set the number of servings to the count.
- **"N g … slice(s)" lines import as N slices** of the entry: a few grams of cheese or pickle slices became dozens of slices and thousands of kcal. Replace with an entry that has a gram unit, or use the count.
- **Grams can turn into the entry's own unit** ("30 g breadcrumbs" → 2 tbsp, "5 g fish sauce" → 5 tbsp). Check the amount column, not only the kcal.
- **Duplicate lines can merge** into one row carrying a single line's amount (two "20 g sauce" lines → one 20 g row). It happens only sometimes; for every repeated line, check whether you got one row or two and fix the amount.
- It picks the nearest lean percentage it knows (90% for 93% lean beef). Check every meat row.
- Flavour and prep words shift matches: "fire roasted" corn matched an entry at about double plain corn's kcal.
- Some lines come back **Unmatched** (no kcal, listed at the top of the review list): often lines with "milkfat", brand-style names, or reduced-fat cheese slices. Save warns that unmatched rows will be dropped.

## Bad auto-match patterns
Check **kcal per 100 g and carbs/fat/protein** on every row. Patterns that came up again and again:
- **Spices at 0 kcal**: garlic/onion powder, cumin, black pepper, sage and seasoning blends by tsp/tbsp often match a brand entry with 0 kcal. Generic entries such as "Garlic powder" (1 tsp ≈ 10), "Cumin, ground" (1 tsp ≈ 8-10), "Onion powder", "Black pepper" and "Coriander - Ground" are fine. The reverse happens too: a spice entry whose tsp is hundreds of kcal.
- **Dishes instead of ingredients**: "black pepper" → a black pepper chicken dish; "sriracha" → sriracha popcorn; "butter" → a nut butter; "bacon cooked" → a fast-food burger; "garlic minced" → a salsa; "ginger puree" → a carrot soup. Read the name, not just the kcal.
- **Cooked vs dry/raw**: "orzo dry", "linguine dry", "rigatoni dry", "rice dry", "ramen noodles dry" can match cooked entries (~70-160 kcal/100 g instead of ~350-370). "Pasta, dry" with a `1.0 g` unit is a safe generic.
- **Wrong variant or fat level**: "whole milk" → 2%; "light butter" → a popcorn flavour; "light mayonnaise" → full-fat; "soy sauce" → sweet soy; "dark soy sauce" → plain soy; "protein pasta" → regular pasta; "frozen diced potatoes" or "french fries" → pre-fried; "roasted red peppers jarred" → oil-packed; "garlic/ginger paste" → oil-based.
- **"2 milkfat" / "reduced fat" confusion**: shredded reduced-fat cheese matched a yogurt or a milk; "cottage cheese 2 milkfat" and "greek yogurt 2 milkfat" hit entries with too little protein or carbs and protein swapped. Pick the entry whose macros look like the food.
- **Kcal that don't match the macros** (check 4·C + 4·P + 9·F ≈ kcal), USDA-named entries with 0 g carbs or fat, and "thigh" entries carrying breast macros.
- **Store-brand entries for generic foods** ("sugar" → 2 kcal per 15 g, "canned tomatoes" at half the usual kcal, a honey entry at 350/100 g). Prefer USDA-style generic entries: "Granulated sugar", "Butter, salted", "Oil, olive", "Tomatoes - Crushed, canned", "Milk, Whole, 3.25% Milkfat", "Garlic, Raw", "Ginger Root (Raw)", "Peppers, ancho, dried", "Enchilada sauce, red".
- **Meat cuts**: "brisket flat lean" matched untrimmed brisket; "chicken breast raw" and "boneless skinless chicken thigh raw" each hit several entries from about 97 to 165 kcal/100 g. Search the USDA-style name (e.g. "Chicken Thigh, Boneless, Skinless, Raw (Generic)", ~120 kcal/100 g) and note the entry you trust in `mfp-notes.md`.
- **Tortillas and buns by grams** often match 290-340 kcal/100 g entries. Use a per-piece entry × count, the brand's when the book names one.
- Search results change over time: an entry you used last week may stop showing. Search its exact name, scroll, or use an equivalent with the same per-100 g macros.

## Units and amounts
- **An entry's gram unit can be broken** (a sauce whose "1 g" = 32 kcal; a cheese whose gram unit is a whole cup; a butter whose 15 g = 25 kcal). Always check the row's kcal after setting the amount.
- Some entries have no gram unit (a can, a tbsp, a slice). Convert: 420 g of soda with only a 355 ml can unit ≈ 1.18 cans; 100 g soy sauce ≈ 5.5 tbsp.
- Drained canned beans: prefer a "drained and rinsed" entry by can rather than cutting grams on a whole-can entry (drained beans are denser).
- The unit list opens scrolled to the current unit, so units above it are hidden; `set-amount.sh` scrolls both ways. Anchor unit regexes: `^1.0 g` also matches "1.0 gallon"; use `^1.0 g$` or `^1.0 (g|gram)$`.
- On entries with a two-line title the amount sometimes didn't change; use `tapx includeNumberServingsContainer; set_servings N` and re-read `txtNoOfServings`.
- Two entries with near-identical names can list different default units (1 tbsp vs 1 tsp at the same kcal). Read the serving text in the result row.

## Search, scrolling and timing
- **Result order can change** between two `results` calls for the same query, so picking by index can open the wrong entry. Match by name and serving text from a fresh dump (`pick-result.sh`) and check `txtFoodName` before setting the amount.
- Results can load partially if read too soon. Wait ~5 s after Enter; if an expected entry is missing, tap the box, `key 123`, `key 66` and wait ~7 s.
- `hide_kb` can scroll the top result off-screen; `swipe_slow 540 900 540 1500 600` brings it back.
- If `tapx text_primary N` doesn't open a result, take a fresh `dump` and tap that row's `itemWithHeaderContainer`.
- **Fast swipes (≤150 ms) on the review list register as taps** and open a row. Scroll it with 600-800 ms swipes (`swipe_slow`, `scroll_top`); fast ones also stall short of the top on long lists and hide the Unmatched rows.
- **After `confirm` from Food Details, wait ~8-10 s** before scrolling or dumping the review list. It re-renders and shifts; swipes during that time opened random rows, a stale dump opened the wrong row's Replace screen, and once the whole review list vanished. Dump, check the list is still there, then continue.
- Many quick searches in a row (7+ with no pause) froze the emulator. Leave ~4 s between searches.
- Titles can contain non-breaking spaces. `tapx` and the scripts treat them as spaces; in your own regexes, use `.*` between words if a match fails.

## Fixing rows
- **Replace Ingredient** (fastest): tap a matched row in Review Ingredients → Food Details → Replace Ingredient. The search box is prefilled with the bulk line; `clear_field`, then `typ` the new query.
- **Unmatched row**: tap the row (it opens a search directly) → pick an entry → set unit and amount → `confirm`. If an Unmatched row disappears after a failed pick, re-add it with the top-right Add Ingredient button.
- **Delete rows**: **Edit** → tick the rows → trash icon. Edit-mode checkbox state isn't shown in `dump`: take a `shot`, or read the `checked` attribute in `$MFP_TMP/ui.xml`, before deleting.
- **Add a row**: **Add Ingredient** → search → pick → unit `1.0 g` and the grams → `confirm`.

## Save
- After **Next**, the summary shows the name, servings and per-serving calories and macros. Check `name_input` (ASCII only, nothing dropped) and `servings_input` before Save.
- **The Save tap sometimes doesn't register.** After it, `dump` and look for `name_text` (the saved recipe's screen); if it's missing, tap Save again. Then confirm the recipe is on the Recipes tab.

## Freezes and crashes
The unsaved recipe is usually lost in these cases; redo it from the start.
- **App not responding (ANR)**: dumps fail or go stale, or the screen is black. Check `adb_ shell dumpsys window | grep mCurrentFocus`. `adb_ shell am force-stop com.myfitnesspal.android`, then `mfp_launch`. A "System UI isn't responding" dialog can also block dumps: tap Close app (`tapx aerr_close`); the review list survived that.
- **Soft reboot**: focus shows `FallbackHome`, or adb says "Can't find service: input"; afterwards text input is truncated and the app keeps ANR-ing. `adb_ reboot`, wait until `adb_ shell cat /proc/loadavg` is under ~3, then `mfp_launch`. Sign-ins survive a reboot.
- **Emulator frozen**: `adb_ shell` hangs (even while `adb devices` still says `device`) or `adb devices` shows `offline`. Kill the emulator processes (Windows: `taskkill //F //IM qemu-system-x86_64.exe` and `//IM emulator.exe`; macOS/Linux: `pkill -f qemu-system`), then `emu_start` and `mfp_launch`.
- **Emulator died and won't start again** (no device, qemu stuck at ~1 s CPU time, or a silent exit): it is often waiting on a hidden crash-report consent prompt or an old lock. Kill leftover qemu/emulator processes, delete stale `*.lock` files in the AVD folder (`~/.android/avd/<AVD>.avd/`, e.g. `multiinstance.lock`; `hardware-qemu.ini.lock` may be a directory and can stay), and rename the crash database `emu-crash-*.db` in the emulator's temp folder (Windows: `%TEMP%\AndroidEmulator`). Then `emu_start`; it came back in about a minute.
- Typing 20+ bulk lines takes over 2 minutes. Run that step in the background or with a long timeout so a tool timeout doesn't cut it mid-line.
- A burst of failed dumps mid-chain can leave the app on an unexpected screen (e.g. a Replace search). Wait, `dump`, and continue from wherever it is.

## Script pitfalls
- **Never chain helpers through `| head` or `| grep`**: the pipe hides a failure ("row not found"), and later steps type into the wrong screen. Put `|| exit 1` after each helper call.
- `open-row.sh` exit 1 means nothing opened: don't follow it with `confirm` (that spot is Edit on the review list). Chain with `&&`.
- `open-row.sh` regexes are unanchored: "2% Milk" opened a "Greek Yogurt … 2% Milkfat" row. Anchor short titles (`^2% Milk$`). On very long lists (16+ rows) it may not reach the last row; scroll further and tap the row from a `dump`.
- Opening an Unmatched row with `open-row.sh` prints "WRONG ROW OPENED" (no food name) but does open its search screen; carry on from there.
- Windows Python can't open Git Bash paths like `/c/...`: pass `$(cygpath -m <path>)`. `mfp.sh` does this for `$MFP_TMP`, and `record-result.py` converts its own arguments. `python -I` ignores `PYTHONIOENCODING`, so the printers use `errors="replace"` for titles the console can't encode.

## Diary
- Entries with only a count serving ("2.0 pieces") work: set the number of servings to match (3 pieces of a 2-piece serving = 1.5).
- To log another day, change the date on the Today screen before adding.
- If an entry was logged wrong, edit or delete it instead of adding a duplicate.
