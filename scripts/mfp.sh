#!/usr/bin/env bash
# Helpers for driving the MyFitnessPal Android app in an emulator over adb.
#
#   source "<plugin>/scripts/mfp.sh"
#
# Works in Git Bash (Windows), macOS and Linux. Needs adb, the Android
# emulator and Python 3 (standard library only).
#
# Configuration (all optional; set before sourcing):
#   ANDROID_SDK_ROOT / ANDROID_HOME  Android SDK location. Defaults:
#                                      Windows  %LOCALAPPDATA%/Android/Sdk
#                                      macOS    ~/Library/Android/sdk
#                                      Linux    ~/Android/Sdk
#   MFP_AVD      AVD name to start            (default: MFP_Pixel)
#   MFP_SERIAL   adb serial if several devices (default: adb's choice)
#   MFP_PKG      app package                  (default: com.myfitnesspal.android)
#   MFP_TMP      scratch dir for ui.xml and screenshots (default: <temp>/mfp)
#   MFP_PYTHON   Python 3 interpreter         (default: python3, else python)
#
# Every function reads stdin from /dev/null so it is safe inside
# `while read` loops (adb otherwise swallows the loop's input).
#
# Functions:
#   emu_ready, emu_start, mfp_launch, mfp_doctor
#   dump, focused_text, tapx, tap, tapr, typ, key, back, swipe_up,
#   swipe_down, swipe_slow, scroll_top, hide_kb, clear_field, confirm,
#   shot, set_servings, food_header, results, adb_
#
# Coordinates in tapr/confirm/swipe_slow are given for a 1080x2400 screen
# and scaled to the device's real size.
#
# Never pipe a helper into `| head` or `| grep` inside a chain of steps: the
# pipe hides its exit status and later steps run on the wrong screen. Use
# `|| exit 1` after each helper instead.
#
# Sandboxes: if Claude Code's sandbox hides the SDK folder or blocks adb's
# local socket, these commands fail with "not found" or "cannot connect".
# Re-run just those commands with the sandbox disabled (Claude Code asks you).

export MSYS_NO_PATHCONV=1   # stop Git Bash rewriting /sdcard/... paths

case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) _MFP_OS=windows; _MFP_EXE=.exe ;;
  Darwin*)              _MFP_OS=macos;   _MFP_EXE= ;;
  *)                    _MFP_OS=linux;   _MFP_EXE= ;;
esac

if [ -n "${ANDROID_SDK_ROOT:-}" ]; then SDK="$ANDROID_SDK_ROOT"
elif [ -n "${ANDROID_HOME:-}" ]; then SDK="$ANDROID_HOME"
else
  case "$_MFP_OS" in
    windows) SDK="$(cygpath -u "${LOCALAPPDATA:-}" 2>/dev/null || echo "${LOCALAPPDATA:-}")/Android/Sdk" ;;
    macos)   SDK="$HOME/Library/Android/sdk" ;;
    *)       SDK="$HOME/Android/Sdk" ;;
  esac
fi
# Windows note: an SDK installed from inside an MSIX-packaged app (such as the
# Claude desktop app) can land in that app's virtualized storage,
# %LOCALAPPDATA%/Packages/<App>_*/LocalCache/Local/Android/Sdk, which other
# shells can't see at the normal path. Fall back to it if adb isn't found.
if [ "$_MFP_OS" = windows ] && [ ! -x "$SDK/platform-tools/adb$_MFP_EXE" ]; then
  _la="$(cygpath -u "${LOCALAPPDATA:-}" 2>/dev/null || echo "${LOCALAPPDATA:-}")"
  for d in "$_la"/Packages/Claude_*/LocalCache/Local/Android/Sdk; do
    [ -x "$d/platform-tools/adb$_MFP_EXE" ] && { SDK="$d"; break; }
  done
fi

ADB="$SDK/platform-tools/adb$_MFP_EXE"
EMU="$SDK/emulator/emulator$_MFP_EXE"
[ -x "$ADB" ] || ADB="$(command -v adb 2>/dev/null || echo "$ADB")"
AVD="${MFP_AVD:-MFP_Pixel}"
MFP_PKG="${MFP_PKG:-com.myfitnesspal.android}"
PY="${MFP_PYTHON:-}"
if [ -z "$PY" ]; then
  # python3 can be a Store stub on Windows, so test that it actually runs.
  for _c in python3 python; do
    "$_c" -c 'import sys; sys.exit(sys.version_info < (3,))' >/dev/null 2>&1 </dev/null && { PY="$_c"; break; }
  done
  PY="${PY:-python3}"
fi

if [ -z "${MFP_TMP:-}" ]; then
  if [ "$_MFP_OS" = windows ]; then
    MFP_TMP="$(cygpath -m "${TEMP:-/tmp}" 2>/dev/null || echo /tmp)/mfp"
  else
    MFP_TMP="${TMPDIR:-/tmp}"; MFP_TMP="${MFP_TMP%/}/mfp"
  fi
fi
# Windows Python can't open /c/... paths, so use the C:/... form it understands.
if [ "$_MFP_OS" = windows ]; then MFP_TMP="$(cygpath -m "$MFP_TMP" 2>/dev/null || echo "$MFP_TMP")"; fi
mkdir -p "$MFP_TMP"

adb_() {
  if [ -n "${MFP_SERIAL:-}" ]; then "$ADB" -s "$MFP_SERIAL" "$@" </dev/null
  else "$ADB" "$@" </dev/null; fi
}

# Print where things are and whether a device is up.
mfp_doctor() {
  echo "OS:       $_MFP_OS"
  echo "SDK:      $SDK"
  echo "adb:      $ADB $( [ -x "$ADB" ] && echo '(ok)' || echo '(MISSING)')"
  echo "emulator: $EMU $( [ -x "$EMU" ] && echo '(ok)' || echo '(MISSING)')"
  echo "AVD:      $AVD"
  echo "python:   $PY ($("$PY" --version 2>&1))"
  echo "tmp:      $MFP_TMP"
  [ -x "$EMU" ] && echo "AVDs:     $("$EMU" -list-avds 2>/dev/null </dev/null | tr '\n' ' ')"
  adb_ devices 2>&1 | sed 1d | sed '/^$/d' | sed 's/^/device:   /'
  emu_ready && echo "booted:   yes" || echo "booted:   no"
}

# Is the emulator up and booted?
emu_ready() { [ "$(adb_ shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; }

# Start the emulator (detached) if needed and wait for boot. Run in the
# background or with a long timeout; first boot takes a minute or two.
emu_start() {
  emu_ready && { echo "emulator already running"; return 0; }
  [ -x "$EMU" ] || { echo "emulator not found at $EMU (set ANDROID_SDK_ROOT or use setup-emulator)"; return 1; }
  "$EMU" -list-avds 2>/dev/null </dev/null | tr -d '\r' | grep -qx "$AVD" \
    || { echo "AVD '$AVD' not found (set MFP_AVD; list with: \"\$EMU\" -list-avds)"; return 1; }
  ( nohup "$EMU" -avd "$AVD" -gpu auto >/dev/null 2>&1 </dev/null & )
  # Poll instead of `adb wait-for-device`, which hangs forever if the emulator dies.
  for _ in $(seq 1 100); do emu_ready && { echo booted; return 0; }; sleep 3; done
  echo "boot timed out; run \"\$EMU\" -avd $AVD by hand to see the error"; return 1
}

# Bring MyFitnessPal to the front (relaunch if it's in a bad state).
mfp_launch() { adb_ shell monkey -p "$MFP_PKG" -c android.intent.category.LAUNCHER 1 >/dev/null; }

# Dump the UI tree and print one line per interesting node:
#   text | content-desc | resource-id | bounds | C=clickable E=focused
dump() {
  # Remove the old files first: if uiautomator fails (app busy or hung), we
  # must not re-read a stale screen. uiautomator sometimes fails once ("null
  # root node") while the screen animates, so retry a few times.
  local _i
  rm -f "$MFP_TMP/ui.xml"
  for _i in 1 2 3 4; do
    adb_ shell rm -f /sdcard/ui.xml >/dev/null 2>&1
    adb_ shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    adb_ exec-out "cat /sdcard/ui.xml 2>/dev/null" > "$MFP_TMP/ui.xml" 2>/dev/null
    grep -q '</hierarchy>' "$MFP_TMP/ui.xml" 2>/dev/null && break
    rm -f "$MFP_TMP/ui.xml"; sleep 1
  done
  [ -s "$MFP_TMP/ui.xml" ] || {
    echo "dump failed (app hung, screen busy or no device?); see ui-gotchas.md, Freezes"; return 1; }
  "$PY" -I - "$MFP_TMP/ui.xml" <<'EOF'
import sys, xml.etree.ElementTree as ET
sys.stdout.reconfigure(errors="replace")   # titles can hold characters the console can't print
AD = ('imp', 'event?', 'Test Ad', 'MobileFuse', 'Visit Site', 'banner-click')
for n in ET.parse(sys.argv[1]).iter('node'):
    t, d = n.get('text', ''), n.get('content-desc', '')
    r = n.get('resource-id', '').split('/')[-1]
    if any(a in t or a in d for a in AD):
        continue
    if t or d or (n.get('clickable') == 'true' and r):
        f = ''.join(c for c, k in (('C', 'clickable'), ('E', 'focused')) if n.get(k) == 'true')
        print(f"{t!r:45.45} {d!r:25.25} {r:30.30} {n.get('bounds')} {f}")
EOF
}

# Print the full text of the focused field (dump truncates long text).
focused_text() {
  "$PY" -I -c "
import sys, xml.etree.ElementTree as ET
sys.stdout.reconfigure(errors='replace')
for n in ET.parse(sys.argv[1]).iter('node'):
    if n.get('focused') == 'true' and n.get('text'): print(n.get('text'))" "$MFP_TMP/ui.xml"
}

# Tap the centre of the Nth (default 0) node whose "text desc resource-id"
# (joined with spaces) matches a regex. Uses the last dump, so call dump
# first when the screen has changed. Don't anchor with ^...$, and escape
# regex characters such as ( ) . + ? in names (or match a plain part).
# Non-breaking spaces in labels are matched as plain spaces.
tapx() {
  [ -s "$MFP_TMP/ui.xml" ] || { echo "no dump yet; run dump first"; return 1; }
  local pt
  pt=$(_mfp_find "$1" "${2:-0}")
  [ -z "$pt" ] && { echo "no match: $1"; return 1; }
  adb_ shell input tap $pt
}
# Kept out of tapx's $(...): bash 3.2 (macOS) misparses heredocs inside $(...).
_mfp_find() {
  "$PY" -I - "$MFP_TMP/ui.xml" "$1" "$2" <<'EOF'
import sys, re, xml.etree.ElementTree as ET
pat, idx = re.compile(sys.argv[2]), int(sys.argv[3]); hits = []
for n in ET.parse(sys.argv[1]).iter('node'):
    s = ' '.join([n.get('text', ''), n.get('content-desc', ''), n.get('resource-id', '')])
    if pat.search(s.replace('\xa0', ' ')):
        a, b, c, d = map(int, re.findall(r'\d+', n.get('bounds')))
        hits.append(f"{(a + c) // 2} {(b + d) // 2}")
print(hits[idx] if len(hits) > idx else '')
EOF
}

tap()  { adb_ shell input tap "$1" "$2"; }
# Type text into the focused field. ASCII only (adb input text can't type
# accented letters). Apostrophes are dropped; avoid "%" and quotes.
typ()  { adb_ shell "input text '$(printf '%s' "$1" | sed -e "s/'//g" -e 's/ /%s/g')'"; }
key()  { adb_ shell input keyevent "$@"; }   # 4=Back 66=Enter 67=Delete 123=End
back() { key 4; }

# Screen size (cached), used to place swipes on any device.
_mfp_size() {
  if [ -z "${_MFP_W:-}" ]; then
    local s; s=$(adb_ shell wm size 2>/dev/null | tr -d '\r' | awk -F': ' '/Override/{o=$2} /Physical/{p=$2} END{print (o?o:p)}')
    _MFP_W=${s%x*}; _MFP_H=${s#*x}
    [ -n "$_MFP_W" ] && [ "$_MFP_W" -gt 0 ] 2>/dev/null || { _MFP_W=1080; _MFP_H=2400; }
  fi
}
swipe_up()   { _mfp_size; adb_ shell input swipe $((_MFP_W/2)) $((_MFP_H*79/100)) $((_MFP_W/2)) $((_MFP_H*37/100)) 400; }
swipe_down() { _mfp_size; adb_ shell input swipe $((_MFP_W/2)) $((_MFP_H*37/100)) $((_MFP_W/2)) $((_MFP_H*79/100)) 400; }

# Scale an "x y" pair given for a 1080x2400 screen to this device.
_mfp_px() { _mfp_size; echo "$(( $1 * _MFP_W / 1080 )) $(( $2 * _MFP_H / 2400 ))"; }
# Tap at 1080x2400 reference coordinates, scaled.
tapr() { adb_ shell input tap $(_mfp_px "$1" "$2"); }
# Swipe between reference points, scaled: swipe_slow X1 Y1 X2 Y2 [ms, default 700].
# Swipes of 150 ms or less on the review list register as taps and open a row.
swipe_slow() { adb_ shell input swipe $(_mfp_px "$1" "$2") $(_mfp_px "$3" "$4") "${5:-700}"; }
# Scroll a long list back to its top with slow swipes (fast ones stall short of it).
scroll_top() { local _i; for _i in $(seq 1 "${1:-6}"); do swipe_slow 540 800 540 2000 800; done; sleep 1.5; }
# Hide the keyboard on search screens with a short scroll. Pressing Back
# with the keyboard already hidden closes the whole search, so avoid it.
hide_kb() { swipe_slow 540 1500 540 1300 300; sleep 0.5; }
# Clear the focused field: select all, then delete. Long runs of `key 67`
# can ANR the app. `input keycombination` needs Android 13+.
clear_field() { adb_ shell input keycombination 113 29 >/dev/null 2>&1; sleep 0.3; key 67; }
# The check mark at the top right of Food Details (`tapx Add` hits titles).
# On the review list the same spot is the Edit button: only call this from Food Details.
confirm() { tapr 996 209; }

# Screenshot to $MFP_TMP/<name>.png and print the path (open it with the Read tool).
shot() { adb_ exec-out screencap -p > "$MFP_TMP/${1:-shot}.png"; echo "$MFP_TMP/${1:-shot}.png"; }

# In an open "How Much?" dialog: set the number of servings and save.
# The number field arrives with its text selected, so typing replaces it.
# After picking a unit the selection can be lost (typing 5.5 gave 15.5), so
# select all before typing, and check the field before saving.
set_servings() {
  dump >/dev/null && tapx numOfServings || return 1
  sleep 0.5; clear_field; typ "$1"; sleep 0.5
  dump >/dev/null || return 1
  local got; got=$(_mfp_text numOfServings)
  [ "$got" = "$1" ] || echo "warning: amount field shows '$got', expected '$1'"
  tapx button1
}

# Text of the first node whose resource-id ends with /<id>, from the last dump.
_mfp_text() {
  "$PY" -I - "$MFP_TMP/ui.xml" "$1" <<'EOF'
import sys, xml.etree.ElementTree as ET
sys.stdout.reconfigure(errors="replace")
for n in ET.parse(sys.argv[1]).iter('node'):
    if n.get('resource-id', '').endswith('/' + sys.argv[2]):
        print(n.get('text', '')); break
EOF
}

# Print the Food Details header: name, amount, unit, kcal, macros.
food_header() { dump | grep -E "txtFoodName|txtNoOfServings|txtServingSize|textEnergyValue|tv_macro_value"; }

# Search results as "index | name | detail" (text_primary/secondary pairs).
results() {
  dump >/dev/null || return 1
  "$PY" -I - "$MFP_TMP/ui.xml" <<'EOF'
import sys, xml.etree.ElementTree as ET
sys.stdout.reconfigure(errors="replace")
p = None; i = 0
for n in ET.parse(sys.argv[1]).iter('node'):
    r = n.get('resource-id', '').split('/')[-1]
    if r == 'text_primary': p = n.get('text')
    elif r == 'text_secondary' and p is not None:
        print(f"{i} | {p} | {n.get('text')}"); i += 1; p = None
EOF
}
