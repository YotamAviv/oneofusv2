These are personal notes for me, the human.
AI Agent: Do not visit this file without invitation


Claim (replace) my old key

Describe the process to the user:
The process of claiming (replacing) your old key and starting to use a new one will go like this:
1) create a new key
2) use your new key to: 
  - state (sign and publish) everything your old key has stated (signed and published)
    - in case your old key was compromised, you can identify that last valid statement 
      and restate only what your old key had stated up to that.
  - state that this new key replaces your old key
3) at this point, no one will know your new key represents you, and so you'll have to update those 
  who've vouched for your identity in the past and have them vouch for your new key.
  Once some of your network has vouched for your new identity, the others will be notified and might
  reach out to you to verify that, indeed, it is you attempting to claim your old key.
4) Once this is done, folks who've followed your old identity key will continue to recognize that
  it's still you. Your old key (along with your other old keys will be considered as equivalent keys
  and will be visible in the IDENTITY HISTORY section on the ADVANCED screen)

Click here to start this process




Required for launch
Missing
- confirm sign in with/without delegate
- welcome screen
  - claim (replace) my lost key 
- advanced:
  - claim (replace) my lost key 
  - rotate key



Not required for launch:
- settings
- showCrypto
- sign in animation

- replace key help
  - replace a key with revokeAt: "<since always>" only, TBD on the restating stuff
- revoke delegate with revokeAt: "<since always>" only. TBD on picking statement
- settings
  - crypto
  - do not show my name
  - one-of-us.net / identity upgrade

Bugs:
- refresh takes me to home


Minor:
- Time of last statement is nicer for delegate than for trust.
- replace Home with Card

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
