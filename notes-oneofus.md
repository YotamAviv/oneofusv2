These are personal notes for me, the human.
AI Agent: Do not visit this file without invitation

Tasks
1) Get integration_test/bidirectional_trust_test.dart to run using the configured Firestore so that it can exercise and test the emulator, as well.
Have that test refuse to run if the current config is for production

2) I added another demo style test in egos.dart.
Chage the DEV screen so that I can run any test in egos.dart Map tests by name;

3) The new demo test in egos is 'longname'. When I run it, the name is way too long to fit in the card.
I'd like to use a large font if the name is "Me" or "Lisa".
But if the name is long:
- use a smaller font
- constrain the name to an area that doesn't interfere with the QR code
- let the name wrap (if it has a space)
- truncate the name to elipses if it still doesn't fit





Required for launch
Missing
- delegates screen: revoke/clear
- load up equivalents (show/edit in modal screen)
- load up blocks (show/edit in modal screen)
- import/export identity/one-of-us.net swap
- entry screen
  - claim (replace) key
  - import key
Have
- trust/block/clear

Not required for launch:
- replace key help
  - replace a key with revokeAt: "<since always>" only, TBD on the restating stuff
- revoke delegate with revokeAt: "<since always>" only. TBD on picking statement
- settings
  - crypto
  - do not show my name
  - one-of-us.net / identity upgrade

Bugs:
- refresh takes me to home

- delegate screen
  - shows nerdster.org twice.
  - what's the check for? (revoked? add tooltip?)

- import / export
  - display "identity" instead of "one-of-us.net". Make sure that it's stored correctly (one-of-us.net) to be compatible and that import and export work.
    - see:
      static Json internal2display(Json internal) => _swap(kOneofusDomain, kIdentity, internal);
      static Json display2internal(Json display) => _swap(kIdentity, kOneofusDomain, display);



TODO

Load up equivalents

Modal screens
- my outstanding blocks (could be a mistake. allow [clear, trust])
- my replaced (claimed) keys (could be a mistake. allow clear)
- 

Test mode
- Start the app with FakeFirebase
  - stoked it with some test statements and an identity.
    - functions like egosCircle, but here.
    - use helpers for trust, block, clear, delegate and enforce rules (comment, moniker, domain, etc...)
      Use those same helpers in the code
    - could be used for unit tests for a MVC style model with notifications, tooltips per thing (trusted key, any key (corrupt), ...)

Show more:
  - if they trusted you, give the details. (could be handled by Crypto mode)

Notifications:
  - key you trust [block, replace] you (or equivalent)
  - key is corrupted (crash and notify if it's my key)
  - 

- navigation
  - import / export to screen 3

Trusting, Blocking
Take 4:
- Do not enable the action button unless a change has been made.
- When I scan a key, check what we already know about it:
  - bring up my existing trust or block if I have one and let me change it (can block, can trust, must maintain rules of trust always requires moniker, block does not allow moniker)
  - Do not let me trust or block my own key, equivalent keys (DEFER), or delegates (including delegate keys)


- delegate screen
  Consider displaying "Yotam@nerdster.org"
  - revokeAt "<since always>" or at specific statement token.


- advanced..
  - claim identity key ("replace", must revokeAt "<since always>")
  - claim delegate key

- tech
  - common package
    - Jsonish
    - FakeFirestore support (and Direct, why not) (might be working)
    - renames
      - s / ContentStatement / NerdsterStatement

- Settings
  - don't show my name on my card
  - show Crypto
    - identity (delegate) key(s) sent to <nerdster.org>
    - key icon, crossed out key icon, on people keys, delegate keys
    - LGTM'ish..

Display keys and export them as "<identity>".
Read the legacy code and verify how it saved keys.
Be compatible with a variety: "one-of-us.net", "identity", "<identity>"

Dropped functionality (from legacy phone app)
- Replace key
- Create delegate
- Replace with specific revokeAt
