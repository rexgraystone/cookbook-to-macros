---
name: extract-recipes
description: Extract recipes from a cookbook PDF or photos of cookbook pages into one markdown file per recipe (ingredients as printed, gram-based MyFitnessPal bulk-import lines, servings, the book's per-serving macros) plus a per-book INDEX.md status table. Use when the user gives a cookbook PDF, scanned pages or recipe photos and wants them prepared for MyFitnessPal, or asks to extract, parse, index or transcribe cookbook recipes.
---

# Extract cookbook recipes

Turns a cookbook into `recipes/<book-slug>/pNNN-slug.md` files and `recipes/<book-slug>/INDEX.md`, ready for the `enter-recipes` skill. This skill never touches the emulator.

Read before writing any recipe file:
- `${CLAUDE_PLUGIN_ROOT}/skills/extract-recipes/reference/extraction-rules.md`: file format, servings, bulk-line rules, what to leave out, sub-recipes, notes.
- `${CLAUDE_PLUGIN_ROOT}/skills/extract-recipes/reference/count-weights.md`: standard weights for count-only items.
- Examples of the output: `${CLAUDE_PLUGIN_ROOT}/examples/sample-recipe.md` and `${CLAUDE_PLUGIN_ROOT}/examples/INDEX.md`.

Extracted recipes are copyrighted book content: keep them in the user's private project and never publish them.

## 1. Set up the book
Agree with the user (or pick sensibly and say so):
- **Book slug**: short folder name, e.g. `weeknight`, `sheet-pan`.
- **MFP suffix**: appended to every MyFitnessPal name, e.g. `(Weeknight Book)`, so their recipes are easy to find and don't clash with database foods. If two books share a suffix and a recipe title, give one a distinct suffix (e.g. `(Weeknight Book 2)`); check the other books' INDEX files for title collisions before naming.

## 2. Map the pages (PDF)
The helper needs PyMuPDF (`pip install pymupdf`). It is far better than pdftotext for fractions and two-column layouts.
```bash
H="${CLAUDE_PLUGIN_ROOT}/skills/extract-recipes/scripts/pdf_pages.py"
python3 "$H" book.pdf --titles                      # biggest text per page = likely recipe titles
python3 "$H" book.pdf --grep "makes|per serving|calories"   # pages with a nutrition line
python3 "$H" book.pdf --pages 20-45 -o book-20-45.txt   # column-aware text, [x,y] per line, ## = bold
```
Use `python` instead of `python3` where that's the working interpreter (often on Windows, where `python3` can be a Microsoft Store stub). Shell variables don't persist between Bash calls, so set `H` in each call.
- Decide whether the book's printed page numbers equal PDF page numbers (compare a footer with the PDF index). Use **book page numbers** in file names and the INDEX; state the offset in the INDEX header. Tables of contents are often stale; trust the pages.
- Pages with no text layer are scans: treat them like photos.
- Put intermediate dumps in a scratch/temp folder, not in `recipes/`.

## 3. Photos or scans
Read each image with the Read tool. Use the printed page number if visible, otherwise the photo's order (`p001`, `p002`, …) and say so in the INDEX header. Ask for a retake of anything unreadable rather than guessing grams.

## 4. Write the recipe files
For each recipe: read the text dump **and** look at the page image (Read tool on the PDF with `pages: "N"`, or `--render DIR` and Read the PNG) to confirm every gram figure, fraction, the serving line and the four macros. Accuracy beats speed: a misread gram figure becomes a wrong recipe in MyFitnessPal. Then write the file exactly as `extraction-rules.md` specifies.

## 5. Write INDEX.md
One table per book, one row per recipe, sorted by page, Status `todo` for new rows (see `examples/INDEX.md`). Recipes you can't use (no macros, a template, a drink with no measurable amounts) get a row with Status `skipped` and the reason in the last column.

## 6. Check
- Every file's Makes, macros and MFP name match its INDEX row.
- Bulk lines contain no `%`, apostrophes, double quotes or non-ASCII letters, and no bare counts.
- For each recipe, a rough calorie total of the bulk lines divided by Makes is within ~15% of the book's per-serving figure; otherwise note your estimate in the file's Notes.
- If the project is a git repo, commit the book folder (`git add recipes/<book-slug>`) unless the user said otherwise.

## Parallelising
Extraction doesn't touch the phone, so it parallelises well. For a big book or several books, give each subagent one book or a page range of about 15-25 recipes. Each brief should include: the PDF path and page range, the book slug, MFP suffix and page offset, the exact output file names it owns, "Use the `extract-recipes` skill and its reference files; check every page image", "Don't touch the emulator or adb; write only your assigned files; don't commit". Ask each to return its INDEX rows plus a list of judgment calls. Then write INDEX.md yourself, check for name collisions across books, and commit once.
