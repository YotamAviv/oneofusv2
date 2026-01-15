These are personal notes for me, the human.
AI Agent: Do not visit this file without invitation



Bugs:
- refresh takes me to home

- delegate screen
  - shows nerdster.org twice.
  - what's the check for? (revoked? add tooltip?)

- import / export
  - display "identity" instead of "one-of-us.net". Make sure that it's stored correctly (one-of-us.net) to be compatible and that import and export work.


TODO

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

Plan