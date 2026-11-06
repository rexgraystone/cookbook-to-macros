#!/usr/bin/env bash
# usage: bash pick-result.sh "<result name, exact>" "<detail substring>"
#
# On a search results screen: takes a fresh dump, taps the row whose name and
# detail text match (e.g. "Oil, olive" "1 tbsp"), then prints the Food
# Details header. Matching by name and detail is safer than by index: result
# order can change between two dumps of the same search.
#
# Hide the keyboard first (hide_kb); rows under it print "LOW". If the top
# result scrolled off, swipe_slow 540 900 540 1500 600. For LOW rows, scroll
# up slowly (swipe_slow 540 1700 540 1100 700) and rerun.
. "$(dirname "$0")/mfp.sh" || exit 1
_mfp_size
dump >/dev/null || exit 1
pt=$("$PY" -I - "$MFP_TMP/ui.xml" "$1" "$2" "$_MFP_H" <<'EOF'
import sys, re, xml.etree.ElementTree as ET
sys.stdout.reconfigure(errors="replace")
nb = lambda s: s.replace('\xa0', ' ')
nodes = list(ET.parse(sys.argv[1]).iter('node')); H = int(sys.argv[4])
for i, n in enumerate(nodes):
    if n.get('resource-id', '').endswith('text_primary') and nb(n.get('text', '')) == sys.argv[2]:
        sec = nb(nodes[i + 1].get('text', '')) if i + 1 < len(nodes) else ''
        if sys.argv[3] in sec:
            a, b, c, d = map(int, re.findall(r'\d+', n.get('bounds')))
            print('LOW' if d > H * 2150 // 2400 else f"{(a + c) // 2} {(b + d) // 2}"); break
EOF
)
echo "pt=$pt"
case "$pt" in ''|LOW) echo "not tappable"; exit 1;; esac
tap $pt; sleep 2.5
food_header
