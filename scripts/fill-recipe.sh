#!/usr/bin/env bash
# usage: bash fill-recipe.sh recipes/<book>/<file>.md [skiphead]
#
# On the New Recipe screen: types the file's "MFP name" and the leading number
# of "Makes", turns on Bulk Import Ingredients and types every line under
# "## Bulk import lines" (code fences and blank lines are skipped).
# skiphead = only type the ingredient lines (name, servings and toggle done).
#
# Takes about a minute per 10 lines; for 20+ lines run it in the background
# or with a long timeout. Check the typed name, servings and lines before Next.
. "$(dirname "$0")/mfp.sh" || exit 1
set -f   # no globbing when splitting lines into words

f="$1"
[ -f "$f" ] || { echo "no such file: $f"; exit 1; }
name=$(grep -m1 '^- MFP name:' "$f" | sed 's/^- MFP name: *//' | tr -d '\r')
# Leading number only: "5 (per bowl)" typed whole became 590 servings.
serv=$(grep -m1 '^- Makes:' "$f" | sed 's/^- Makes: *//' | grep -o '^[0-9.]*')
lines=$(sed -n '/^## Bulk import lines/,/^## /p' "$f" | grep -v '^##' | grep -v '^```' | tr -d '\r' | grep -v '^[[:space:]]*$')
[ -n "$name" ] && [ -n "$serv" ] && [ -n "$lines" ] || { echo "missing MFP name, Makes or bulk lines in $f"; exit 1; }
# adb input text silently drops words with non-ASCII letters.
if printf '%s\n%s\n' "$name" "$lines" | LC_ALL=C grep -q '[^ -~]'; then
  echo "non-ASCII text in name or lines (spell it in ASCII first):"
  printf '%s\n%s\n' "$name" "$lines" | LC_ALL=C grep -n '[^ -~]'; exit 1
fi

if [ "$2" != skiphead ]; then
  dump >/dev/null || exit 1
  tapx inputName || exit 1; sleep 0.5
  # Word by word: long `input text` strings were cut at ~18 characters.
  for w in $name; do typ "$w "; done; key 67; sleep 0.5
  dump >/dev/null || exit 1; tapx inputServings || exit 1; sleep 0.5; typ "$serv"; sleep 0.5
  dump >/dev/null || exit 1; tapx switchBulkImport || exit 1; sleep 1.5
fi
dump >/dev/null || exit 1
tapx inputIngredients || exit 1; sleep 0.8
printf '%s\n' "$lines" | while IFS= read -r line; do
  for w in $line; do typ "$w "; done; key 66
done
echo "typed: name='$name' servings=$serv lines=$(printf '%s\n' "$lines" | wc -l | tr -d ' ')"
