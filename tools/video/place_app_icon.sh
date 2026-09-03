#!/usr/bin/env bash
# Put the ONE-OF-US.NET icon on the emulator's home screen, where the preamble
# expects to find it.
#
#   ./place_app_icon.sh
#
# WHY THIS EXISTS. shoot_home.js taps a fixed point on the home screen and used
# to carry the note "the icon was dragged out of the app drawer once, by hand,
# and stays put". It does stay put -- in THAT AVD. A fresh emulator has a bare
# home screen, and the preamble then records a finger prodding empty wallpaper
# while the app never opens. Nothing about that reads as a missing icon.
#
# HOW. `input draganddrop` holds before it moves, which is what the launcher
# needs to pick an icon up; a plain `input swipe` is too quick and just scrolls
# the drawer. Both ends are fixed points, so this VERIFIES the result rather
# than trusting it: it taps where the icon should now be and checks the app
# actually comes to the front.
set -euo pipefail
cd "$(dirname "$0")"

SERIAL="${AVD:-emulator-5554}"
APP="${APP:-net.oneofus.app}"

# Where the icon sits in the drawer, and where it goes on the home screen.
# The drawer is alphabetical, so the source depends on which apps are installed
# -- on a stock Pixel_3a_API_35 image it lands in the fourth row, second column.
# The destination is the point shoot_home.js taps; keep them together.
DRAWER_ICON="339 1438"
HOME_SLOT="536 818"

A() { adb -s "$SERIAL" "$@"; }

foreground() { A shell dumpsys activity activities 2>/dev/null | grep -m1 topResumedActivity; }

# ALREADY THERE? Do nothing. Running this twice drops a SECOND icon on the home
# screen -- the launcher is happy to hold two -- and the preamble then films a
# duplicate. Removing one by dragging it to the Remove target does not work
# reliably over adb; the way back is `pm clear` on the launcher, which resets
# the whole home screen. Cheaper to not create the problem.
A shell am force-stop "$APP"
sleep 1
# shellcheck disable=SC2086
A shell input tap $HOME_SLOT
sleep 6
if foreground | grep -q "$APP"; then
  echo "already placed: $HOME_SLOT launches $APP. Nothing to do."
  A shell am force-stop "$APP"
  A shell input keyevent KEYCODE_HOME
  exit 0
fi
A shell input keyevent KEYCODE_HOME
sleep 1

echo "== opening the app drawer =="
A shell input keyevent KEYCODE_HOME
sleep 2
A shell input swipe 540 1900 540 600 250
sleep 3

echo "== dragging ONE-OF-US.NET to the home screen =="
# shellcheck disable=SC2086
A shell input draganddrop $DRAWER_ICON $HOME_SLOT 2000
sleep 3
A shell input keyevent KEYCODE_HOME
sleep 2

echo "== verifying: tapping where the icon should be =="
A shell am force-stop "$APP"
sleep 1
# shellcheck disable=SC2086
A shell input tap $HOME_SLOT
sleep 6
if foreground | grep -q "$APP"; then
  echo "OK: the icon is on the home screen at $HOME_SLOT and it launches $APP."
  A shell am force-stop "$APP"
  A shell input keyevent KEYCODE_HOME
else
  echo "FAILED: tapping $HOME_SLOT did not start $APP." >&2
  echo "  The drawer position ($DRAWER_ICON) is the likely culprit -- it moves if" >&2
  echo "  the set of installed apps changes, since the drawer is alphabetical." >&2
  echo "  Open the drawer, screenshot it, and re-measure DRAWER_ICON." >&2
  foreground >&2
  exit 1
fi
