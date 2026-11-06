# Contributing

## Reporting app UI changes
MyFitnessPal updates its Android app often, and selectors break. When something stops matching, open an issue with:
- the app version (`adb shell dumpsys package com.myfitnesspal.android | grep versionName`) and Android version;
- the step that failed (e.g. "Create a Recipe → bulk import toggle");
- the relevant lines of `dump` output for that screen (the old and new resource-id or label).

Strip anything personal from dumps and screenshots first: your name, email, diary entries, weight, and any cookbook text.

## Adding a gotcha
Gotchas live in one place: `skills/enter-recipes/reference/ui-gotchas.md`. Add one short line under the right heading, saying what happens and what to do instead. Don't copy gotchas into the individual skills; link to the file.

During your own runs, the skills write local lessons to `mfp-notes.md` in your project. Anything general there is a good candidate for a pull request.

## Other changes
- Keep `SKILL.md` files short and imperative; put long reference material in a `reference/` file.
- Never add cookbook content (recipe text, ingredient lists, macros, page numbers or book names) to examples or tests. Invent examples.
- Never add instructions that type passwords or sign in for the user.
- Run before sending a PR:
  ```bash
  for f in scripts/*.sh; do bash -n "$f"; done
  python3 scripts/record-result.py --help
  claude plugin validate .
  python3 skills/extract-recipes/scripts/pdf_pages.py --help
  ```
