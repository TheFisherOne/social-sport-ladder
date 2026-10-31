#!/usr/bin/env bash
# End-to-end check on the connected emulator/device (app must be installed):
#  1. launch app, tap "About Social-Sport-Ladder"
#  2. verify Chrome shows "Social Sport Ladder Introduction" and a "Go Back" button
#  3. follow the Privacy Policy link, verify its page and that Go Back returns to About
#  4. tap "Go Back" and verify we are back on the app login page
#  5. sign in with a bad account and verify the credential error is shown
set -uo pipefail
ADB=${ADB:-$HOME/Android/Sdk/platform-tools/adb}
PKG=com.doug.socialsportladder
EMAIL=test21@gmail.com
PASSWORD=123456

dump() {
  "$ADB" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  "$ADB" exec-out cat /sdcard/ui.xml
}

# find_center <attr> <value-substring>: reads dump on stdin, prints "x y" of first match
find_center() {
  python3 -c '
import re, sys
attr, val = sys.argv[1], sys.argv[2]
for n in re.findall(r"<node[^>]*>", sys.stdin.read()):
    m = re.search(r"\b" + attr + r"=\"([^\"]*)\"", n)
    b = re.search(r"bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"", n)
    if m and b and val in m.group(1):
        x1, y1, x2, y2 = map(int, b.groups())
        print((x1 + x2) // 2, (y1 + y2) // 2)
        break
' "$1" "$2"
}

tap_xy() { "$ADB" shell input tap "$1" "$2"; }

# wait_for <attr> <value> [tries]: polls until visible (dismissing Chrome
# first-run dialogs); sets LAST_XY and LAST_DUMP
wait_for() {
  local attr=$1 val=$2 tries=${3:-15} d c
  for _ in $(seq 1 "$tries"); do
    d=$(dump)
    c=$(echo "$d" | find_center "$attr" "$val")
    if [ -n "$c" ]; then LAST_DUMP=$d; LAST_XY=$c; return 0; fi
    for label in "Stay signed out" "Accept & continue" "No thanks" "Use without an account" "Got it"; do
      c=$(echo "$d" | find_center text "$label")
      [ -n "$c" ] && tap_xy $c
    done
    sleep 2
  done
  return 1
}

# check <description> <attr> <value> [tries]
check() {
  if wait_for "$2" "$3" "${4:-15}"; then echo "PASS: $1"; else echo "FAIL: $1"; exit 1; fi
}

"$ADB" shell am force-stop com.android.chrome
"$ADB" shell pm clear "$PKG" >/dev/null # start signed out
"$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

check "login page shown" content-desc "About Social-Sport-Ladder" 30
tap_xy $LAST_XY

# The page content may be exposed as text or content-desc depending on Chrome
if wait_for text "Social Sport Ladder Introduction" 10 ||
   wait_for content-desc "Social Sport Ladder Introduction" 3; then
  echo "PASS: About header"
else
  echo "FAIL: About header"; exit 1
fi
check "Go Back button" text "Go Back" 5

# Privacy policy link (inside the About page) -> Privacy Policy page -> Go Back
check "Privacy policy link on About page" text "Privacypolicy.html" 5
tap_xy $LAST_XY
check "Privacy Policy page title" text "Privacy Policy" 10
check "Go Back button on Privacy Policy page" text "Go Back" 5
tap_xy $LAST_XY
check "returned to About page" text "Social Sport Ladder Introduction" 10

check "Go Back button on About page" text "Go Back" 5
tap_xy $LAST_XY

check "back on app login page" content-desc "Sign In" 15

check "email field" hint "Email" 3
tap_xy $LAST_XY
sleep 1.5
"$ADB" shell input text "$EMAIL"
check "password field" hint "Password" 3
tap_xy $LAST_XY
sleep 1.5
"$ADB" shell input text "$PASSWORD"
"$ADB" shell input keyevent KEYCODE_BACK # hide keyboard

check "Sign In button" content-desc "Sign In" 5
tap_xy $LAST_XY

check "credential error shown" content-desc "credential" 15
echo "Error text: $(echo "$LAST_DUMP" | grep -o 'content-desc="[^"]*credential[^"]*"' | head -1)"

# Second attempt with the correct password should reach the ladder selection page
check "password field (retry)" hint "Password" 3
tap_xy $LAST_XY
sleep 1.5
sleep 1.5
"$ADB" shell input keyevent KEYCODE_MOVE_END
"$ADB" shell input keyevent --longpress $(for _ in $(seq 20); do printf 'KEYCODE_DEL '; done)
"$ADB" shell "input text '@123456\$'"
"$ADB" shell input keyevent KEYCODE_BACK # hide keyboard
check "Sign In button (retry)" content-desc "Sign In" 5
tap_xy $LAST_XY

# The ladder selection app bar shows "V<version>" and the logged-in email
check "ladder selection page shown" content-desc "$EMAIL" 20
echo "App bar: $(echo "$LAST_DUMP" | grep -o "content-desc=\"[^\"]*$EMAIL[^\"]*\"" | head -1)"
