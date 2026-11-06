#!/usr/bin/env bash
# usage: bash new-recipe.sh recipes/<book>/<file>.md   (2-5 min; long timeout or background)
#
# Start on the Recipes list (More -> Recipes, Meals & Foods -> Recipes tab,
# scrolled to the top, search box empty and keyboard hidden) or on a saved
# recipe's details screen. Runs Create a Recipe -> Enter Ingredients Manually
# -> fill-recipe.sh -> prints the typed ingredient text -> Next -> review-rows.sh.
#
# "not on recipes list": the list may still be loading after a Save (wait 2 s
# and rerun) or be scrolled down (swipe_down twice and rerun).
. "$(dirname "$0")/mfp.sh" || exit 1
here="$(dirname "$0")"

dump >/dev/null || exit 1
grep -q RecipeDetailsActivity "$MFP_TMP/ui.xml" && { key 4; sleep 2; dump >/dev/null || exit 1; }
grep -q btn_add_item "$MFP_TMP/ui.xml" || { echo "not on recipes list"; exit 1; }
tapx btn_add_item || exit 1; sleep 2
dump >/dev/null || exit 1; tapx "Enter Ingredients Manually" || exit 1; sleep 2.5
bash "$here/fill-recipe.sh" "$1" || { echo "fill-recipe failed; check the screen before retrying"; exit 1; }
dump >/dev/null || exit 1; focused_text
tapx Next || exit 1; sleep 6
bash "$here/review-rows.sh"
