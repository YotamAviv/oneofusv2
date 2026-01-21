These are personal notes for me, the human.
AI Agent: Do not visit this file without invitation

## Nice ones:
flutter emulators --launch Pixel_7a_API_35
flutter emulators --launch Pixel_7
flutter emulators --launch Pixel_3a_API_35
adb shell pm clear net.oneofus.app
flutter run -d emulator-5554

## required for launch
claim key from welcome screen broken.

### Nerdster side
- keys received, just a text snackbar

## Bugs:

## Not required for launch:
- settings
- showCrypto
- display delegate keys we have locally (private key) differently from ones we know about but don't have

## magic sign in improve
switch to card, show animation (might be working already)


## Notifications:
  - key you trust [block, replace] you (or equivalent)
  - key you trust trusts a key you've blocked
  - key you trust blocks a key you trust
  - (think about this more, replace, etc...)
  - key is corrupted (crash and notify if it's my key)
  - you replaced a key but didn't revoke it "<since always>"
- 

## Settings
  - showCrypto
  - do not show my name
  - one-of-us.net / identity upgrade

### showCrypto
- sign in credentials sent..
  - identity public key (and/or delegate public/private key pair) sent to nerdster.org
- keys icons..
  - revoked: crossed out key icon, on people keys, delegate keys
  - mine, theirs, my delegates
- LGTM'ish..


### Minor
- delegate screen: Consider displaying "Yotam@nerdster.org"
- if they vouched for you, give the details (name, comment). (could be handled by Crypto mode)

## Tech
- common package
  - Jsonish
  - renames
    - s / ContentStatement / NerdsterStatement

...

### Dropped functionality (from legacy phone app)
- Create delegate
- Replace with specific revokeAt

### PoV mode!?
(Don't actually spend time on it)
But yes, you could browse around, see who they trust, sign into services as them (without their delegate key)
Wouldn't even be that hard