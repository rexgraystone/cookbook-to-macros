#!/usr/bin/env bash
# usage: bash review-rows.sh [pages, default 9]
#
# In Review Ingredients (or the New Recipe summary): scrolls to the top, then
# down through the list, printing each row once as
#   title | amount | kcal | original bulk line
# plus "## <calories per serving>" when shown. Unmatched rows show UNMATCHED.
#
# Wait ~8-10 s after confirming Food Details before running this: swipes that
# land during the re-render can open a random row (leave it with `confirm`).
. "$(dirname "$0")/mfp.sh" || exit 1

dump >/dev/null || exit 1
grep -Eq 'original_text|calories_per_serving|Unmatched' "$MFP_TMP/ui.xml" \
  || { echo "not on the review list (did it vanish?); check the screen first"; exit 1; }
scroll_top
: > "$MFP_TMP/rows.txt"
for _i in $(seq 1 "${1:-9}"); do
  dump >/dev/null || break
  "$PY" -I - "$MFP_TMP/ui.xml" >> "$MFP_TMP/rows.txt" <<'EOF'
import sys, xml.etree.ElementTree as ET
sys.stdout.reconfigure(errors="replace")
rows = []; cur = None
for n in ET.parse(sys.argv[1]).iter('node'):
    r = n.get('resource-id', '').split('/')[-1]; t = n.get('text', '').replace('\xa0', ' ')
    if r == 'calories_per_serving': print('##', t)
    if r == 'title': cur = {'title': t}; rows.append(cur)
    elif r in ('info', 'calories', 'original_text') and cur is not None: cur[r] = t
for c in rows:
    if 'original_text' in c or c.get('info') == 'Unmatched':
        print(f"{c['title']} | {c.get('info', '')} | {c.get('calories', '-')} | {c.get('original_text', 'UNMATCHED')}")
EOF
  swipe_slow 540 1900 540 900 600; sleep 0.8
done
awk '!seen[$0]++' "$MFP_TMP/rows.txt"
