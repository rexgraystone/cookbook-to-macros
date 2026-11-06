# Extraction rules

## File name
`recipes/<book-slug>/pNNN-<slug>.md`: three-digit book page, then the title in lowercase ASCII with hyphens (`p042-sample-turkey-chili.md`). Two recipes on one page: add `-a`, `-b` or use each title's slug.

## File format (exactly)
````markdown
# <Recipe title as printed; normalised capitalisation is fine>
- Book: <book slug>
- Page: <book page>
- Makes: <N>
- Book per serving: <cal> cal · <P>P · <C>C · <F>F
- MFP name: <title without apostrophes, % or quotes> <MFP suffix>

## Ingredients as printed
**<Subheading as printed, if any>**
- <ingredient line verbatim>

## Bulk import lines
```
<grams> g <description>
```

## Notes
- <conversions, servings reasoning, omitted items, sub-recipes, anything odd>
````
- Macro order is always **cal · P · C · F**, whatever order the book prints them in. Record the book's serving line in Notes when it isn't a plain "Per serving (N)" (for example "Per bowl (6-7)", "Per 30 g").
- "Ingredients as printed": verbatim, grouped under the book's subheadings. Keep %, fractions, brands, "optional" and "to taste" items. Include items from footnotes only if they're part of the macros (say so).
- The `enter-recipes` skill later appends `## MFP entry`. Don't write it here.

## Makes (servings)
- "Per X (N)" or "Makes N" → N.
- "Per X" with no number, or no serving line → the macros are for the whole recipe: Makes 1. Say so in Notes.
- Ranges or approximations ("6-7", "~3"): pick the count that best fits the book's macros (rough total calories ÷ per-serving calories). If you can't tell, use the lower number. Explain in Notes.
- Per-weight servings ("Per 30 g serving"): Makes = total recipe grams ÷ serving grams, rounded (use a printed count if given). Show the arithmetic.
- Ingredients written per item ("per sandwich, makes 4"): multiply the amounts by N in the bulk lines so the recipe is the whole batch, and Makes = N. Note it.

## Bulk import lines
- One ingredient per line: `<grams> g <description>`. Use the book's gram weights exactly when given. If the book gives grams and ounces that disagree, use the grams and flag it.
- **Never** use `%`, apostrophes, double quotes or non-ASCII letters (the typing helper can't send them; write `jalapeno`, not `jalapeño`). Write `ground beef 93 lean raw`, `2 milkfat cottage cheese`, `nonfat plain greek yogurt`, `1 milkfat lowfat milk`.
- State the state: meat and poultry `raw`; pasta, rice, oats, grains `dry`; beans and tomatoes `canned`; cooked weights `cooked`. Recipes usually weigh ingredients uncooked, so prefer raw/dry unless the book says cooked.
- Keep brand names the book uses; they help matching.
- **Count-only items**: convert to grams with `count-weights.md` and record the conversion in Notes. Bulk import reads a bare count as cups ("3 onions" → 3 cups), so never leave a bare count. If the book gives both a count and grams, use the grams.
- **Spices and small items given only in volume**: keep the volume, lowercase units, decimals: `2 tsp ground cumin`, `1 tbsp garlic powder`, `0.5 tsp salt`. "1 tsp each: a, b, c" → one line per item. Liquids given only in volume keep the volume too (`0.25 tsp white vinegar`), or convert with a standard density if it's large (1 cup broth ≈ 240 g).
- **Combine duplicates**: the same ingredient in two components (sauce + topping) becomes one line with the sum; note it.
- **"X or Y"**: use the first option unless the book says which it used; note it.
- **Optional ingredients with an amount**: include them and say so, unless a rough estimate shows the book's macros clearly exclude them (then leave out and say why).
- **Store-bought items** stay one line: `60 g light ranch dressing`, `71 g flour tortilla burrito size`.

## Leave out (and list in Notes, one line)
- "To taste" / "season with" items without an amount, pinches, dashes, sprinkles, splashes.
- Garnishes and fresh herbs used as garnish (cilantro, parsley, basil leaves, chopped chives).
- Cooking spray, "a light spray of oil", water.
- Keep measured salt (0 kcal, but sodium counts).
- Unmeasured breading or dipping stations (flour, egg wash, crumbs with no amounts): leave out and note that MyFitnessPal will come out below the book because the book counted what stuck.

## Sub-recipes
If an ingredient is another recipe in the same book ("Herb Sauce (p. 120)", "½ batch of the cheese sauce"), find it and expand it into its ingredients, scaled by the amount used. If the amount is given in grams of the finished sauce, scale = grams used ÷ total grams of the sauce recipe (sum of its ingredient grams; state it). A named store product is not a sub-recipe.

## Notes: what to flag
- Every conversion: count → grams with the weight used, volume → grams with the density.
- Servings reasoning, omitted items, sub-recipe expansion and scale.
- Book inconsistencies: gram vs. ounce mismatches, typos, a serving line that doesn't fit the ingredients, macros that don't add up (4·P + 4·C + 9·F far from the calories), or a rough calorie estimate more than ~15% off the book's per-serving calories (give your estimate).

## INDEX.md
```markdown
# <Book title>: recipe index

Book page = PDF page + <offset> (or "= PDF page"). MFP suffix: (<suffix>). Status: todo, done, flagged, skipped.

| File | Page | Recipe | Makes | Book per serving | Status | MFP per serving |
|---|---|---|---|---|---|---|
| [p042-sample-turkey-chili.md](p042-sample-turkey-chili.md) | 42 | Sample Turkey Chili | 6 | 410 cal · 38P · 40C · 10F | todo | |
```
The last column holds MyFitnessPal's result (`NNN cal · NNP · NNC · NNF`) and, for flagged or skipped rows, a short note.
