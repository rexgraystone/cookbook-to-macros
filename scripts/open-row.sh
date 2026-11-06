#!/usr/bin/env bash
# usage: bash open-row.sh "<title regex>" ["<food name regex>"]
#
# In Review Ingredients: scrolls to the top, then down to the first row whose
# title matches, opens it and prints the Food Details header.
# Exit 1: row not found (nothing opened; do NOT tap the check mark, on the
#         review list that spot is the Edit button).
# Exit 2: the opened food's name doesn't match (Food Details appends the
#         brand, so ^ and $ are dropped for this check). An Unmatched row has
#         no food name and opens its search screen instead; carry on there.
# Regexes are unanchored: anchor short titles (^2% Milk$) so they don't hit
# longer ones. Non-breaking spaces in titles match plain spaces.
. "$(dirname "$0")/mfp.sh" || exit 1
_mfp_size
scroll_top
pt=
for _i in 1 2 3 4 5 6 7 8 9 10; do
  dump >/dev/null || continue
  pt=$("$PY" -I - "$MFP_TMP/ui.xml" "$1" "$_MFP_W" "$_MFP_H" <<'EOF'
import sys, re, xml.etree.ElementTree as ET
pat, W, H = re.compile(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
for n in ET.parse(sys.argv[1]).iter('node'):
    if n.get('resource-id', '').endswith('/title') and pat.search(n.get('text', '').replace('\xa0', ' ')):
        a, b, c, d = map(int, re.findall(r'\d+', n.get('bounds')))
        if b > H * 400 // 2400 and d < H * 2100 // 2400:   # fully on screen, below the toolbar
            print(W * 500 // 1080, (b + d) // 2 + H * 40 // 2400); break
EOF
)
  [ -n "$pt" ] && break
  swipe_slow 540 1900 540 1300 600; sleep 1.5
done
[ -z "$pt" ] && { echo "row not found"; exit 1; }
tap $pt; sleep 2.5
food_header
name=$(_mfp_text txtFoodName)
pat="${2:-$1}"; pat="${pat#^}"; pat="${pat%\$}"
"$PY" -I -c 'import sys, re; sys.exit(0 if re.search(sys.argv[1], sys.argv[2].replace("\xa0", " ")) else 1)' "$pat" "$name" \
  || { echo "WRONG ROW OPENED: '$name'"; exit 2; }
