#!/usr/bin/env bash
# usage: bash set-amount.sh "<unit regex, e.g. ^1.0 g$; empty keeps the unit>" <number of servings>
#
# In Food Details: opens How Much?, picks the unit (scrolling the unit list
# both ways, since it opens at the current unit and hides the ones above),
# types the amount, saves and prints the header. Anchor the unit regex:
# "^1.0 g" also matches "1.0 gallon"; use "^1.0 g$" or "^1.0 (g|gram)$".
#
# Then leave Food Details with `confirm`, never Back. Check the printed kcal:
# some entries have broken gram units, and on entries with a two-line title
# the amount can stay unchanged (then: tapx includeNumberServingsContainer;
# set_servings N).
. "$(dirname "$0")/mfp.sh" || exit 1

findu() {
  "$PY" -I - "$MFP_TMP/ui.xml" "$1" <<'EOF'
import sys, re, xml.etree.ElementTree as ET
for n in ET.parse(sys.argv[1]).iter('node'):
    if n.get('resource-id', '').endswith('/text1') and re.search(sys.argv[2], n.get('text', '')):
        a, b, c, d = map(int, re.findall(r'\d+', n.get('bounds'))); print((a + c) // 2, (b + d) // 2); break
EOF
}

dump >/dev/null || exit 1
if ! grep -q 'numOfServings' "$MFP_TMP/ui.xml"; then
  tapx includeNumberServingsContainer || tapx txtServingSize || exit 1
  sleep 1.5; dump >/dev/null || exit 1
fi
if [ -n "$1" ]; then
  tapx serving_size || exit 1; sleep 1.5; dump >/dev/null || exit 1
  pt=$(findu "$1")
  for dir in down down down up up up up up up; do
    [ -n "$pt" ] && break
    if [ "$dir" = down ]; then swipe_slow 500 1500 500 2200 300; else swipe_slow 500 2200 500 1500 300; fi
    sleep 1; dump >/dev/null || continue; pt=$(findu "$1")
  done
  [ -z "$pt" ] && { echo "unit not found; units on screen:"; dump | grep text1; exit 1; }
  tap $pt; sleep 1
fi
set_servings "$2" || exit 1; sleep 2
food_header
